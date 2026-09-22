import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kirisaki_app/core/network/thumbnail_requests.dart';

void main() {
  test(
    'obsolete queued images are skipped and can be requested again',
    () async {
      var calls = 0;
      final requests = ThumbnailRequests(
        clientFactory: () => MockClient((_) async {
          calls++;
          return http.Response.bytes([1], 200);
        }),
      );
      await expectLater(
        requests.load('https://example.test/a', isNeeded: () => false),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 0);
      expect(await requests.load('https://example.test/a'), [1]);
      expect(calls, 1);
    },
  );
  test(
    'same URL shares transfer and queue limits concurrent requests',
    () async {
      final responses = <Completer<http.Response>>[];
      final requests = ThumbnailRequests(
        maxConcurrent: 1,
        clientFactory: () => MockClient((_) {
          final response = Completer<http.Response>();
          responses.add(response);
          return response.future;
        }),
      );
      final first = requests.load('https://example.test/a');
      final duplicate = requests.load('https://example.test/a');
      final second = requests.load('https://example.test/b');
      expect(identical(first, duplicate), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(responses.length, 1);
      responses.first.complete(http.Response.bytes([1], 200));
      expect(await first, [1]);
      await Future<void>.delayed(Duration.zero);
      expect(responses.length, 2);
      responses.last.complete(http.Response.bytes([2], 200));
      expect(await second, [2]);
    },
  );

  test('failure releases slot and permits retry', () async {
    var count = 0;
    final requests = ThumbnailRequests(
      maxConcurrent: 1,
      clientFactory: () => MockClient((_) async {
        count++;
        return http.Response.bytes([1], count == 1 ? 503 : 200);
      }),
    );
    await expectLater(
      requests.load('https://example.test/a'),
      throwsA(isA<http.ClientException>()),
    );
    expect(await requests.load('https://example.test/a'), [1]);
    expect(count, 2);
  });
}
