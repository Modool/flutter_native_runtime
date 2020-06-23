package com.modool.flutter_native_runtime;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;


abstract class FlutterResult {
    public static FlutterResult empty() {
        return new FlutterReturnResult(null);
    }

    public static FlutterResult success(Object object) {
        return new FlutterReturnResult(object);
    }

    public static FlutterResult error(Error error) {
        return new FlutterErrorResult(error);
    }

    protected abstract void execute(MethodChannel.Result result);

    private static class FlutterReturnResult extends FlutterResult {
        FlutterReturnResult(Object returnValue) {
            this.returnValue = returnValue;
        }

        private Object returnValue;

        protected void execute(MethodChannel.Result result) {
            result.success(returnValue);
        }
    }

    private static class FlutterErrorResult extends FlutterResult {
        FlutterErrorResult(Error error) {
            this.error = error;
        }

        private Error error;

        protected void execute(MethodChannel.Result result) {
            result.error(error.getMessage(), error.getStackTrace().toString(), null);
        }
    }
}

/**
 * FlutterNativeRuntimePlugin
 */
public class FlutterNativeRuntimePlugin implements MethodCallHandler {
    private Registrar _registrar;

    private Map<String, Object> instances;
    private Map<String, Object> cache = new HashMap();

    FlutterNativeRuntimePlugin(Registrar registrar) {
        _registrar = registrar;

        if (_registrar != null) {
            instances = new HashMap() {
                {
                    put("Registrar", _registrar);
                }
            };
        }
    }
    /**
     * Flutter
     */
    @Override
    public void onMethodCall(MethodCall call, Result result) {
        final Object args = call.arguments;
        final List<Class> parameterTypes = new ArrayList();

        if (args != null) {
            if (args instanceof List) {
                for (Object arg : (List) args) {
                    parameterTypes.add(arg.getClass());
                }
            } else {
                parameterTypes.add(args.getClass());
            }
        }

        Method method = null;
        if (method == null) {
            try {
                method = getClass().getDeclaredMethod(call.method, parameterTypes.toArray(new Class[0]));
            } catch (Exception e) {
                e.printStackTrace();
            }
        }

        if (method == null) {
            result.notImplemented();
            return;
        }
        try {
            method.setAccessible(true);

            Object object;
            if (args instanceof List) {
                object = method.invoke(this, (Object[]) ((List) args).toArray());
            } else if (args != null) {
                object = method.invoke(this, args);
            } else {
                object = method.invoke(this);
            }
            if (object instanceof FlutterResult) {
                ((FlutterResult) object).execute(result);
            } else {
                result.success(object);
            }
        } catch (RuntimeException e) {
            e.printStackTrace();

            result.error(e.getMessage(), e.getStackTrace().toString(), null);
        } catch (IllegalAccessException e) {
            e.printStackTrace();

            result.error(e.getMessage(), e.getStackTrace().toString(), null);
        } catch (InvocationTargetException e) {
            e.printStackTrace();

            result.error(e.getMessage(), e.getStackTrace().toString(), null);
        }
    }

    /**
     * Plugin registration.
     */
    public static void registerWith(Registrar registrar) {
        final MethodChannel channel = new MethodChannel(registrar.messenger(), "com.modool.flutter/plugins/flutter_native_runtime");
        final FlutterNativeRuntimePlugin plugin = new FlutterNativeRuntimePlugin(registrar);

        channel.setMethodCallHandler(plugin);
    }

    private FlutterResult invoke(HashMap<String, Object> map) {
        try {
            return FlutterResult.success(__invoke(map));
        } catch (Exception e) {
            return FlutterResult.error(new Error(e.getMessage(), e));
        }
    }

    private FlutterResult keep(HashMap<String, Object> map) {
        try {
            String uuid = (String) map.get("id");
            Object result = __invoke(map);
            if (result != null)  cache.put(uuid, result);

            return FlutterResult.empty();
        } catch (Exception e) {
            return FlutterResult.error(new Error(e.getMessage(), e));
        }
    }

