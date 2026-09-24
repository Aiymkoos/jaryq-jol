import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/assistant_commands.dart';
import '../services/navigation_service.dart';
import '../services/scene_narrator.dart';
import '../services/settings_service.dart';
import '../services/speech_service.dart';
import '../services/text_reader.dart';
import '../services/vision_service.dart';

class CompanionScreen extends StatefulWidget {
  const CompanionScreen({super.key});
  @override
  State<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends State<CompanionScreen>
    with WidgetsBindingObserver {
  final _speech = SpeechService();
  final _settings = PrefsSettingsStore();
  final _navigation = NavigationService();
  final _microphone = SpeechToText();
  final _query = TextEditingController();
  final _command = TextEditingController();
  final _map = MapController();
  AppSettings _preferences = const AppSettings();
  int _tab = 0, _operation = 0;
  bool _busy = false, _listening = false, _started = false;
  String _last = '', _status = '';
  List<Place> _places = [];
  Position? _position;
  WalkRoute? _route;
  RouteProgress? _progress;
  StreamSubscription<Position>? _positions;
  Timer? _watchdog;
  bool _guiding = false, _consent = false;
  DateTime _lastAlert = DateTime(2000);
  bool get kk => _preferences.language == AppLanguage.kazakh;
  String tr(String ru, String kz) => kk ? kz : ru;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  Future<void> _load() async {
    final p = await _settings.load();
    if (!mounted) return;
    setState(() => _preferences = p);
    await _speech.init(language: p.language, rate: p.rate);
  }

  Future<void> _say(String s) async {
    if (!mounted) return;
    setState(() => _last = s);
    await _speech.speak(s);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _microphone.cancel();
      _speech.stop();
      _positions?.cancel();
      _positions = null;
      _watchdog?.cancel();
      if (mounted)
        setState(() {
          _listening = false;
          _guiding = false;
          _status = tr(
            'Сопровождение приостановлено. Вернитесь в приложение и продолжите.',
            'Бағыттау тоқтатылды. Қолданбаға оралып, жалғастырыңыз.',
          );
        });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _operation++;
    _positions?.cancel();
    _watchdog?.cancel();
    _microphone.cancel();
    _speech.dispose();
    _navigation.dispose();
    _query.dispose();
    _command.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    final token = ++_operation;
    setState(() => _busy = true);
    await _microphone.cancel();
    if (mounted) setState(() => _listening = false);
    try {
      final result = await action();
      if (mounted && token == _operation) await _say(result);
    } catch (_) {
      if (mounted && token == _operation)
        await _say(
          tr(
            'Не удалось выполнить действие. Проверьте разрешения, освещение и интернет. Попробуйте ещё раз.',
            'Әрекет орындалмады. Рұқсаттарды, жарықты және интернетті тексеріп, қайталаңыз.',
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _describe() => _run(() async {
    await _say(
      tr(
        'Распознаю. Держите телефон неподвижно.',
        'Танып жатырмын. Телефонды қозғалтпай ұстаңыз.',
      ),
    );
    final recognizer = CameraSceneRecognizer();
    try {
      return SceneNarrator.describe(
        await recognizer.describeScene(),
        _preferences.language,
      );
    } finally {
      await recognizer.dispose();
    }
  });
  Future<void> _read() => _run(() async {
    await _say(
      tr(
        'Читаю текст. Наведите камеру на хорошо освещённую надпись.',
        'Мәтінді оқып жатырмын. Камераны жарық түсетін жазуға бағыттаңыз.',
      ),
    );
    final r = await DeviceTextReader().read(kk);
    return r.text.isEmpty
        ? tr(
            'Не удалось уверенно прочитать. Держите телефон ровно и улучшите освещение.',
            'Мәтін анық танылмады. Телефонды түзу ұстап, жарықты жақсартыңыз.',
          )
        : tr(
            'Распознанный текст может содержать ошибки. ${r.text}',
            'Танылған мәтінде қате болуы мүмкін. ${r.text}',
          );
  });
  Future<Position> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled())
      throw StateError('location_off');
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever)
      throw StateError('location_denied');
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    if (mounted) setState(() => _position = p);
    return p;
  }

  Future<void> _where() => _run(() async {
    final p = await _locate();
    return tr(
      'Координаты ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}. Точность GPS примерно ${p.accuracy.round()} метров.',
      'Координаттар ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}. GPS дәлдігі шамамен ${p.accuracy.round()} метр.',
    );
  });
  Future<bool> _networkConsent() async {
    if (_consent) return true;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Построить маршрут', 'Бағыт құру')),
        content: Text(
          tr(
            'Поиск адреса и координаты начала и конца маршрута отправляются сервисам OpenStreetMap. Фотографии остаются на устройстве.',
            'Мекенжай іздеуі мен маршруттың бастапқы және соңғы координаттары OpenStreetMap сервистеріне жіберіледі. Суреттер құрылғыда қалады.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr('Отмена', 'Бас тарту')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Продолжить', 'Жалғастыру')),
          ),
        ],
      ),
    );
    _consent = allowed ?? false;
    return _consent;
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 3) {
      await _say(
        tr('Введите хотя бы три буквы.', 'Кемінде үш әріп енгізіңіз.'),
      );
      return;
    }
    if (!await _networkConsent()) return;
    await _run(() async {
      final p = await _navigation.search(_query.text);
      if (mounted) setState(() => _places = p);
      return p.isEmpty
          ? tr(
              'Место в Алматы не найдено. Уточните адрес.',
              'Алматыда орын табылмады. Мекенжайды нақтылаңыз.',
            )
          : tr(
              'Найдено ${p.length}. Выберите нужный адрес.',
              '${p.length} орын табылды. Мекенжайды таңдаңыз.',
            );
    });
  }

  Future<void> _buildRoute(Place destination) async {
    if (!await _networkConsent()) return;
    await _run(() async {
      final p = await _locate();
      if (p.accuracy > 35)
        return tr(
          'GPS пока неточен. Подождите на открытом месте и повторите.',
          'GPS дәл емес. Ашық жерде күтіп, қайталаңыз.',
        );
      final r = await _navigation.route(
        LatLng(p.latitude, p.longitude),
        destination,
      );
      if (mounted)
        setState(() {
          _route = r;
          _progress = RouteProgress(r);
          _places = [];
          _guiding = false;
        });
      return tr(
        'Маршрут ${(r.distance / 1000).toStringAsFixed(1)} км, примерно ${(r.duration / 60).ceil()} минут. Проверьте маршрут и нажмите «Начать».',
        'Бағыт ${(r.distance / 1000).toStringAsFixed(1)} км, шамамен ${(r.duration / 60).ceil()} минут. Бағытты тексеріп, «Бастау» түймесін басыңыз.',
      );
    });
  }

  Future<void> _startRoute() async {
    if (_route == null) return;
    await _positions?.cancel();
    setState(() => _guiding = true);
    await _say(
      tr(
        'Сопровождение включено. Держите приложение открытым. GPS не определяет препятствия и безопасность перехода.',
        'Бағыттау қосылды. Қолданбаны ашық ұстаңыз. GPS кедергілерді және өткел қауіпсіздігін анықтамайды.',
      ),
    );
    _positions =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 3,
          ),
        ).listen(
          _onPosition,
          onError: (Object e) {
            if (mounted) setState(() => _guiding = false);
            _say(
              tr(
                'GPS недоступен. Сопровождение остановлено.',
                'GPS қолжетімсіз. Бағыттау тоқтатылды.',
              ),
            );
          },
        );
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 10), (timer) {
      final p = _position;
      if (_guiding &&
          (p == null ||
              DateTime.now().difference(p.timestamp).inSeconds > 20)) {
        _alert(
          tr(
            'Сигнал GPS устарел. Дождитесь точного положения.',
            'GPS сигналы ескірді. Дәл орынды күтіңіз.',
          ),
        );
      }
    });
  }

  void _alert(String s) {
    if (DateTime.now().difference(_lastAlert).inSeconds < 20) return;
    _lastAlert = DateTime.now();
    _say(s);
  }

  void _onPosition(Position p) {
    if (!mounted || !_guiding) return;
    final progress = _progress!;
    final changed = progress.update(
      LatLng(p.latitude, p.longitude),
      p.accuracy,
      p.timestamp,
    );
    setState(() => _position = p);
    if (progress.uncertain) {
      _alert(
        tr(
          'GPS неточен. Подсказки поворотов приостановлены.',
          'GPS дәл емес. Бұрылыс нұсқаулары тоқтатылды.',
        ),
      );
      return;
    }
    if (progress.offRoute) {
      _alert(
        tr(
          'Вы, возможно, отклонились. Остановитесь в безопасном месте и перестройте маршрут.',
          'Бағыттан ауытқуыңыз мүмкін. Қауіпсіз жерде тоқтап, бағытты қайта құрыңыз.',
        ),
      );
      return;
    }
    if (progress.arrived) {
      _positions?.cancel();
      _watchdog?.cancel();
      setState(() => _guiding = false);
      _say(
        tr(
          'Вы рядом с местом назначения. Найдите вход с помощью камеры или помощника.',
          'Межелі жерге жақындадыңыз. Камера немесе көмекші арқылы кіреберісті табыңыз.',
        ),
      );
      return;
    }
    if (changed && progress.current != null)
      _say(progress.current!.instruction(kk));
  }

  Future<void> _stop() async {
    _operation++;
    await _microphone.cancel();
    await _speech.stop();
    await _positions?.cancel();
    _positions = null;
    _watchdog?.cancel();
    if (mounted)
      setState(() {
        _guiding = false;
        _listening = false;
        _last = tr('Остановлено', 'Тоқтатылды');
      });
  }

  Future<void> _listen() async {
    if (_busy) return;
    if (_listening) {
      await _microphone.stop();
      setState(() => _listening = false);
      return;
    }
    await _speech.stop();
    final ready = await _microphone.initialize(
      onStatus: (s) {
        if (mounted && s != 'listening') setState(() => _listening = false);
      },
      onError: (e) {
        if (mounted) setState(() => _listening = false);
        _say(
          tr(
            'Голосовой ввод недоступен. Можно написать команду.',
            'Дауыстық енгізу қолжетімсіз. Пәрменді жазуға болады.',
          ),
        );
      },
    );
    if (!ready) {
      await _say(
        tr(
          'Разрешите микрофон или напишите команду.',
          'Микрофонға рұқсат беріңіз немесе пәрменді жазыңыз.',
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _microphone.listen(
      localeId: kk ? 'kk_KZ' : 'ru_RU',
      onResult: (r) {
        if (mounted) setState(() => _command.text = r.recognizedWords);
        if (r.finalResult) _execute(r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _execute(String input) async {
    final c = AssistantCommand.parse(input);
    switch (c.action) {
      case AssistantAction.describe:
        await _describe();
      case AssistantAction.read:
        await _read();
      case AssistantAction.repeat:
        await _speech.speak(_last);
      case AssistantAction.stop:
        await _stop();
      case AssistantAction.location:
        await _where();
      case AssistantAction.navigate:
        setState(() {
          _tab = 1;
          _query.text = c.query;
        });
        await _search();
      case AssistantAction.help:
      case AssistantAction.unknown:
        await _say(
          tr(
            'Я понимаю: «что передо мной», «прочитай текст», «найди парк», «где я», «повтори», «стоп». Сейчас это помощник для действий, свободный разговор ещё не подключён.',
            '«Айналаны сипатта», «мәтінді оқып бер», «қайдамын», «қайтала», «тоқта» пәрмендерін түсінемін. Еркін әңгімелесу әлі қосылмаған.',
          ),
        );
    }
  }

  Future<void> _language() async {
    final next = _preferences.copyWith(language: _preferences.language.toggled);
    setState(() => _preferences = next);
    await _settings.save(next);
    await _speech.setLanguage(next.language);
    await _say(
      _speech.usingFallbackVoice
          ? tr(
              'Выбранный голос отсутствует. Используется доступный голос устройства.',
              'Таңдалған дауыс жоқ. Құрылғыдағы қолжетімді дауыс қолданылады.',
            )
          : tr('Русский язык', 'Қазақ тілі'),
    );
  }

  Widget _button(
    String label,
    IconData icon,
    VoidCallback action, {
    bool primary = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SizedBox(
      width: double.infinity,
      child: primary
          ? FilledButton.icon(
              onPressed: action,
              icon: Icon(icon, size: 30),
              label: Text(label),
              style: FilledButton.styleFrom(
                minimumSize: const Size(88, 80),
                textStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: action,
              icon: Icon(icon, size: 30),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(88, 76),
                textStyle: const TextStyle(fontSize: 21),
              ),
            ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (!_started)
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(28),
                children: [
                  const Icon(Icons.route, size: 72),
                  const SizedBox(height: 24),
                  const Text(
                    'Jaryq Jol',
                    style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      'Маршрут, камера и голос — в одном месте.',
                      'Бағыт, камера және дауыс — бір жерде.',
                    ),
                    style: const TextStyle(fontSize: 26),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(
                      'Это прототип помощника. Он не заменяет трость или сопровождающего и не определяет, безопасно ли переходить дорогу.',
                      'Бұл көмекші прототипі. Ол таяқты немесе сүйемелдеушіні алмастырмайды және жолдан өту қауіпсіздігін анықтамайды.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  _button(tr('Начать', 'Бастау'), Icons.play_arrow, () {
                    setState(() => _started = true);
                    _say(
                      tr(
                        'Jaryq Jol готов. Выберите маршрут, камеру или помощника.',
                        'Jaryq Jol дайын. Бағытты, камераны немесе көмекшіні таңдаңыз.',
                      ),
                    );
                  }, primary: true),
                  _button(
                    kk ? 'Русский' : 'Қазақша',
                    Icons.language,
                    _language,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jaryq Jol'),
        actions: [
          TextButton(onPressed: _language, child: Text(kk ? 'РУС' : 'ҚАЗ')),
          IconButton(
            tooltip: tr('Скорость речи', 'Сөйлеу жылдамдығы'),
            onPressed: () async {
              final next = _preferences.copyWith(rate: _preferences.rate.next);
              setState(() => _preferences = next);
              await _settings.save(next);
              await _speech.setRate(next.rate);
              await _say(AppStrings.of(next.language).speedName(next.rate));
            },
            icon: const Icon(Icons.speed),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_busy)
                  const LinearProgressIndicator(semanticsLabel: 'Обработка'),
                if (_status.isNotEmpty) Text(_status),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF143257),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _last.isEmpty
                          ? tr('Куда отправимся?', 'Қайда барамыз?')
                          : _last,
                      style: const TextStyle(fontSize: 25, height: 1.35),
                    ),
                  ),
                ),
                if (_tab == 0) ...[
                  _button(
                    tr('Описать окружение', 'Айналаны сипаттау'),
                    Icons.visibility,
                    _describe,
                    primary: true,
                  ),
                  _button(
                    tr('Прочитать текст', 'Мәтінді оқу'),
                    Icons.document_scanner,
                    _read,
                  ),
                  _button(
                    tr('Где я нахожусь', 'Мен қайдамын'),
                    Icons.my_location,
                    _where,
                  ),
                  Text(
                    tr(
                      'Камера не определяет безопасный путь. В темноте распознавание может не сработать.',
                      'Камера қауіпсіз жолды анықтамайды. Қараңғыда тану істемеуі мүмкін.',
                    ),
                  ),
                ],
                if (_tab == 1) ..._routeWidgets(),
                if (_tab == 2) ...[
                  _button(
                    _listening
                        ? tr('Завершить запись', 'Жазуды аяқтау')
                        : tr('Сказать команду', 'Пәрмен айту'),
                    _listening ? Icons.stop : Icons.mic,
                    _listen,
                    primary: true,
                  ),
                  Text(
                    tr(
                      'Например: «найди парк», «прочитай текст», «что передо мной».',
                      'Мысалы: «мәтінді оқып бер», «айналада не бар», «қайдамын».',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _command,
                    decoration: InputDecoration(
                      labelText: tr('Написать команду', 'Пәрмен жазу'),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: _execute,
                  ),
                  const SizedBox(height: 12),
                  _button(
                    tr('Выполнить', 'Орындау'),
                    Icons.send,
                    () => _execute(_command.text),
                  ),
                  Text(
                    tr(
                      'Распознавание речи зависит от устройства и может использовать интернет.',
                      'Сөйлеуді тану құрылғыға байланысты және интернетті пайдалануы мүмкін.',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _button(
                  tr('Повторить ответ', 'Жауапты қайталау'),
                  Icons.replay,
                  () => _speech.speak(_last),
                ),
                _button(
                  tr('Остановить всё', 'Барлығын тоқтату'),
                  Icons.stop_circle,
                  _stop,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.visibility_outlined),
            label: tr('Камера', 'Камера'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.route),
            label: tr('Маршрут', 'Бағыт'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.mic_none),
            label: tr('Помощник', 'Көмекші'),
          ),
        ],
      ),
    );
  }

  List<Widget> _routeWidgets() {
    final r = _route;
    return [
      TextField(
        controller: _query,
        decoration: InputDecoration(
          labelText: tr('Куда в Алматы?', 'Алматыда қайда?'),
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => _search(),
      ),
      const SizedBox(height: 12),
      _button(
        tr('Найти место', 'Орынды табу'),
        Icons.search,
        _search,
        primary: true,
      ),
      ..._places.map(
        (p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OutlinedButton(
            onPressed: () => _buildRoute(p),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(p.name),
            ),
          ),
        ),
      ),
      if (r != null) ...[
        Text(
          r.destination.name,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          '${(r.distance / 1000).toStringAsFixed(1)} км · ${(r.duration / 60).ceil()} мин',
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 280,
          child: FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: r.points.first, initialZoom: 15),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'kz.jaryqjol.app',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: r.points,
                    color: const Color(0xFF2255DD),
                    strokeWidth: 6,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: r.destination.point,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 42,
                    ),
                  ),
                  if (_position != null)
                    Marker(
                      point: LatLng(_position!.latitude, _position!.longitude),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 32,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _button(
          _guiding
              ? tr('Сопровождение идёт', 'Бағыттау қосулы')
              : tr('Начать сопровождение', 'Бағыттауды бастау'),
          Icons.navigation,
          _startRoute,
          primary: true,
        ),
        if (_progress?.current != null)
          Text(
            _progress!.current!.instruction(kk),
            style: const TextStyle(fontSize: 26),
          ),
        if (_progress != null)
          Text(
            tr(
              'Осталось примерно ${_progress!.remaining.round()} м',
              'Шамамен ${_progress!.remaining.round()} м қалды',
            ),
          ),
        _button(
          tr('Перестроить маршрут', 'Бағытты қайта құру'),
          Icons.refresh,
          () => _buildRoute(r.destination),
        ),
        ...r.steps.map(
          (s) => ListTile(
            leading: const Icon(Icons.turn_right),
            title: Text(s.instruction(kk)),
            subtitle: Text('${s.distance.round()} м'),
          ),
        ),
      ],
      Text(
        tr(
          'Пешеходные маршруты: FOSSGIS / OpenStreetMap. Маршрут не учитывает все препятствия и освещение.',
          'Жаяу жүру бағыттары: FOSSGIS / OpenStreetMap. Маршрут барлық кедергілер мен жарықты ескермейді.',
        ),
      ),
      TextButton(
        onPressed: () =>
            launchUrl(Uri.parse('https://www.openstreetmap.org/fixthemap')),
        child: Text(tr('Сообщить об ошибке карты', 'Карта қатесін хабарлау')),
      ),
    ];
  }
}
