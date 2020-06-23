import 'package:flutter/material.dart';
import 'package:flutter_native_runtime/flutter_native_runtime.dart';

final nativeRuntime = NativeRuntime();

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String version;
  String version2;
  String processName;
  Map map;
  String path;
  List paths;
  dynamic _flags;

  final userDefaults = nativeRuntime
      .classNamed('NSUserDefaults')
      .method('alloc')
      .method('initWithSuiteName:', arguments: ['test_name']);

  String customUserDefaultValue;

  @override
  void initState() {
    userDefaults.keep().then((_) {
      userDefaults
          .method('setObject:forKey:', arguments: ['1', 'test_key'])
          .invoke<void>()
          .then((_) {
            userDefaults
                .method('objectForKey:', arguments: ['test_key'])
                .invoke<String>()
                .then((value) {
                  setState(() {
                    customUserDefaultValue = value;
                  });
                });
          });
    });
    nativeRuntime
        .instanceNamed('UIDevice')
        .method('systemVersion')
        .invoke<String>()
        .then((version) {
      setState(() {
        this.version = version;
      });
    });

    nativeRuntime
        .classNamed('UIDevice')
        .property('currentDevice')
        .property('systemVersion')
        .get<String>()
        .then((version) {
      setState(() {
        version2 = version;
      });
    });

    nativeRuntime
        .instanceNamed('NSProcessInfo')
        .method('processName')
        .invoke<String>()
        .then((processName) {
      setState(() {
        this.processName = processName;
      });
    });

    nativeRuntime
        .instanceNamed('NSUserDefaults')
        .method('dictionaryRepresentation')
        .invoke<Map>()
        .then((map) {
      setState(() {
        this.map = map;
      });
    });

    nativeRuntime
        .classNamed('NSBundle')
        .property('mainBundle')
        .method('pathForResource:ofType:inDirectory:forLocalization:',
            arguments: ['ios', 'dart', null, null])
        .invoke<String>()
        .then((path) {
          setState(() {
            this.path = path;
          });
        });

    nativeRuntime
        .classNamed('NSBundle')
        .property('mainBundle')
        .method('pathsForResourcesOfType:inDirectory:forLocalization:',
            arguments: ['', 'dart', null, null])
        .invoke<List>()
        .then((paths) {
          setState(() {
            this.paths = paths;
          });
        });
//
//    nativeRuntime
//        .classNamed('NSBundle')
//        .property('mainBundle')
//        .memberVariable(
//          '_flags',
//        )
//        .get<dynamic>()
//        .then((flags) {
//      setState(() {
//        _flags = flags;
//      });
//    });

    super.initState();
  }

  @override
  Future<void> dispose() async {
    await userDefaults.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: <Widget>[
            Text('UIDevice: systemVersion: $version'),
            Text('UIDevice.currentDevice.systemVersion: $version2'),
            Text('NSProcessInfo: processName: ${processName.toString()}'),
            Text(
                'NSUserDefaults: dictionaryRepresentation: ${processName.toString()}'),
            Text(
                'NSBundle.mainBundle.pathForResource:ofType:inDirectory:forLocalization: $path'),
            Text(
                'NSBundle.mainBundle.pathsForResourcesOfType:ofType:inDirectory:forLocalization: ${paths.toString()}'),
//            Text('NSBundle.mainBundle->_flags: ${_flags.toString()}'),
            Text(
                '[[NSUserDefaults alloc] initWithSuiteName: @"test_name"] : test_key : $customUserDefaultValue'),
          ],
        ),
      ),
    );
  }
}
