import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kirisaki_app/features/settings/presentation/pages/contributors_page.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'contributor list supports narrow screen and large text: $brightness',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const ContributorsPage(),
          ),
        );
        await tester.scrollUntilVisible(find.text('徐氏'), 180);
        expect(find.text('失去重力'), findsOneWidget);
        expect(find.text('徐氏'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('SuzumiyaAkizuki'), 180);
        expect(find.text('感谢词库 · DanbooruSearchOnline'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
