import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grestapp_homeal_app/api/api_response_dio.dart';
import 'package:grestapp_homeal_app/providers/auth_provider.dart';
import 'package:grestapp_homeal_app/providers/locale_provider.dart';
import 'package:grestapp_homeal_app/utils/extensions/uri_extension.dart';
import 'package:grestapp_homeal_app/utils/my-libraries/pretty_dio_logger.dart';
import 'package:grestapp_homeal_app/utils/services/cookie_jar_service.dart';
import 'package:grestapp_homeal_app/utils/services/snack_bar_service.dart';
import 'package:grestapp_homeal_app/constants/constants.dart';
import 'package:provider/provider.dart';
import 'package:grestapp_homeal_app/utils/helpers/misc_helper.dart';
import 'package:http_query_string/http_query_string.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_gen/gen_l10n/translate.dart';

enum HttpDioMethod { get, post, patch, put, delete, patch_, put_, delete_ }

class HttpDio_ {
  final int maxRedirects = 5;
  late HttpDioMethod method;
  late String host;
  Map<String, dynamic>? queryParameters;
  Map<String, String> headers = {};
  late Uri url;
  List<Map<String, List<Uint8List>>> rawImages = [];

  HttpDio_(this.method, String urlOrPath, [this.queryParameters]) {
    _setMethod();
    _setUrl(urlOrPath);
    _paramsCasting();
    _addHeaders();
  }

  void _setMethod() {
    if ([HttpDioMethod.patch_, HttpDioMethod.put_, HttpDioMethod.delete_].contains(method)) {
      queryParameters ??= {};
      queryParameters!['_method'] = method.name.substring(0, method.name.length - 1).toUpperCase();
      method = HttpDioMethod.post;
    }
  }

  Future<ApiResponseDio> send([BuildContext? ctx]) async {
    BuildContext context = ctx ?? globalScaffoldKey.currentContext!;
    int redirects = 0;

    if (Const.appEnv != AppEnv.production) {
      await Future.delayed(Duration(milliseconds: Const.serverLatency));
    }

    Dio dio = Dio(/* BaseOptions() */)
          ..options.connectTimeout = const Duration(seconds: Const.httpTimeout)
          ..options.receiveTimeout = const Duration(seconds: Const.httpTimeout)
          ..options.followRedirects = url.host == Const.serverDns
              ? false
              : true // https://pub.dev/packages/dio_cookie_manager#handling-cookies-with-redirect-requests
          ..options.headers = headers
          ..options.method = method.name
          ..interceptors.add(CookieManager(CookieJarService.defaultJar))
          ..options.validateStatus = (status) =>
              status !=
              null /* [
            ...ApiResponseDio.successfulStatusCodes(),
            ...ApiResponseDio.redirectStatusCodes(),
            ...ApiResponseDio.validationErrorStatusCodes()
          ].contains(status) */
        ;

    if (kDebugMode && Const.appEnv != AppEnv.production) {
      dio.interceptors.add(
        PrettyDioLogger_(),
      );
    }

    late Response response;
    ApiResponseDio apiResponse;

    try {
      if (method == HttpDioMethod.get && queryParameters != null) {
        url = Uri.parse('${url.toString()}?${Encoder().convert(queryParameters ?? {})}');
      }
      Object? data = method != HttpDioMethod.get ? queryParameters : null;

      while (redirects < maxRedirects) {
        if (rawImages.isEmpty) {
          response = await dio.request(url.toString(), data: data, options: Options(contentType: Headers.jsonContentType));
        } else {
          queryParameters = queryParameters ?? {};
          List<MapEntry<String, MultipartFile>> images = _handleFiles();
          for (MapEntry<String, MultipartFile> x in images) {
            queryParameters![x.key] = x.value;
            // formData.files.add(x);
          }
          var formData = FormData.fromMap(queryParameters!);
          response = await dio.post(url.toString(), data: formData, options: Options(contentType: Headers.multipartFormDataContentType));
        }

        if (url.host == Const.serverDns && response.headers.value(HttpHeaders.locationHeader) != null) {
          _setUrl(
            response.headers.value(HttpHeaders.locationHeader)!,
          ); // https://pub.dev/packages/dio_cookie_manager#handling-cookies-with-redirect-requests
        } else {
          break;
        }

        redirects++;
      }

      apiResponse = ApiResponseDio(response, url, context);
    } /* on DioException catch (e, s) {
      print(e.toString());
      print(s.toString());
    }  */
    catch (e, s) {
      flutterLog(e, color: 'red');
      flutterLog(s, color: 'red');

      if (e is TimeoutException) {
        apiResponse = ApiResponseDio.serviceUnavailable(context);
      } else {
        apiResponse = ApiResponseDio.unknownError(context);
      }
    }

    //List<Cookie> cookies = await CookieJarService.defaultJar.loadForRequest(url);
    //flutterLog(cookies, color: 'red');

    // await CookieJarService.updateMyCookies(); commentato perchè al momento non li uso

    // context = context.mounted ? context : globalScaffoldKey.currentContext!;

    if (url.host == Const.serverDns) {
      try {
        await _statusCodeActions(apiResponse, context);
      } catch (e, s) {
        flutterLog(e, color: 'red');
        flutterLog(s, color: 'red');
        rethrow;
      }
    }

    // await _ircActions(apiResponse);

    return apiResponse;
  }

