import 'dart:async';

import 'package:stream_with_value/src/stream_with_value.dart';
import 'package:test/test.dart';

void main() {
  group('mapPerEvent', () {
    test('several listeners (pull model)', () async {
      final zeros = Stream.fromIterable(
        List.generate(10, (_) => 0),
      ).asBroadcastStream();

      var numberOfMapCalls = 0;
      final incremental = zeros.mapPerEvent((x) => x + numberOfMapCalls++);

      final outputs = await Future.wait(
        List.generate(10, (_) => incremental.toList()),
      );

      outputs.forEach(
        (output) => expect(output, List.generate(output.length, (x) => x)),
      );
    });

    test('several listeners (push model)', () async {
      final zeros = Stream.periodic(const Duration(microseconds: 1), (_) => 0)
          .take(10)
          .asBroadcastStream();

      var numberOfMapCalls = 0;
      final incremental = zeros.mapPerEvent((x) => x + numberOfMapCalls++);

      final outputs = await Future.wait(
        List.generate(10, (_) => incremental.toList()),
      );

      outputs.forEach(
        (output) => expect(output, List.generate(output.length, (x) => x)),
      );
    });

    test('non-broadcast stream', () {
      final emptyStream = Stream.fromIterable([0]).mapPerEvent((event) => null);
      expect(
        () => emptyStream
          ..listen(((value) => null))
          ..listen(((value) => null)),
        throwsA(const TypeMatcher<StateError>()),
      );
    });
  });

  group('StreamWithLatestValue', () {
    test('takes initialValue', () {
      final sv = StreamWithLatestValue.withInitialValue(
        const Stream<int>.empty(),
        initialValue: 42,
      );
      expect(sv.loaded, true);
      expect(sv.value, 42);
    });

    test('updates value when it arrives', () async {
      final sv = StreamWithLatestValue(Stream.fromIterable([0, 1, 2]));
      expect(sv.loaded, false);

      expect(await sv.updates.first, 0);
      expect(sv.loaded, true);
      expect(sv.value, 0);
    });

    test('does not update value when there is no listener', () async {
      final source = StreamController<int>.broadcast();
      final sv = StreamWithLatestValue(source.stream);
      expect(sv.loaded, false);
      source.add(0);
      expect(sv.loaded, false);

      final first = sv.updates.first;
      source.add(1);
      expect(await first, 1);
      expect(sv.loaded, true);
      expect(sv.value, 1);

      await source.close();

      expect(sv.loaded, true);
      expect(sv.value, 1);
    });

    test('recognizes null as loaded (even from initialValue)', () async {
      final sv = StreamWithLatestValue.withInitialValue(
        Stream.fromIterable([0, null, 1]).asBroadcastStream(),
        initialValue: null,
      );
      expect(sv.loaded, true);

      expect(await sv.updates.first, 0);
      expect(sv.loaded, true);
      expect(sv.value, 0);

      expect(await sv.updates.first, null);
      expect(sv.loaded, true);
      expect(sv.value, null);
    });

    test('pauses the original stream when updates subscription does', () async {
      final source = StreamController<int>();
      final sv = StreamWithLatestValue(source.stream);

      final subscription = sv.updates.listen((event) {});
      subscription.pause();
      expect(source.isPaused, true);
      subscription.resume();
      expect(source.isPaused, false);
      await subscription.cancel();
      await source.close();
    });

    test('closes when the original stream is closed', () async {
      final source = StreamController<int>();
      final sv = StreamWithLatestValue(source.stream);
      expectLater(sv.updates, emitsInOrder([42, emitsDone]));
      source.add(42);
      await source.close();
    });
  });

  group('StreamWithValue.map extension', () {
    test('relays loaded and value', () async {
      final swv = StreamWithLatestValue<int>(Stream.fromIterable([1, 2, 3])),
          mapped = swv.map((x) => x + 1);
      expect(mapped.loaded, false);

      await swv.updates.first;
      expect(mapped.loaded, true);
      expect(mapped.value, swv.value + 1);
    });

    test('relays updates', () async {
      final swv = StreamWithLatestValue<int>(Stream.fromIterable([1, 2, 3])),
          mapped = swv.map((x) => x + 1);
      expect(await mapped.updates.toList(), [2, 3, 4]);
    });
  });

  group('StreamWithValue.valueOrNull extension', () {
    test('valueOrNull', () async {
      final swv = StreamWithLatestValue<int>(Stream.fromIterable([1, 2, 3]));
      expect(swv.valueOrNull, null);
      await swv.updates.first;
      expect(swv.valueOrNull, 1);
    });
  });

  group('StreamWithValue.valueWithUpdates extension', () {
    test('emits stream directly if no initial value given', () async {
      final swv = StreamWithLatestValue<int>(Stream.fromIterable([1, 2, 3]));
      expect(await swv.valueWithUpdates.first, 1);
    });

    test('emits value first if given', () async {
      final swv = StreamWithLatestValue<int>.withInitialValue(
        Stream.fromIterable([1, 2, 3]),
        initialValue: 42,
      );
      expect(await swv.valueWithUpdates.first, 42);
    });
  });

  group('PushStreamWithValue', () {
    test('takes initialValue', () {
      final sv = PushStreamWithValue.withInitialValue(42);
      expect(sv.loaded, true);
      expect(sv.value, 42);
      sv.close();
    });

    test('updates value on add()', () async {
      final sv = PushStreamWithValue.withInitialValue(42);
      expect(sv.loaded, true);
      expect(sv.value, 42);

      sv.add(43);
      expect(sv.loaded, true);
      expect(sv.value, 43);

      sv.close();
    });

    test('is not loaded without initialValue', () async {
      final sv = PushStreamWithValue();
      expect(sv.loaded, false);

      sv.add(42);
      expect(sv.loaded, true);
      expect(sv.value, 42);

      sv.close();
    });

    test('recognizes null as loaded (even from initialValue)', () async {
      final sv = PushStreamWithValue.withInitialValue(null);
      expect(sv.loaded, true);
      expect(sv.value, null);
      sv.close();
    });

    test('relays add*() to updates', () async {
      final sv = PushStreamWithValue();

      expectLater(
          sv.updates,
          emitsInOrder([
            42,
            emitsError('Failure'),
          ]));

      sv.add(42);
      expect(sv.loaded, true);
      expect(sv.value, 42);

      sv.addError('Failure');

      await sv.close();
    });
  });
}
