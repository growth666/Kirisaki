import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kirisaki_app/core/network/original_image.dart';

void main() {
  testWidgets(
    'original image retries through the injected client after failure',
    (tester) async {
      var calls = 0;
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      );
      final client = MockClient(
        (_) async => ++calls == 1
            ? http.Response('', 503)
            : http.Response.bytes(bytes, 200),
      );
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: OriginalImage(
              url: 'https://example.test/original.png',
              client: client,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.text('图片加载失败'), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('重试图片'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('图片加载失败'), findsNothing);
    },
  );
}
