import 'dart:io';
import 'package:flutter/material.dart';

import 'package:sprintf/sprintf.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:open_file/open_file.dart';

import 'package:phone_log/phone_log.dart';
import 'package:audio_recorder2/audio_recorder2.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

Future<Directory> _getAppDir() async {
  print("getAppDir");
  Directory dp = await getExternalStorageDirectory();

  print("getAppDir: " + dp.path);
  Directory d = Directory(dp.path + "/Android/data/com.tuxago.regord/audio");
  await d.create(recursive: true);
  return d;
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  String _error = "";
  final PhoneLog phoneLog = new PhoneLog();
  Iterable<CallRecord> _callRecords;
  List<FileSystemEntity> _audioTaskFiles;
  bool _isRecording = false;

  void _requestPermissions() async {
    print("requesting perms");
    Map<perm.PermissionGroup, perm.PermissionStatus> _permissions =
        await perm.PermissionHandler().requestPermissions([
      perm.PermissionGroup.storage,
      perm.PermissionGroup.speech,
      perm.PermissionGroup.phone
    ]);
    print("perms asked: " + _permissions.toString());
    PermissionStatus ps = await phoneLog.checkPermission();
    print("ps: " + ps.toString());
  }

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  void _decrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter--;
    });
  }

  void fetchCallLog() async {
    PermissionStatus perm = await phoneLog.checkPermission();
    if (perm != PermissionStatus.granted) {
      print("requesting call log perms");
      bool permGranted = await phoneLog.requestPermission();
      if (!permGranted) {
        print("permission denied");
        return;
      }
    }
    Iterable<CallRecord> entries = await phoneLog.getPhoneLogs();
    setState(() {
      _counter = entries.length;
      _callRecords = entries;
    });
  }

  void recordTask() async {
    bool hasPermissions = await AudioRecorder2.hasPermissions;

    if (!hasPermissions) {
      return;
    }

    Directory _appDir = await _getAppDir();

    setState(() {
      _isRecording = true;
    });

    await AudioRecorder2.start(
        path: _appDir.path + "/" + datePrefix() + "task.mp4",
        audioOutputFormat: AudioOutputFormat.AAC);
  }

  String datePrefix() {
    DateTime now = DateTime.now();
    return sprintf("%02d-%02d-%02dT%02d-%02d-%02d_",
        [now.year, now.month, now.day, now.hour, now.minute, now.second]);
  }

  void stopRecordTask() async {
    bool hasPermissions = await AudioRecorder2.hasPermissions;

    if (!hasPermissions) {
      return;
    }

    Recording recording = await AudioRecorder2.stop();
    print(
        "path: ${recording.path}, format: ${recording.audioOutputFormat}, duration: ${recording.duration}, extension: ${recording.extension}");

    Directory d = await _getAppDir();
    List<FileSystemEntity> files =
        await d.list(recursive: false, followLinks: false).toList();

    setState(() {
      _isRecording = false;
      _audioTaskFiles = files;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    final List<Widget> children = <Widget>[
      Text(
        'You have pushed the button this many times:',
      ),
      Text(
        '$_counter',
        style: Theme.of(context).textTheme.display1,
      ),
    ];

    for (CallRecord call in _callRecords ?? <CallRecord>[]) {
      children.addAll(<Widget>[
        new Container(
          height: 16.0,
        ),
        new Row(
          children: <Widget>[
            new Text(call.formattedNumber ?? call.number ?? 'unknow'),
            new Padding(
              child: new Text(call.callType.toString()),
              padding: const EdgeInsets.only(left: 8.0),
            ),
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        new Row(
          children: <Widget>[
            new Padding(
              child: new Text(call.dateYear.toString() +
                  '-' +
                  call.dateMonth.toString() +
                  '-' +
                  call.dateDay.toString() +
                  '  ' +
                  call.dateHour.toString() +
                  ': ' +
                  call.dateMinute.toString() +
                  ': ' +
                  call.dateSecond.toString()),
              padding: const EdgeInsets.only(left: 8.0),
            ),
            new Padding(
                child: new Text(call.duration.toString() + 'seconds'),
                padding: const EdgeInsets.only(left: 8.0))
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        )
      ]);
    }

    for (FileSystemEntity f in _audioTaskFiles ?? <FileSystemEntity>[]) {
      children.addAll(<Widget>[
        new Container(
          height: 16.0,
        ),
        new Row(
          children: <Widget>[
            FlatButton(
              onPressed: () => _playMedia(f.path),
              child: Icon(Icons.play_circle_filled),
            ),
            Padding(
              child: Text(basename(f.path)),
              padding: const EdgeInsets.only(left: 8.0),
            ),
          ],
          crossAxisAlignment: CrossAxisAlignment.center,
        )
      ]);
    }

    FloatingActionButton recordingTask;
    if (_isRecording) {
      recordingTask = FloatingActionButton(
        onPressed: stopRecordTask,
        tooltip: 'Stop recording task',
        child: Icon(Icons.stop),
      );
    } else {
      recordingTask = FloatingActionButton(
        onPressed: recordTask,
        tooltip: 'Record task',
        child: Icon(Icons.mic),
      );
    }

    Widget floatingActionButton = Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        FloatingActionButton(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          child: Icon(Icons.add),
        ), // This trailing comma makes auto-formatting nicer for build methods.
        FloatingActionButton(
          onPressed: _decrementCounter,
          tooltip: 'Decrement',
          child: Icon(Icons.remove),
        ), // This trailing comma makes auto-formatting nicer for build methods.
        FloatingActionButton(
          onPressed: _requestPermissions,
          tooltip: 'Request permissions',
          child: Icon(Icons.perm_phone_msg),
        ), // This trailing comma makes auto-formatting nicer for build methods.
        FloatingActionButton(
          onPressed: fetchCallLog,
          tooltip: 'Get number of calls',
          child: Icon(Icons.view_list),
        ), // This trailing comma makes auto-formatting nicer for build methods.
        recordingTask,
      ],
    );

    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: ListView(
          // Column is also layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          children: children,
        ),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

void _playMedia(String filepath) async {
  await OpenFile.open(filepath);
}