  void _setUrl(String urlOrPath) {
    if (_isUrl(urlOrPath)) {
      url = Uri.parse(urlOrPath);
      if (url.host == Const.serverDns &&
          (url.pathSegments.isEmpty || url.pathSegments[0] != 'api' || url.pathSegments[1] != 'v${Const.appVersionMajorRelease}')) {
        url = url.replace(path: 'api/v${Const.appVersionMajorRelease}${url.path}');
      }
      assert(url.isScheme('HTTPS'));
    } else {
      assert(urlOrPath[0] == '/');
      url = Uri.https(Const.serverDns, 'api/v${Const.appVersionMajorRelease}$urlOrPath');
    }
    host = url.host;
    if (host == Const.serverDns && method == HttpDioMethod.get) {
      url = url.withTrailingSlash();
    }
  }

  void _paramsCasting() {
    if (queryParameters != null) {
      queryParameters = queryParameters!.map((key, value) {
        if (value == null) {
          return MapEntry(key, '');
        } else if (value is String) {
          return MapEntry(key, value.trim());
        } else if ((value is List<Uint8List> && value.isNotEmpty) || value is Uint8List) {
          assert(method == HttpDioMethod.post);
          if (value is Uint8List) {
            value = [value];
          }
          rawImages.add({key: value});
          return const MapEntry('_', '');
        } else if (value is List || value is Map) {
          //return MapEntry(key, jsonEncode(value).trim());
          return MapEntry(key, value);
        } else if (value is int || value is double) {
          //return MapEntry(key, value.toString().trim());
          return MapEntry(key, value.toString());
        } else if (value is bool) {
          if (value == true) {
            return MapEntry(key, '1');
            //return MapEntry(key, value);
          } else if (value == false) {
            return MapEntry(key, '0');
            //return MapEntry(key, value);
          }
        }
        throw Exception("invalid data type");
      });
      queryParameters!.removeWhere((key, value) => key == '_');
    }
  }

  List<MapEntry<String, MultipartFile>> _handleFiles() {
    List<MapEntry<String, MultipartFile>> multipartFiles = [];
    for (Map<String, List<Uint8List>> files in rawImages) {
      files.forEach((key, value) {
        if (value.length > 1) {
          for (int i = 0; i < value.length; i++) {
            multipartFiles.add(MapEntry("$key[$i]", MultipartFile.fromBytes(value[i], filename: generateRandomString(16))));
          }
        } else {
          multipartFiles.add(MapEntry(key, MultipartFile.fromBytes(value[0], filename: generateRandomString(16))));
        }
      });
    }

    return multipartFiles;
  }

