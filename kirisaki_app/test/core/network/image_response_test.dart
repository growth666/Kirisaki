import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kirisaki_app/core/network/image_response.dart';

class _StreamingClient extends http.BaseClient {
  _StreamingClient(this.body);
  final Stream<List<int>> body;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(body, 200);
}

void main() {
  test(
    'total transfer may exceed idle timeout while bytes keep arriving',
    () async {
      final stream = Stream<List<int>>.periodic(
        const Duration(milliseconds: 100),
        (i) => [i],
      ).take(5);
      final result = await fetchImageResponse(
        _StreamingClient(stream),
        Uri.parse('https://example.test/image'),
        idleTimeout: const Duration(milliseconds: 300),
      );
      expect(result.bodyBytes, [0, 1, 2, 3, 4]);
    },
  );
  test('stalled body fails and cancels its subscription', () async {
    var cancelled = false;
    final body = StreamController<List<int>>(onCancel: () => cancelled = true);
    await expectLater(
      fetchImageResponse(
        _StreamingClient(body.stream),
        Uri.parse('https://example.test/image'),
        idleTimeout: const Duration(milliseconds: 50),
      ),
      throwsA(isA<TimeoutException>()),
    );
    expect(cancelled, true);
    await body.close();
  });
}
