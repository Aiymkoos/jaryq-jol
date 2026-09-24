import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Street and house first, then district; the city only when there is no
/// street. Same rule as the web app's address.js.
String spokenAddress(Map<String, dynamic>? a) {
  if (a == null) return '';
  final street = a['road'] ?? a['pedestrian'] ?? a['footway'];
  final area = a['suburb'] ?? a['neighbourhood'] ?? a['city_district'];
  final city = a['city'] ?? a['town'] ?? a['village'];
  final house = a['house_number'];
  return [
    if (street != null) house != null ? '$street, $house' : '$street',
    if (area != null) '$area',
    if (street == null && city != null) '$city',
  ].join(', ');
}

class Place {
  const Place(this.name, this.point);
  final String name;
  final LatLng point;
}

class WalkStep {
  const WalkStep(
    this.point,
    this.type,
    this.modifier,
    this.road,
    this.distance,
  );
  final LatLng point;
  final String type, modifier, road;
  final double distance;
  String instruction(bool kk) {
    if (type == 'arrive') {
      return kk ? 'Межелі жерге жақындадыңыз' : 'Вы рядом с местом назначения';
    }
    final directions = kk
        ? {
            'left': 'солға',
            'right': 'оңға',
            'slight left': 'сәл солға',
            'slight right': 'сәл оңға',
            'sharp left': 'солға күрт',
            'sharp right': 'оңға күрт',
            'uturn': 'кері',
          }
        : {
            'left': 'налево',
            'right': 'направо',
            'slight left': 'немного налево',
            'slight right': 'немного направо',
            'sharp left': 'резко налево',
            'sharp right': 'резко направо',
            'uturn': 'назад',
          };
    final direction = directions[modifier];
    final action = type == 'depart'
        ? (kk ? 'Маршрут бойымен жүріңіз' : 'Начните движение по маршруту')
        : type == 'roundabout' || type == 'rotary'
        ? (kk
              ? 'Алда айналма жол. Өткелді тексеріңіз'
              : 'Впереди круговой перекрёсток. Проверьте переход')
        : direction != null
        ? (kk ? '$direction бұрылыңыз' : 'Поверните $direction')
        : (kk ? 'Түзу жүріңіз' : 'Продолжайте прямо');
    return road.isEmpty ? action : '$action · $road';
  }
}

class WalkRoute {
  WalkRoute(
    this.points,
    this.steps,
    this.distance,
    this.duration,
    this.destination,
  );
  final List<LatLng> points;
  final List<WalkStep> steps;
  final double distance, duration;
  final Place destination;
}

class NavigationService {
  NavigationService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, List<Place>> _cache = {};
  DateTime _lastRequest = DateTime(2000);
  Future<void> _throttle() async {
    final wait = 1100 - DateTime.now().difference(_lastRequest).inMilliseconds;
    if (wait > 0) await Future<void>.delayed(Duration(milliseconds: wait));
    _lastRequest = DateTime.now();
  }

  Future<List<Place>> search(String query) async {
    final q = query.trim();
    if (q.length < 3) return [];
    if (_cache.containsKey(q)) return _cache[q]!;
    await _throttle();
    // Explicit searches only, no autocomplete or background scraping.
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': '$q, Алматы',
      'format': 'jsonv2',
      'limit': '5',
      'countrycodes': 'kz',
      'accept-language': 'ru',
      'viewbox': '76.7,43.4,77.2,43.05',
      'bounded': '1',
    });
    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'JaryqJol/1.0 (accessible walking prototype)',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) throw StateError('search_unavailable');
    final data = jsonDecode(response.body) as List;
    final result = data
        .map(
          (dynamic p) => Place(
            p['display_name'] as String,
            LatLng(
              double.parse(p['lat'] as String),
              double.parse(p['lon'] as String),
            ),
          ),
        )
        .toList();
    _cache[q] = result;
    return result;
  }

  /// Spoken address at [point], or empty when the map knows none there.
  Future<String> addressAt(LatLng point, {required bool kk}) async {
    await _throttle();
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': point.latitude.toStringAsFixed(6),
      'lon': point.longitude.toStringAsFixed(6),
      'format': 'jsonv2',
      'zoom': '18',
      'accept-language': kk ? 'kk,ru' : 'ru',
    });
    // Shorter than search: the person is standing still waiting to hear it.
    final response = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'JaryqJol/1.0 (accessible walking prototype)',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw StateError('address_unavailable');
    final data = jsonDecode(response.body);
    return spokenAddress(
      data is Map<String, dynamic>
          ? data['address'] as Map<String, dynamic>?
          : null,
    );
  }

  Future<WalkRoute> route(LatLng from, Place to) async {
    await _throttle();
    // routed-foot is a dedicated pedestrian graph; not the car demo endpoint.
    final base = const String.fromEnvironment(
      'ROUTING_BASE',
      defaultValue: 'https://routing.openstreetmap.de/routed-foot',
    );
    final uri = Uri.parse(
      '$base/route/v1/foot/${from.longitude},${from.latitude};${to.point.longitude},${to.point.latitude}?overview=full&geometries=geojson&steps=true',
    );
    final r = await _client
        .get(
          uri,
          headers: {
            'User-Agent': 'JaryqJol/1.0 (accessible walking prototype)',
          },
        )
        .timeout(const Duration(seconds: 25));
    if (r.statusCode != 200) throw StateError('route_unavailable');
    return parseRoute(jsonDecode(r.body) as Map<String, dynamic>, to);
  }

  static WalkRoute parseRoute(Map<String, dynamic> data, Place to) {
    if (data['code'] != 'Ok' || (data['routes'] as List).isEmpty) {
      throw StateError('no_route');
    }
    final route = data['routes'][0];
    final points = (route['geometry']['coordinates'] as List)
        .map(
          (dynamic p) =>
              LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
        )
        .toList();
    if (points.length < 2) throw StateError('no_route');
    final steps = <WalkStep>[];
    for (final leg in route['legs']) {
      for (final s in leg['steps']) {
        final m = s['maneuver'];
        final p = m['location'];
        steps.add(
          WalkStep(
            LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
            m['type'] as String,
            m['modifier'] as String? ?? '',
            s['name'] as String? ?? '',
            (s['distance'] as num).toDouble(),
          ),
        );
      }
    }
    return WalkRoute(
      points,
      steps,
      (route['distance'] as num).toDouble(),
      (route['duration'] as num).toDouble(),
      to,
    );
  }

  void dispose() => _client.close();
}

