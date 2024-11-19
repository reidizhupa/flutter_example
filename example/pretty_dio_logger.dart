import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:grestapp_homeal_app/utils/extensions/datetime_extension.dart';
import 'dart:developer';
import 'dart:developer' as developer;

Map<String, Map<String, Map<String, dynamic>>> httpDebug = {};

enum PrettyDioLoggerEvent { request, response, error }

// preso spunto da https://github.com/Milad-Akarie/pretty_dio_logger
class PrettyDioLogger_ extends Interceptor {
  /// Print request [Options]
  final bool request;

  /// Print request header [Options.headers]
  final bool requestHeader;

  /// Print request data [Options.data]
  final bool requestBody;

  /// Print [Response.data]
  final bool responseBody;

  /// Print [Response.headers]
  final bool responseHeader;

  /// Print error message
  final bool error;

  /// InitialTab count to logPrint json response
  static const int kInitialTab = 1;

  /// 1 tab length
  static const String tabStep = '    ';

  /// Print compact json response
  final bool compact;

  /// Width size per logPrint
  final int maxWidth;

  /// Size in which the Uint8List will be splitted
  static const int chunkSize = 20;

  final bool useInspect;

  String logStr = '';

  // Map<String, dynamic> logMap = {};

  late String requestId;

  PrettyDioLoggerEvent? event;

