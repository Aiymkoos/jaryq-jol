import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:qamqor_vision/services/navigation_service.dart';

void main() {
  test('адрес называет улицу, дом и район, без города', () {
    expect(
      spokenAddress({
        'road': 'улица Сатпаева',
        'house_number': '22',
        'suburb': 'Коктем',
        'city': 'Алматы',
        'country': 'Казахстан',
      }),
      'улица Сатпаева, 22, Коктем',
    );
  });

  test('без улицы называется город, а не пустота', () {
    expect(spokenAddress({'footway': null, 'city': 'Алматы'}), 'Алматы');
    expect(spokenAddress(null), '');
  });

  test('пешеходная дорожка считается улицей', () {
    expect(
      spokenAddress({'footway': 'Арбат', 'city_district': 'Алмалинский район'}),
      'Арбат, Алмалинский район',
    );
  });

  test('адрес запрашивается на языке пользователя', () async {
    Uri? asked;
    final service = NavigationService(
      client: MockClient((request) async {
        asked = request.url;
        return http.Response(
          jsonEncode({
            'address': {'road': 'Абай даңғылы', 'suburb': 'Бостандық'},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final address = await service.addressAt(
      const LatLng(43.238, 76.945),
      kk: true,
    );
    expect(address, 'Абай даңғылы, Бостандық');
    expect(asked!.path, '/reverse');
    expect(asked!.queryParameters['accept-language'], 'kk,ru');
  });

  test('ошибка сервиса не выдаётся за адрес', () async {
    final service = NavigationService(
      client: MockClient((_) async => http.Response('busy', 503)),
    );
    expect(
      service.addressAt(const LatLng(43.238, 76.945), kk: false),
      throwsStateError,
    );
  });
}
