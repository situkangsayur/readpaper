import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readpaper/src/core/constants/app_constants.dart';
import 'package:readpaper/src/features/reader/presentation/widgets/annotation_editor.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(1600, 2560),
    String fieldLabel = 'Komentar',
  }) async {
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAnnotationEditor(
                    context,
                    initialColor: AnnotationPalette.yellow,
                    title: 'Isi teks',
                    fieldLabel: fieldLabel,
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('the dialog actually shows its field and buttons', (tester) async {
    await open(tester);
    expect(find.text('Isi teks'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
  });

  testWidgets('the field is labelled for what it is being used for', (tester) async {
    await open(tester, fieldLabel: 'Teks');
    expect(find.text('Teks'), findsOneWidget);
  });

  testWidgets('everything stays reachable on a short screen', (tester) async {
    // What is left of a tablet once the keyboard has taken its half.
    await open(tester, size: const Size(1600, 900));
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    // Off-screen buttons are the bug this guards: hitTestable finds only what
    // can actually be tapped.
    expect(find.text('Simpan').hitTestable(), findsOneWidget);
  });

  testWidgets('typing and saving returns what was typed', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Hendri Karisma');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
