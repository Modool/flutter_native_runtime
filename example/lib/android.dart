import 'package:flutter/material.dart';
import 'package:flutter_native_runtime/flutter_native_runtime.dart';

final nativeRuntime = NativeRuntime();

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String model;
  String packageName;

  @override
  void initState() {
    nativeRuntime
        .classNamed('android.os.Build')
        .memberVariable('MODEL')
        .get<String>()
        .then((model) {
      setState(() {
        this.model = model;
      });
    });
    nativeRuntime
        .instanceNamed('Registrar')
        .method('context')
        .method('getPackageName')
        .invoke<String>()
        .then((packageName) {
      setState(() {
        this.packageName = packageName;
      });
    });
    super.initState();
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
            Text('Class(android.os.Build)->MODEL: $model'),
            Text('Registrar.context().getPackageName(): $packageName'),
          ],
        ),
      ),
    );
  }
}