/// Independent of GPS plugins: rejects uncertain/stale fixes, never jumps across
/// a whole route based on proximity alone, and requires repeated arrival fixes.
class RouteProgress {
  RouteProgress(this.route) {
    cumulative = [0];
    for (var i = 1; i < route.points.length; i++) {
      cumulative.add(
        cumulative.last + meters(route.points[i - 1], route.points[i]),
      );
    }
  }
  final WalkRoute route;
  late final List<double> cumulative;
  double along = 0, distanceFromRoute = 0;
  int stepIndex = 0, _offCount = 0, _arrivalCount = 0;
  bool uncertain = true, offRoute = false, arrived = false;
  DateTime? _lastFix;
  static double meters(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b);
  double get remaining => math.max(0, cumulative.last - along);
  WalkStep? get current =>
      stepIndex < route.steps.length ? route.steps[stepIndex] : null;
  bool update(LatLng p, double accuracy, DateTime timestamp, {DateTime? now}) {
    if (!accuracy.isFinite ||
        accuracy < 0 ||
        accuracy > 35 ||
        (now ?? DateTime.now()).difference(timestamp).inSeconds > 20) {
      uncertain = true;
      _arrivalCount = 0;
      return false;
    }
    if (_lastFix != null && !timestamp.isAfter(_lastFix!)) return false;
    uncertain = false;
    _lastFix = timestamp;
    double best = double.infinity, candidate = along;
    final latScale = 111320.0,
        lonScale = 111320.0 * math.cos(p.latitude * math.pi / 180);
    for (var i = 0; i < route.points.length - 1; i++) {
      if (cumulative[i + 1] < along - 30 || cumulative[i] > along + 200) {
        continue;
      }
      final a = route.points[i], b = route.points[i + 1];
      final ax = (a.longitude - p.longitude) * lonScale,
          ay = (a.latitude - p.latitude) * latScale;
      final dx = (b.longitude - a.longitude) * lonScale,
          dy = (b.latitude - a.latitude) * latScale;
      final denom = dx * dx + dy * dy;
      final t = denom == 0
          ? 0.0
          : ((-ax * dx - ay * dy) / denom).clamp(0.0, 1.0);
      final d = math.sqrt(math.pow(ax + t * dx, 2) + math.pow(ay + t * dy, 2));
      if (d < best) {
        best = d;
        candidate = cumulative[i] + (cumulative[i + 1] - cumulative[i]) * t;
      }
    }
    distanceFromRoute = best;
    _offCount = best > math.max(40, accuracy * 1.5) ? _offCount + 1 : 0;
    offRoute = _offCount >= 3;
    if (best <= math.max(25, accuracy)) along = math.max(along, candidate);
    final old = stepIndex;
    if (!offRoute) {
      // Advance only through consecutive nearby maneuvers.
      while (stepIndex < route.steps.length - 1 &&
          meters(p, route.steps[stepIndex].point) < 18) {
        stepIndex++;
      }
    }
    final atEnd =
        remaining < 25 &&
        meters(p, route.destination.point) < 20 &&
        accuracy <= 20 &&
        !offRoute;
    _arrivalCount = atEnd ? _arrivalCount + 1 : 0;
    arrived = _arrivalCount >= 2;
    return old != stepIndex;
  }
}