  PrettyDioLogger_({
    this.request = true,
    this.requestHeader = true,
    this.requestBody = true,
    this.responseHeader = true,
    this.responseBody = true,
    this.error = true,
    this.maxWidth = 90,
    this.compact = true,
    this.useInspect = true,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    requestId = DateTime.now().secondsSinceEpoch().toString() + UniqueKey().toString();
    httpDebug[requestId] = {
      PrettyDioLoggerEvent.request.name: {},
      PrettyDioLoggerEvent.response.name: {},
      PrettyDioLoggerEvent.error.name: {},
    };
    event = PrettyDioLoggerEvent.request;
    if (request) {
      _printRequestHeader(options);
    }
    if (requestHeader) {
      _printMapAsTable(options.queryParameters, header: 'Query Parameters');
      final requestHeaders = <String, dynamic>{};
      requestHeaders.addAll(options.headers);
      requestHeaders['contentType'] = options.contentType?.toString();
      requestHeaders['responseType'] = options.responseType.toString();
      requestHeaders['followRedirects'] = options.followRedirects;
      requestHeaders['connectTimeout'] = options.connectTimeout?.toString();
      requestHeaders['receiveTimeout'] = options.receiveTimeout?.toString();
      _printMapAsTable(requestHeaders, header: 'Headers');
      _printMapAsTable(options.extra, header: 'Extras');
    }
    if (requestBody && options.method != 'GET') {
      final dynamic data = options.data;
      if (data != null) {
        if (data is Map) _printMapAsTable(options.data as Map?, header: 'Body');
        if (data is FormData) {
          final formDataMap = <String, dynamic>{}
            ..addEntries(data.fields)
            ..addEntries(data.files);
          _printMapAsTable(formDataMap, header: 'Form data | ${data.boundary}');
        } else {
          if (useInspect) {
            logPrint({'Body': data});
          } else {
            _printBlock(data.toString());
          }
        }
      }
    }
    _showLog();
    super.onRequest(options, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    event = PrettyDioLoggerEvent.error;
    if (error) {
      if (err.type == DioErrorType.badResponse) {
        final uri = err.response?.requestOptions.uri;
        _printBoxed(header: 'DioError ║ Status: ${err.response?.statusCode} ${err.response?.statusMessage}', text: uri.toString());
        if (err.response != null && err.response?.data != null) {
          _printResponse(err.response!, header: err.type.toString());
        }
      } else {
        _printBoxed(header: 'DioError ║ ${err.type}', text: err.message);
      }
    }
    _showLog();
    super.onError(err, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    event = PrettyDioLoggerEvent.response;
    _printResponseHeader(response);
    if (responseHeader) {
      final responseHeaders = <String, dynamic>{};
      response.headers.forEach((k, list) => responseHeaders[k] = useInspect && list.length > 1 ? list : list.toString());
      _printMapAsTable(responseHeaders, header: 'Headers');
    }

    if (responseBody) {
      _printResponse(response, header: 'Body');
    }

    _showLog();
    super.onResponse(response, handler);
  }

  void _printBoxed({required String header, String? text}) {
    if (useInspect) {
      logPrint({header: text});
    } else {
      logPrint('');
      logPrint('╔╣ $header');
      logPrint('║  $text');
      _printLine('╚');
    }
  }

  void _printResponse(Response response, {required String header}) {
    if (useInspect) {
      logPrint({header: response.data});
    } else {
      logPrint('╔ $header');
      logPrint('║');
      if (response.data != null) {
        if (response.data is Map) {
          _printPrettyMap(response.data as Map);
        } else if (response.data is Uint8List) {
          logPrint('║${_indent()}[');
          _printUint8List(response.data as Uint8List);
          logPrint('║${_indent()}]');
        } else if (response.data is List) {
          logPrint('║${_indent()}[');
          _printList(response.data as List);
          logPrint('║${_indent()}]');
        } else {
          _printBlock(response.data.toString());
        }
      }
      logPrint('║');
      _printLine('╚');
      logPrint('');
    }
  }

  void _printResponseHeader(Response response) {
    final uri = response.requestOptions.uri;
    final method = response.requestOptions.method;
    _printBoxed(header: 'Response ║ $method ║ Status: ${response.statusCode} ${response.statusMessage}', text: uri.toString());
  }

  void _printRequestHeader(RequestOptions options) {
    final uri = options.uri;
    final method = options.method;
    _printBoxed(header: 'Request ║ $method ', text: uri.toString());
  }

  void _printLine([String pre = '', String suf = '╝']) {
    if (!useInspect) {
      logPrint('$pre${'═' * maxWidth}$suf');
    }
  }

  void _printKV(String? key, Object? v) {
    assert(useInspect == false);

    final pre = '╟ $key: ';
    final msg = v.toString();

    if (pre.length + msg.length > maxWidth) {
      logPrint(pre);
      _printBlock(msg);
    } else {
      logPrint('$pre$msg');
    }
  }

  void _printBlock(String msg) {
    assert(useInspect == false);

    final lines = (msg.length / maxWidth).ceil();
    for (var i = 0; i < lines; ++i) {
      logPrint((i >= 0 ? '║ ' : '') + msg.substring(i * maxWidth, math.min<int>(i * maxWidth + maxWidth, msg.length)));
    }
  }

  String _indent([int tabCount = kInitialTab]) => tabStep * tabCount;

  void _printPrettyMap(
    Map data, {
    int initialTab = kInitialTab,
    bool isListItem = false,
    bool isLast = false,
  }) {
    assert(useInspect == false);

    var tabs = initialTab;
    final isRoot = tabs == kInitialTab;
    final initialIndent = _indent(tabs);
    tabs++;

    if (isRoot || isListItem) logPrint('║$initialIndent{');

    data.keys.toList().asMap().forEach((index, dynamic key) {
      final isLast = index == data.length - 1;
      dynamic value = data[key];
      if (value is String) {
        value = '"${value.toString().replaceAll(RegExp(r'([\r\n])+'), " ")}"';
      }
      if (value is Map) {
        if (compact && _canFlattenMap(value)) {
          logPrint('║${_indent(tabs)} $key: $value${!isLast ? ',' : ''}');
        } else {
          logPrint('║${_indent(tabs)} $key: {');
          _printPrettyMap(value, initialTab: tabs);
        }
      } else if (value is List) {
        if (compact && _canFlattenList(value)) {
          logPrint('║${_indent(tabs)} $key: ${value.toString()}');
        } else {
          logPrint('║${_indent(tabs)} $key: [');
          _printList(value, tabs: tabs);
          logPrint('║${_indent(tabs)} ]${isLast ? '' : ','}');
        }
      } else {
        final msg = value.toString().replaceAll('\n', '');
        final indent = _indent(tabs);
        final linWidth = maxWidth - indent.length;
        if (msg.length + indent.length > linWidth) {
          final lines = (msg.length / linWidth).ceil();
          for (var i = 0; i < lines; ++i) {
            logPrint('║${_indent(tabs)} ${msg.substring(i * linWidth, math.min<int>(i * linWidth + linWidth, msg.length))}');
          }
        } else {
          logPrint('║${_indent(tabs)} $key: $msg${!isLast ? ',' : ''}');
        }
      }
    });

    logPrint('║$initialIndent}${isListItem && !isLast ? ',' : ''}');
  }

  void _printList(List list, {int tabs = kInitialTab}) {
    assert(useInspect == false);

    list.asMap().forEach((i, dynamic e) {
      final isLast = i == list.length - 1;
      if (e is Map) {
        if (compact && _canFlattenMap(e)) {
          logPrint('║${_indent(tabs)}  $e${!isLast ? ',' : ''}');
        } else {
          _printPrettyMap(e, initialTab: tabs + 1, isListItem: true, isLast: isLast);
        }
      } else {
        logPrint('║${_indent(tabs + 2)} $e${isLast ? '' : ','}');
      }
    });
  }

  void _printUint8List(Uint8List list, {int tabs = kInitialTab}) {
    assert(useInspect == false);

    var chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(i, i + chunkSize > list.length ? list.length : i + chunkSize),
      );
    }
    for (var element in chunks) {
      logPrint('║${_indent(tabs)} ${element.join(", ")}');
    }
  }

  bool _canFlattenMap(Map map) {
    assert(useInspect == false);

    return map.values.where((dynamic val) => val is Map || val is List).isEmpty && map.toString().length < maxWidth;
  }

  bool _canFlattenList(List list) {
    assert(useInspect == false);

    return list.length < 10 && list.toString().length < maxWidth;
  }

  void _printMapAsTable(Map? map, {required String header}) {
    if (useInspect) {
      logPrint({header: map});
    } else {
      if (map == null || map.isEmpty) return;
      logPrint('╔ $header ');
      map.forEach((dynamic key, dynamic value) => _printKV(key.toString(), value));
      _printLine('╚');
    }
  }

  void logPrint(dynamic obj) {
    if (useInspect && obj != null) {
      Map<String, dynamic> map = obj.cast<String, dynamic>();
      httpDebug[requestId]![event!.name]![map.keys.first] = map.values.first;
    } else {
      String str = "$obj";
      logStr += "$str\n";
    }
  }

  void _showLog() {
    if (useInspect) {
      if (event == PrettyDioLoggerEvent.request) {
        if (httpDebug.length >= 50) httpDebug.remove(httpDebug.keys.first);
        inspect(httpDebug[requestId]);
      }
    } else {
      developer.log(logStr, name: 'HttpDio');
      logStr = '';
    }
  }
}
