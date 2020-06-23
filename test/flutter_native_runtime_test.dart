import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_native_runtime/flutter_native_runtime.dart';

void main() {
  final nativeRuntime = NativeRuntime();
  const channel = MethodChannel('flutter_native_runtime');

  final log = <MethodCall>[];

  channel.setMockMethodCallHandler((methodCall) async {
    log.add(methodCall);

    if (methodCall.method == '_dispose' || methodCall.method == '_keep') {
      return null;
    }

    return '42';
  });

  tearDown(log.clear);

  test('native target', () async {
    final target =
        nativeRuntime.classNamed('test').method('method', arguments: ['a']);

    expect(target.id, isNotEmpty);
    expect(target.arguments, ['a']);
    expect(target.hashCode, target.id.hashCode);

    final target2 =
        nativeRuntime.classNamed('test').method('method', arguments: ['a']);

    expect(target == target2, false);
    expect(target.isSameAs(target2), true);
  });

  test('keep native target', () async {
    final target = nativeRuntime.classNamed('test');
    expect(await target.keep(), true);

    final call = log.first;
    expect(call.method, '_keep');
    expect(call.arguments['n'], 'test');
    expect(call.arguments['t'], 1);
    expect(call.arguments['id'], target.id);

    expect(await target.dispose(), true);

    final call2 = log[1];
    expect(call2.method, '_dispose');
    expect(call2.arguments, target.id);

    expect(await target.dispose(), false);
    expect(log.length, 2);
  });

  test('dispose native target', () async {
    final target = nativeRuntime.classNamed('test');

    expect(await target.dispose(), false);
    expect(log, isEmpty);
  });

  test('property get by class matching', () async {
    final result = await nativeRuntime
        .classNamed('test')
        .property('property')
        .get<String>();

    final call = log.first;
    expect(call.method, '_invoke');
    expect(call.arguments['n'], 'property');
    expect(call.arguments['t'], 3);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'test');
    expect(call.arguments['p']['t'], 1);
    expect(call.arguments['p']['id'], isNotNull);

    expect(result, '42');
  });

  test('property\'s property get by class matching', () async {
    final result = await nativeRuntime
        .classNamed('test')
        .property('property1')
        .property('property2')
        .get<String>();

    final call = log.first;
    expect(call.method, '_invoke');
    expect(call.arguments['n'], 'property2');
    expect(call.arguments['t'], 3);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'property1');
    expect(call.arguments['p']['t'], 3);
    expect(call.arguments['p']['id'], isNotNull);

    expect(call.arguments['p']['p']['n'], 'test');
    expect(call.arguments['p']['p']['t'], 1);
    expect(call.arguments['p']['p']['id'], isNotNull);

    expect(result, '42');
  });

  test('property set by class matching', () async {
    await nativeRuntime.classNamed('test').property('property').set('aa');

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['aa']);
    expect(call.arguments['n'], 'property');
    expect(call.arguments['t'], 3);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'test');
    expect(call.arguments['p']['t'], 1);
    expect(call.arguments['p']['id'], isNotNull);
  });

  test('property\'s property set by class matching', () async {
    await nativeRuntime
        .classNamed('test')
        .property('property1')
        .property('property2')
        .set('aa');

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['aa']);
    expect(call.arguments['n'], 'property2');
    expect(call.arguments['t'], 3);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'property1');
    expect(call.arguments['p']['t'], 3);
    expect(call.arguments['p']['id'], isNotNull);

    expect(call.arguments['p']['p']['n'], 'test');
    expect(call.arguments['p']['p']['t'], 1);
    expect(call.arguments['p']['p']['id'], isNotNull);
  });

  test('method invoke by class matching', () async {
    final result = await nativeRuntime
        .classNamed('test')
        .method('method', arguments: ['aa']).invoke();

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['aa']);
    expect(call.arguments['n'], 'method');
    expect(call.arguments['t'], 2);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'test');
    expect(call.arguments['p']['t'], 1);
    expect(call.arguments['p']['id'], isNotNull);

    expect(result, '42');
  });

  test('method invoke with result of another method invoking by class matching',
      () async {
    final result = await nativeRuntime.classNamed('test').method('method1',
        arguments: ['aa']).method('method2', arguments: ['bb']).invoke();

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['bb']);
    expect(call.arguments['n'], 'method2');
    expect(call.arguments['t'], 2);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['a'], ['aa']);
    expect(call.arguments['p']['n'], 'method1');
    expect(call.arguments['p']['t'], 2);
    expect(call.arguments['p']['id'], isNotNull);

    expect(call.arguments['p']['p']['n'], 'test');
    expect(call.arguments['p']['p']['t'], 1);
    expect(call.arguments['p']['p']['id'], isNotNull);

    expect(result, '42');
  });

  test(
      'member variable invoke with result of another method invoking by class matching',
      () async {
    final result = await nativeRuntime
        .classNamed('test')
        .memberVariable('var')
        .method('method2', arguments: ['bb']).invoke();

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['bb']);
    expect(call.arguments['n'], 'method2');
    expect(call.arguments['t'], 2);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'var');
    expect(call.arguments['p']['t'], 4);
    expect(call.arguments['p']['id'], isNotNull);

    expect(call.arguments['p']['p']['n'], 'test');
    expect(call.arguments['p']['p']['t'], 1);
    expect(call.arguments['p']['p']['id'], isNotNull);

    expect(result, '42');
  });

  test(
      'method invoke with result of another method invoking by instance matching',
      () async {
    final result = await nativeRuntime.instanceNamed('test').method('method1',
        arguments: ['aa']).method('method2', arguments: ['bb']).invoke();

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['bb']);
    expect(call.arguments['n'], 'method2');
    expect(call.arguments['t'], 2);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['a'], ['aa']);
    expect(call.arguments['p']['n'], 'method1');
    expect(call.arguments['p']['t'], 2);
    expect(call.arguments['p']['id'], isNotNull);

    expect(call.arguments['p']['p']['n'], 'test');
    expect(call.arguments['p']['p']['t'], 0);
    expect(call.arguments['p']['p']['id'], isNotNull);

    expect(result, '42');
  });

  test('get member variable from instance named \'test\'', () async {
    final result = await nativeRuntime
        .instanceNamed('test')
        .memberVariable('variable')
        .get();

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['n'], 'variable');
    expect(call.arguments['t'], 4);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'test');
    expect(call.arguments['p']['t'], 0);
    expect(call.arguments['p']['id'], isNotNull);

    expect(result, '42');
  });

  test('set member variable to instance named \'test\'', () async {
    await nativeRuntime
        .instanceNamed('test')
        .memberVariable('variable')
        .set('aa');

    final call = log.first;
    expect(call.method, '_invoke');

    expect(call.arguments['a'], ['aa']);
    expect(call.arguments['n'], 'variable');
    expect(call.arguments['t'], 4);
    expect(call.arguments['id'], isNotNull);

    expect(call.arguments['p']['n'], 'test');
    expect(call.arguments['p']['t'], 0);
    expect(call.arguments['p']['id'], isNotNull);
  });

  test('target to map', () async {
    final target = nativeRuntime
        .instanceNamed('test')
        .method('method1', arguments: ['aa']);

    final result = await target.invoke();

    expect(log.first.arguments, target.toMap());

    expect(result, '42');
  });

  test('TestNativeRuntime', () async {
    final runtime = TestNativeRuntime(const MethodChannel('test'));

    expect(runtime, isInstanceOf<NativeRuntime>());
  });
}
