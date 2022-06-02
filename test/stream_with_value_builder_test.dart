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
    testWidgets('correctly builds loading screen or calls builder',
        (WidgetTester tester) async {
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

      await tester.runAsync(sv.close);
      // After closure, DataStreamWithValueBuilder calls Navigator.pop. This
      // needs pumpAndSettle and afterwards, no widgets will remain.
      await tester.pumpAndSettle();
      expect(find.text('43'), findsNothing);
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
      final data = <int?>[];
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
      final data = <int?>[];
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

    testWidgets('Widget is rebuilt with new stream when it is updated',
        (WidgetTester tester) async {
      final swvHello = PushStreamWithValue<String>.withInitialValue('Hello');
      final currentSWV = ValueNotifier<StreamWithValue<String>>(swvHello);
      final dataRecorder = <String?>[];

      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<StreamWithValue<String>>(
          valueListenable: currentSWV,
          builder: (context, swv, child) => DataStreamWithValueBuilder(
            streamWithValue: swv,
            builder: (context, data) => Text(data.toString()),
            onData: dataRecorder.add,
          ),
        ),
      ));
      expect(find.text('Hello'), findsOneWidget);
      expect(dataRecorder, ['Hello']);

      final swvBye = PushStreamWithValue<String>.withInitialValue('Bye');
      currentSWV.value = swvBye;
      await tester.pump();
      expect(find.text('Bye'), findsOneWidget);
      expect(dataRecorder, ['Hello', 'Bye']);

      swvBye.add('Goodbye!');
      // Unlike this test, our stream is truly asynchronous: wait for the value
      // addition to propagade before trying to trigger the next frame.
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Goodbye!'), findsOneWidget);
      expect(dataRecorder, ['Hello', 'Bye', 'Goodbye!']);

      await tester.runAsync(swvHello.close);
      await tester.runAsync(swvBye.close);
    });

    testWidgets('onError handler can be replaced', (WidgetTester tester) async {
      final swv = PushStreamWithValue<String>.withInitialValue('Hello');
      final caughtErrors = [], uncaughtErrors = [];
      final errorHandler = ValueNotifier<void Function(dynamic, StackTrace)?>(
        (error, stack) => caughtErrors.add(error),
      );

      // The errors are propagated from the Stream.listen call, i.e. on the
      // initial widget build.  That's where we should install the zone handler.
      await runZonedGuarded(
        () => tester.pumpWidget(
          MaterialApp(
            home: ValueListenableBuilder<void Function(dynamic, StackTrace)?>(
              valueListenable: errorHandler,
              builder: (context, onError, child) => DataStreamWithValueBuilder(
                streamWithValue: swv,
                builder: (context, data) => Text(data.toString()),
                onError: onError,
              ),
            ),
          ),
        ),
        (error, stack) {
          uncaughtErrors.add(error);
        },
      );

      swv.addError(Exception('This should be caught by callback'));
      await tester.runAsync(pumpEventQueue);
      expect(caughtErrors.length, 1);
      expect(caughtErrors[0], isA<Exception>());
      expect(uncaughtErrors, isEmpty);

      errorHandler.value = null;
      await tester.pump();
      swv.addError(Exception('This will be propagated to default handler'));
      await tester.runAsync(pumpEventQueue);
      expect(caughtErrors.length, 1);
      expect(uncaughtErrors.length, 1);
      expect(uncaughtErrors[0], isA<Exception>());

      await tester.runAsync(swv.close);
    });

    testWidgets('null values are ignored when nullValueBuilder is unset',
        (WidgetTester tester) async {
      final swv = PushStreamWithValue<String?>.withInitialValue('Hello');

      await tester.pumpWidget(
        MaterialApp(
          home: DataStreamWithValueBuilder(
            streamWithValue: swv,
            builder: (context, data) => Text(data.toString()),
          ),
        ),
      );
      expect(find.text('Hello'), findsOneWidget);

      swv.add(null);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Hello'), findsOneWidget);

      swv.add('Bye!');
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Hello'), findsNothing);
      expect(find.text('Bye!'), findsOneWidget);

      await tester.runAsync(swv.close);
    });

    testWidgets('null values (including init) are built with nullValueBuilder',
        (WidgetTester tester) async {
      final swv = PushStreamWithValue<String?>.withInitialValue(null);

      await tester.pumpWidget(
        MaterialApp(
          home: DataStreamWithValueBuilder(
            streamWithValue: swv,
            builder: (context, data) => Text(data.toString()),
            nullValueBuilder: (context) => Center(
              child: CircularProgressIndicator(),
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      swv.add(null);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      swv.add('Hello');
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Hello'), findsOneWidget);

      swv.add(null);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Hello'), findsNothing);

      await tester.runAsync(swv.close);
    });

    testWidgets('recovers after null when rebuilt with nullValueBuilder unset',
        (WidgetTester tester) async {
      final swv = PushStreamWithValue<String?>.withInitialValue('Hello');
      final currentNullValueBuilder = ValueNotifier<NullValueBuilder?>(
        (_) => Text('null!'),
      );

      await tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<NullValueBuilder?>(
          valueListenable: currentNullValueBuilder,
          builder: (context, nullValueBuilder, child) =>
              DataStreamWithValueBuilder(
            streamWithValue: swv,
            nullValueBuilder: nullValueBuilder,
            builder: (context, data) => Text(data.toString()),
          ),
        ),
      ));
      expect(find.text('Hello'), findsOneWidget);

      swv.add(null);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('null!'), findsOneWidget);

      currentNullValueBuilder.value = null;
      await tester.pump();
      expect(find.text('null!'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      swv.add('Bye!');
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Bye!'), findsOneWidget);

      // This null should be ignored since we unset nullValueBuilder.
      swv.add(null);
      await tester.runAsync(pumpEventQueue);
      await tester.pump();
      expect(find.text('Bye!'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.runAsync(swv.close);
    });

    testWidgets('does not pop the same route more than once',
        (WidgetTester tester) async {
      final swv = PushStreamWithValue<String>.withInitialValue('Hello');

      await tester.pumpWidget(MaterialApp(
        home: _ExtraRoutePusher(
          child: DataStreamWithValueBuilder(
            streamWithValue: swv,
            builder: (context, data) => DataStreamWithValueBuilder(
              streamWithValue: swv,
              builder: (context, data) => Text(data.toString()),
            ),
          ),
        ),
      ));

      expect(find.text('First widget'), findsOneWidget);

      // Push that extra route (with animation).
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);

      await tester.runAsync(swv.close);
      // Wait until the route is popped (with animation).
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsNothing);
      // First widget still there.
      expect(find.text('First widget'), findsOneWidget);
    });
  });
}

class _ExtraRoutePusher extends StatefulWidget {
  final Widget child;

  const _ExtraRoutePusher({required this.child, Key? key}) : super(key: key);

  @override
  State<_ExtraRoutePusher> createState() => _ExtraRoutePusherState();
}

/// This allows a value of type T or T?
/// to be treated as a value of type T?.
///
/// We use this so that APIs that have become
/// non-nullable can still be used with `!` and `?`
/// to support older versions of the API as well.
///
/// https://docs.flutter.dev/development/tools/sdk/release-notes/release-notes-3.0.0#if-you-see-warnings-about-bindings
T? _ambiguate<T>(T value) => value;

class _ExtraRoutePusherState extends State<_ExtraRoutePusher> {
  @override
  void initState() {
    super.initState();
    _ambiguate(WidgetsBinding.instance)!.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => widget.child),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(body: Text('First widget'));
}