  void _addHeaders() {
    if (rawImages.isEmpty) headers['content-type'] = 'application/json';
    headers['accept'] = 'application/json';
    headers['accept-encoding'] = 'gzip,deflate';

    if (url.host == Const.serverDns) {
      headers['Y-User-Id'] = AuthProvider.userStatic?.id ?? '';
      headers['Y-Version'] = Const.appVersionComplete;
      headers['Y-Platform'] = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown');
      headers['accept-language'] =
          LocaleProvider.languageCode ?? ''; // da migliorare? la prima richiesta al server (/first-run) non ha un languageCode

      if (Const.appEnv == AppEnv.development) {
        String httpAuth =
            base64.encode(utf8.encode('${deobfuscateEnv(Const.httpBasicAuthUser)}:${deobfuscateEnv(Const.httpBasicAuthPassword)}'));
        headers['authorization'] = 'Basic $httpAuth';
      }

      if (Const.elbMaintenanceKey.isNotEmpty) {
        headers['Elb-Maintenance-Key'] = deobfuscateEnv(Const.elbMaintenanceKey);
      }
    }
  }

  Future<void> _statusCodeActions(ApiResponseDio apiResponse, BuildContext context) async {
    bool loginOrLogout = false;

    if (apiResponse.unauthenticated()) {
      loginOrLogout = true;
      await AuthProvider.logout(context);
    } else if (apiResponse.differentUserId() && apiResponse.success()) {
      if (apiResponse.userIdHeader() != null && !AuthProvider.loggedIn() && apiResponse.user != null) {
        loginOrLogout = true;
        await AuthProvider.login(apiResponse.user!, context);
      } else if (apiResponse.userIdHeader() == null && AuthProvider.loggedIn()) {
        loginOrLogout = true;
        await AuthProvider.logout(context);
      }
    } else if (apiResponse.statusCode == 503) {
      SnackBarService(Translate.of(context).serviceUnavailableText, SnackBarType.error, context).show();
    } else {
      SnackBarType? snackBarType = apiResponse.success()
          ? SnackBarType.success
          : ((apiResponse.hasValidationErrors() || apiResponse.warning())
              ? SnackBarType.info
              : (apiResponse.error() ? SnackBarType.error : null));
      if (snackBarType != null) SnackBarService(apiResponse.message, snackBarType, context).duration(3000).show();
    }

    if (!loginOrLogout && context.mounted && apiResponse.success()) {
      await context.read<AuthProvider>().update(apiResponse.user);
    }
  }

  //funziona male forse perchè rimane nella cache l'ip del dns e quindi risulta raggiungibile anche quando non è vero
  /* Future<bool> noConnection() async {
    try {
      final addressLookup = await InternetAddress.lookup(Const.connectionTestDns)
          .timeout(const Duration(seconds: 1), onTimeout: () => throw const SocketException(''));
      if (addressLookup.isNotEmpty && addressLookup[0].rawAddress.isNotEmpty) {
        //connesso
      }
    } on SocketException catch (_) {
      if (ultimoAvvisoAssenzaConnessione == null ||
        ultimoAvvisoAssenzaConnessione!.add(const Duration(seconds: AVVISO_ASSENZA_CONNESSIONE_LIMITE_SECONDI)).isBefore(DateTime.now())) {
      ultimoAvvisoAssenzaConnessione = DateTime.now();
      SnackBarService(Translate.of(context).noResponseFromServer, "info", context);
    }
      return true;
    }
    return false;
  } */

  /* Future<void> _ircActions(ApiResponseDio response) async {
    switch (response.irc) {
      case 1: // utente bannato
        await AuthProvider.logout();
        break;
      default:
      //nothing
    }
  } */

  bool _isUrl(String value) {
    return Uri.tryParse(value)?.hasScheme ?? false;
  }
}
