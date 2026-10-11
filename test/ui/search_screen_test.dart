import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nuvio_tv_flutter/domain/models/content_type.dart';
import 'package:nuvio_tv_flutter/domain/models/meta.dart';
import 'package:nuvio_tv_flutter/ui/screens/search/search_screen.dart';

void main() {
  MetaPreview _preview(String id, String name) => MetaPreview(
        id: id,
        type: ContentType.movie,
        name: name,
      );

  testWidgets('keyboard renders and typing builds query', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pump();

    // Tap letters on the keyboard.
    await tester.tap(find.text('T'));
    await tester.pump();
    await tester.tap(find.text('E'));
    await tester.pump();
    await tester.tap(find.text('S'));
    await tester.pump();
    await tester.tap(find.text('T'));
    await tester.pump();

    expect(find.text('TEST'), findsOneWidget);
  });

  testWidgets('backspace removes last char', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pump();

    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(find.text('AB'), findsOneWidget);

    await tester.tap(find.text('⌫'));
    await tester.pump();
    // Query is now 'A' (shown in display AND as keyboard key = 2 matches).
    expect(find.text('A'), findsNWidgets(2));
  });

  testWidgets('CLR clears query and results', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SearchScreen()));
    await tester.pump();

    await tester.tap(find.text('X'));
    await tester.pump();
    await tester.tap(find.text('CLR'));
    await tester.pump();
    expect(find.text('Search…'), findsOneWidget);
    expect(find.text('X'), findsOneWidget); // only keyboard key remains
  });

  testWidgets('search fires debounced with query and shows results',
      (tester) async {
    List<MetaPreview> Function(String)? captured;
    await tester.pumpWidget(MaterialApp(
      home: SearchScreen(
        onSearch: (query) async {
          captured = (_) => [];
          return [_preview('tt1', 'Result for $query')];
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('H'));
    await tester.pump();
    await tester.tap(find.text('I'));
    await tester.pump();

    // Debounce 300ms.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.text('Result for HI'), findsOneWidget);
  });

  testWidgets('short queries do not search', (tester) async {
    var searchCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: SearchScreen(
        onSearch: (query) async {
          searchCalls++;
          return const [];
        },
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('A'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(searchCalls, 0);
  });
}
