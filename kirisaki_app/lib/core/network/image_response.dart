import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Allow large images on slow links while rejecting stalled transfers.
Future<http.Response> fetchImageResponse(
  http.Client client,
  Uri uri, {
  Duration idleTimeout = const Duration(seconds: 30),
}) async {
  final response = await client
      .send(http.Request('GET', uri))
      .timeout(const Duration(seconds: 20));
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response.stream.timeout(idleTimeout)) {
    bytes.add(chunk);
  }
  return http.Response.bytes(
    bytes.takeBytes(),
    response.statusCode,
    headers: response.headers,
    request: response.request,
  );
}
