import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_with_value/src/stream_with_value.dart';
import 'package:stream_with_value/src/stream_with_value_builder.dart';

void main() {
  testWidgets('StreamBuilderWithValue', (WidgetTester tester) async {
    final sv = PushStreamWithValue<int>();
    await tester.pumpWidget(MaterialApp(
      home: StreamBuilderWithValue(
        streamWithValue: sv,
        builder: (context, snapshot) {
          return snapshot.hasData
              ? Text(snapshot.data.toString())
              : Text('n/a');
        },
      ),
    ));
    expect(find.text('n/a'), findsOneWidget);

    sv.add(42);
    await tester.pump();
    expect(find.text('n/a'), findsNothing);
    expect(find.text('42'), findsOneWidget);

    sv.close();
    await tester.pump();
    expect(find.text('n/a'), findsNothing);
    expect(find.text('42'), findsOneWidget);
  });

  group('DataStreamWithValueBuilder', () {
    testWidgets('builder', (WidgetTester tester) async {
      final sv = PushStreamWithValue<int?>();
      await tester.pumpWidget(MaterialApp(
        home: DataStreamWithValueBuilder(
          streamWithValue: sv,
          builder: (context, data) => Text(data.toString()),
        ),
      ));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      sv.add(42);
      await tester.pump();
      expect(find.text('42'), findsOneWidget);

      sv.add(43);
      await tester.pump();
      expect(find.text('43'), findsOneWidget);

      sv.add(null);
      // Duration workaround for https://github.com/flutter/flutter/issues/79565
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('43'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      sv.add(44);
      await tester.pump();
      expect(find.text('44'), findsOneWidget);

      await tester.runAsync(sv.close);
      // After closure, DataStreamWithValueBuilder calls Navigator.pop. This
      // needs pumpAndSettle and afterwards, no widgets will remain.
      await tester.pumpAndSettle();
      expect(find.text('44'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('already initialized', (WidgetTester tester) async {
      final sv = PushStreamWithValue<int?>.withInitialValue(42);
      await tester.pumpWidget(MaterialApp(
        home: DataStreamWithValueBuilder(
          streamWithValue: sv,
          builder: (context, data) => Text(data.toString()),
        ),
      ));
      expect(find.text('42'), findsOneWidget);

      await tester.runAsync(sv.close);
      await tester.pumpAndSettle();
      expect(find.text('42'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('onData / onError callbacks', (WidgetTester tester) async {
      final controller = StreamController<int>();
      final sv = StreamWithLatestValue<int>(controller.stream);
      final data = <int>[];
      final errors = <dynamic>[];
      await tester.pumpWidget(MaterialApp(
        home: DataStreamWithValueBuilder(
          streamWithValue: sv,
          builder: (context, data) => Text(data.toString()),
          onData: data.add,
          onError: (error, stackTrace) => errors.add(error),
        ),
      ));

      controller.add(42);
      await tester.pump();
      expect(data, [42]);

      controller.addError(Exception());
      await tester.pump();
      expect(errors, isNotEmpty);

      // Expect UI to be unaffected by errors.
      expect(find.text('42'), findsOneWidget);

      await tester.runAsync(controller.close);
      await tester.pumpAndSettle(const Duration(milliseconds: 1));
      expect(find.text('42'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('onData triggered when already initialized',
        (WidgetTester tester) async {
      final sv = PushStreamWithValue<int>.withInitialValue(42);
      final data = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: DataStreamWithValueBuilder(
          streamWithValue: sv,
          builder: (context, data) => Text(data.toString()),
          onData: data.add,
        ),
      ));
      expect(find.text('42'), findsOneWidget);
      expect(data, [42]);
      await tester.runAsync(sv.close);
    });
  });
}
