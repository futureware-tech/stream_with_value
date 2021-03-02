import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stream_with_value/stream_with_value.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(title: 'Flutter Demo Home Page'),
      );
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({@required this.title});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _counterStreamController = StreamController<int>.broadcast();
  var _streamWithValue;

  @override
  void initState() {
    _streamWithValue = StreamWithLatestValue<int>.withInitialValue(
        _counterStreamController.stream,
        initialValue: 0);
    super.initState();
  }

  @override
  void dispose() {
    _counterStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'You have pushed the button this many times:',
              ),
              const Text('StreamBuilderWithValue example'),
              StreamBuilderWithValue<int>(
                streamWithValue: _streamWithValue,
                builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                  return (snapshot.hasData)
                      ? Text(
                          '${snapshot.data}',
                          style: Theme.of(context).textTheme.headline4,
                        )
                      : CircularProgressIndicator();
                },
              ),
              const Text('DataStreamWithValueBuilder example'),
              DataStreamWithValueBuilder<int>(
                streamWithValue: _streamWithValue,
                builder: (context, int value) => Text(
                  '$value',
                  style: Theme.of(context).textTheme.headline4,
                ),
                onData: (int newValue) {
                  print('New value arrived callback: $newValue');
                },
                nullValueBuilder: (BuildContext context) =>
                    CircularProgressIndicator(),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Increment the latest value and add to the StreamController
            _counterStreamController.add(_streamWithValue.value + 1);
          },
          tooltip: 'Increment',
          child: Icon(Icons.add),
        ),
      );
}
