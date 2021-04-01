# stream_with_value

[![pub package](https://img.shields.io/pub/v/stream_with_value.svg)](https://pub.dev/packages/stream_with_value)
[![flutter build](https://github.com/futureware-tech/stream_with_value/workflows/flutter/badge.svg?branch=master&event=push)](https://github.com/futureware-tech/stream_with_value/actions?query=workflow%3Aflutter+branch%3Amaster)
[![code coverage](https://codecov.io/gh/futureware-tech/stream_with_value/branch/master/graph/badge.svg)](https://codecov.io/gh/futureware-tech/stream_with_value)

## About

If you ever found yourself:

- listening to a single-subscription
  [Stream](https://api.dart.dev/stable/dart-async/Stream-class.html) and needing
  to access the latest value on demand (and not just in the `listen` callback);
- confused and tired of tedious handling of lazy-loaded values in
  [StreamBuilder](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html),
  especially handling the edge cases when the value is not loaded (progress
  indicator);

then this package is for you. It provides an interface, which is an
encapsulation of
[Stream<T>](https://api.dart.dev/stable/dart-async/Stream-class.html) and a
value of type `T`, along with a set of convenient implementations and
extensions. The most common to use is a
[StreamWithLatestValue](https://pub.dev/documentation/stream_with_value/latest/stream_with_value/StreamWithLatestValue-class.html),
which automatically tracks the latest value emitted by the stream:

```dart
/// Abstract interface, the base of this package.
abstract class StreamWithValue<T> {
  /// The stream.
  Stream<T> get updates;
  /// The value.
  T get value;
  /// Whether the value is initialized.
  bool get loaded;
}

/// A specific implementation which simply tracks the latest value emitted by
/// the sourceStream.
class StreamWithLatestValue<T> implements StreamWithValue<T> {
  StreamWithLatestValue(Stream<T> sourceStream) { /* ... */ }

  factory StreamWithLatestValue.withInitialValue(
    Stream<T> sourceStream, {
    required T initialValue,
  }) { /* ... */ }
}
```

Note well: since subscribing to a single-subscription stream can be an expensive
operation (e.g. it can initiate a network connection and start a download),
[StreamWithLatestValue](https://pub.dev/documentation/stream_with_value/latest/stream_with_value/StreamWithLatestValue-class.html)
would not subscribe to the stream unless you do (e.g. through `updates.listen()`
or passing it to
[StreamBuilder](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html)).
This means that the `value` will not be `loaded` until a subscription is active
and the first value is emitted by the stream.

If you want a different behavior, consider other implementations of
`StreamWithValue` offered by this package, for example,
[PushStreamWithValue](https://pub.dev/documentation/stream_with_value/latest/stream_with_value/PushStreamWithValue-class.html).

There's more to love about this package, see the
[API reference](https://pub.dev/documentation/stream_with_value/latest/) for
other helpers.

### For Flutter users

A very common pattern in reactive programming in Flutter is to show a progress
indicator while an element of UI is loading (e.g. from remote database). Flutter
offers convenient
[StreamBuilder](https://api.flutter.dev/flutter/widgets/StreamBuilder-class.html),
which allows you to customize behavior when a stream is not loaded, but you have
to implement it from scratch and insert branching. And what if the value for
the stream has been loaded before, and the UI has just been rebuilt when user
rotated the screen? This may cause flickering, and these two are exactly the
problems
[StreamWithValue](https://pub.dev/documentation/stream_with_value/latest/stream_with_value/StreamWithValue-class.html)
is here to solve. Use the convenience widgets:
[StreamBuilderWithValue](https://pub.dev/documentation/stream_with_value/latest/stream_with_value/StreamBuilderWithValue-class.html)
and if you don't want to handle `null` or not loaded data, then its friend,
[DataStreamWithValueBuilder](https://pub.dev/documentation/stream_with_value/latest/stream_with_value/DataStreamWithValueBuilder-class.html)
will save your day.

## How to use

See the [Install](https://pub.dev/packages/stream_with_value/install) section
on how to start using `StreamWithValue` in your project. You can use convenience
wrappers to start improving your project right away:

```dart
StreamWithValue<T> _counter;

void initState() {
  _counter = StreamWithValue<int>(
    Stream<int>.periodic(const Duration(seconds: 1))
  );
}

// Before StreamWithValue, in the build() method:
child: StreamBuilder<int>(
  stream: _counter.updates,
  builder: (BuildContext context, AsyncSnapshot snapshot) {
    return snapshot.hasData
      ? Text(
          '${snapshot.data}',
          style: Theme.of(context).textTheme.headline4,
        )
      : CircularProgressIndicator();
  },
)

// If you turn the screen, you will see a progress indicator for a moment. This
// can be easily solved with StreamWithValue and StreamWithValueBuilder:
child: StreamBuilderWithValue<int>(
  streamWithValue: _counter,
  builder: (BuildContext context, AsyncSnapshot snapshot) {
    return snapshot.hasData
      ? Text(
          '${snapshot.data}',
          style: Theme.of(context).textTheme.headline4,
        )
      : CircularProgressIndicator();
  },
)

/// Or use convenience widget in the code, which will automatically render a
/// progress indicator if the value is not yet loaded:
child: DataStreamWithValueBuilder<int>(
  streamWithValue: _counter,
  builder: (BuildContext context, int value) => Text(
      '${snapshot.data}',
      style: Theme.of(context).textTheme.headline4,
  ),
)
```

See more in the [Example](https://pub.dev/packages/stream_with_value/example)
section of the documentation. Happy streaming! Or building. Or both.
