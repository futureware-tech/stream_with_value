import 'dart:async';

abstract class StreamWithValue<T> {
  T get value;
  bool get loaded;

  /// Any changes to [value], in the form of a stream.
  /// The current [value] itself typically is not sent upon [Stream.listen] to
  /// [updates], although this detail is implementation defined.
  Stream<T> get updates;
}

typedef _Converter<TInput, TOutput> = TOutput Function(TInput event);

class _MappedStreamWithValue<TInput, TOutput>
    implements StreamWithValue<TOutput> {
  final StreamWithValue<TInput> _inputStream;
  final _Converter<TInput, TOutput> _convert;

  _MappedStreamWithValue(this._inputStream, this._convert);

  @override
  TOutput get value => _convert(_inputStream.value);

  @override
  bool get loaded => _inputStream.loaded;

  @override
  Stream<TOutput> get updates => _inputStream.updates.mapPerEvent(_convert);
}

/// We want [StreamWithValue] to be usable as an interface, rather than forcing
/// users to inherit from it, since it has no state.
/// Any implementations that can be useful are provided via this extension
/// instead.
extension StreamWithValueExtensions<TInput> on StreamWithValue<TInput> {
  StreamWithValue<TOutput> map<TOutput>(_Converter<TInput, TOutput> convert) =>
      _MappedStreamWithValue(this, convert);

  Stream<TInput> get valueWithUpdates async* {
    if (loaded) {
      yield value;
    }
    yield* updates;
  }
}

extension MapPerEvent<TInput> on Stream<TInput> {
  /// Like [map], but calls [convert] once per event, and not per listener.
  Stream<TOutput> mapPerEvent<TOutput>(_Converter<TInput, TOutput> convert) {
    late StreamController<TOutput> controller;
    late StreamSubscription<TInput> subscription;

    void onListen() {
      subscription = listen((event) => controller.add(convert(event)),
          onError: controller.addError, onDone: controller.close);
    }

    if (isBroadcast) {
      controller = StreamController<TOutput>.broadcast(
          onListen: onListen,
          onCancel: () => subscription.cancel(),
          sync: true);
    } else {
      controller = StreamController<TOutput>(
          onListen: onListen,
          onPause: () => subscription.pause(),
          onResume: () => subscription.resume(),
          onCancel: () => subscription.cancel(),
          sync: true);
    }

    return controller.stream;
  }
}

/// [StreamWithValue] implementation that wraps a [Stream] and keeps the latest
/// value that was received from it. Beware that for "push" model, where a
/// (typically broadcast) stream pushes data even when it's not listened to,
/// the [value] will not be tracked if there are no listeners on [updates]. In
/// such case [PushStreamWithValue] may be more appropriate.
// Why not use BehaviorSubject?
// 1. It incapsulates all of: stream, value and add(), i.e. requires another
//    interface / wrapper to expose read-only properties: stream and value.
// 2. If you already have a stream that you want to turn into BehaviorSubject,
//    you have to subscribe to that stream, create a BehaviorSubject, add values
//    to BehaviorSubject and when done, close both stream subscription and
//    BehaviorSubject. This is cumbersome.
// 3. It replays the value to all new stream subscribers, which is redundant
//    when passing value as initialData to StreamBuilder. Passing initialData
//    if it's available is important to avoid unnecessary blinking.
class StreamWithLatestValue<T> implements StreamWithValue<T> {
  late Stream<T> _stream;
  bool _hasLatestValue = false;
  late T _latestValue;

  StreamWithLatestValue(Stream<T> sourceStream) {
    _stream = sourceStream.mapPerEvent((value) {
      _latestValue = value;
      _hasLatestValue = true;
      return value;
    });
  }

  factory StreamWithLatestValue.withInitialValue(
    Stream<T> sourceStream, {
    required T initialValue,
  }) =>
      StreamWithLatestValue(sourceStream)
        .._latestValue = initialValue
        .._hasLatestValue = true;

  @override
  Stream<T> get updates => _stream;

  /// Must check [loaded] before attempting to read [value]. If the [value] is
  /// not initialized (either through [withInitialValue] or stream event), an
  /// exception will be thrown.
  @override
  T get value => _latestValue;

  @override
  bool get loaded => _hasLatestValue;
}

/// [StreamWithValue] implementation that creates a [Stream] from subsequent
/// calls to [add]. This way, [value] is always set to the latest value that has
/// been [add]ed, regardless of whether the [updates] are listened to (in
/// contrast to [StreamWithLatestValue].
class PushStreamWithValue<T> implements StreamWithValue<T>, Sink<T> {
  final _controller = StreamController<T>.broadcast();
  bool _hasLatestValue = false;
  late T _latestValue;

  PushStreamWithValue();

  PushStreamWithValue.withInitialValue(T initialValue) {
    _latestValue = initialValue;
    _hasLatestValue = true;
  }

  /// Push [data] to the stream and save it in [value].
  @override
  void add(T data) {
    _latestValue = data;
    _hasLatestValue = true;
    _controller.add(data);
  }

  /// Close the stream. After that, calls to [add] are no longer allowed.
  @override
  void close() => _controller.close();

  @override
  bool get loaded => _hasLatestValue;

  @override
  Stream<T> get updates => _controller.stream;

  /// Must check [loaded] before attempting to read [value]. If the [value] is
  /// not initialized (either through [withInitialValue] or stream event), an
  /// exception will be thrown.
  @override
  T get value => _latestValue;
}
