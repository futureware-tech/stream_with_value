import 'dart:async';

import 'package:fw_stream_with_value/src/stream_with_value.dart';
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
        () => emptyStream..listen((value) => null)..listen((value) => null),
        throwsA(const TypeMatcher<StateError>()),
      );
    });
  });

  group('StreamWithLatestValue', () {
    test('takes initialValue', () {
      final sv = StreamWithLatestValue(
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

    test('recognizes null as loaded (except from initialValue)', () async {
      final sv = StreamWithLatestValue(
        Stream.fromIterable([0, null, 1]).asBroadcastStream(),
        initialValue: null,
      );
      expect(sv.loaded, false);

      expect(await sv.updates.first, 0);
      expect(sv.loaded, true);
      expect(sv.value, 0);

      expect(await sv.updates.first, null);
      expect(sv.loaded, true);
      expect(sv.value, null);
    });
  });

  group('StreamWithValue.map extension', () {
    test('relays loaded and value', () async {
      final swv = StreamWithLatestValue(Stream.fromIterable([1, 2, 3])),
          mapped = swv.map((x) => x + 1);
      expect(mapped.loaded, false);

      await swv.updates.first;
      expect(mapped.loaded, true);
      expect(mapped.value, swv.value + 1);
    });

    test('relays updates', () async {
      final swv = StreamWithLatestValue(Stream.fromIterable([1, 2, 3])),
          mapped = swv.map((x) => x + 1);
      expect(await mapped.updates.toList(), [2, 3, 4]);
    });
  });
}
