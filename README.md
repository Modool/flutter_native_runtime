# Flutter Native Runtime Plugin

A native runtime plugin for Flutter. This plugin provides a cross-platform (iOS, Android) API to request and call native runtime.

![Flutter Test](https://github.com/Modool/flutter_native_runtime/workflows/Flutter%20Test/badge.svg) [![pub package](https://img.shields.io/pub/v/flutter_native_runtime.svg)](https://pub.dartlang.org/packages/flutter_native_runtime) [![Build Status](https://app.bitrise.io/app/fa4f5d4bf452bcfb/status.svg?token=HorGpL_AOw2llYz39CjmdQ&branch=master)](https://app.bitrise.io/app/fa4f5d4bf452bcfb) [![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)

## Features

* Access class with name.
* Access global instance with name.
* Call method with method name and arguments.
* Read and write property with property name.

## Usage

To use this plugin, add `flutter_native_runtime` as a [dependency in your pubspec.yaml file](https://flutter.io/platform-plugins/). For example:

```yaml
dependencies:
  flutter_native_runtime: 0.0.1
```

## API

### Access native class or instance target

```dart
import 'package:flutter_native_runtime/flutter_native_runtime.dart';

// Class target for ios
final deviceTarget = nativeRuntime.classNamed('UIDevice');

// Instance target for ios
final deviceTarget = nativeRuntime.instanceNamed('UIDevice');

// Class target for android
final registrarTarget = nativeRuntime.classNamed('Registrar');

// Instance type for android
final registrarTarget = nativeRuntime.instanceNamed('Registrar');
```

### Call native method or property 

```dart

import 'package:flutter_native_runtime/flutter_native_runtime.dart';
  
// iOS
// Access property to get result of UIDevice.currentDevice.systemVersion
final systemVersion = nativeRuntime.classNamed('UIDevice').property('currentDevice').property('systemVersion').get<String>();

// Access method to get result of [[UIDevice currentDevice] systemVersion]
final systemVersion = nativeRuntime.classNamed('UIDevice').method('currentDevice').method('systemVersion').invoke<String>();

// Access method to get result of [UIDevice currentDevice].systemVersion
final systemVersion = nativeRuntime.classNamed('UIDevice').method('currentDevice').property('systemVersion').get<String>();

// Android
// To get Context.getPackageName 
final packageName = nativeRuntime.instanceNamed('Registrar').method('context').method('getPackageName').invoke<String>();

// To get private variable of Context.mVariable 
final variable = nativeRuntime.instanceNamed('Registrar').property('context').variable('mVariable').invoke<String>();
```

## Issues

Please file any issues, bugs or feature request as an issue on our  [Github](https://github.com/modool/flutter_native_runtime/issues) page.

## Want to contribute

If you would like to contribute to the plugin (e.g. by improving the documentation, solving a bug or adding a cool new feature), please carefully review our [contribution guide](CONTRIBUTING.md) and send us your [pull request](https://github.com/modool/flutter_native_runtime/pulls).

## Author

This Flutter Native Runtime plugin for Flutter is developed by [modool](https://github.com/modool). You can contact us at <modool.go@gmail.com>