    private void dispose(String uuid) {
        cache.remove(uuid);

    }
    /**
     * @param map
     *
     *    'n': 'test',
     *    'id': uuid
     *    't': 1,
     *    'a': [],
     *    'p': {
     *        'n': 'variable',
     *        't': 4,
     *        'a': [],
     *    }
     */
    private Object __invoke(Map<String, Object> map) throws Exception {
        String name = (String) map.get("n");
        if (name.isEmpty()) throw new Exception("Target name can\'t be empty");

        String uuid = (String) map.get("id");

        if (cache.containsKey(uuid)) return cache.get(uuid);

        NativeTargetType type = NativeTargetType.values()[(Integer) map.get("t")];

        List arguments = (List) map.get("a");

        Map<String, Object> parent = (Map) map.get("p");

        if (parent != null) {
            Object target = __invoke(parent);

            return __invoke(target, type, name, arguments);
        } else {
            if (type != NativeTargetType.CLASS && type != NativeTargetType.GLOBAL) {
                throw new Exception("No implementation.");
            }
            Object target;
            if (type == NativeTargetType.GLOBAL) {
                target = instances.get(name);
            } else {
                target = Class.forName(name);
            }
            if (target == null) throw new Exception("Can\'t find an target named ${name}");

            return target;
        }
    }

    private Method __findMethod(String methodName, int parameterCount, Class cls) {
        Method method = __findMethod(methodName, parameterCount, cls.getDeclaredMethods());
        if (method != null) return method;

        return __findMethod(methodName, parameterCount, cls.getMethods());

    }

    private Method __findMethod(String methodName, int parameterCount, Method[] methods) {
        for (Method method: methods) {
            if (!method.getName().equals(methodName)) continue;;
            if (method.getParameterTypes().length != parameterCount) continue;

            return method;
        }
        return null;
    }

    private Field __findFeild(String fieldName, Class cls) {
        Field field = __findFeild(fieldName, cls.getDeclaredFields());
        if (field != null) return field;

        return __findFeild(fieldName, cls.getFields());
    }

    private Field __findFeild(String fieldName, Field[] fields) {
        for (Field field: fields) {
            String name = field.getName();
            if (!name.equals(fieldName)) continue;;

            return field;
        }
        return null;
    }

    private Object __invoke(Object target, NativeTargetType type , String name, List arguments) throws Exception {
        int parameterCount = arguments != null ? (arguments instanceof List ? arguments.size() : 1) : 0;

        Class cls = (target instanceof Class) ? (Class)target : target.getClass();
        Class enclosingClass = cls.getEnclosingClass();

        if (type == NativeTargetType.METHOD) {
            Method method = __findMethod(name, parameterCount, cls);
            if (method == null && enclosingClass != null) {
                method = __findMethod(name, parameterCount, enclosingClass);
            }
            if (method == null) {
                throw new Exception("No implementation.");
            } else {
                method.setAccessible(true);

                if (arguments instanceof List) {
                    return method.invoke(target, (Object[]) arguments.toArray());
                } else if (arguments != null) {
                    return method.invoke(target, arguments);
                } else {
                    return method.invoke(target);
                }
            }
        } else if (type == NativeTargetType.VARIABLE) {
            Field field = __findFeild(name, cls);
            if (field == null && enclosingClass != null) {
                field = __findFeild(name, enclosingClass);
            }
            if (field == null) {
                throw new Exception("No implementation.");
            } else {
                field.setAccessible(true);

                if (arguments != null) {
                    field.set(target, arguments);
                    return null;
                } else {
                    return field.get(target);
                }
            }
        } else {
            throw new Exception("Unsupported type:" + type + ".");
        }
    }

    private enum NativeTargetType {GLOBAL, CLASS, METHOD, INVALID, VARIABLE}
}
