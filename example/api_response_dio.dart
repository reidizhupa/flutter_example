import 'package:flutter_gen/gen_l10n/translate.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:grestapp_homeal_app/constants/constants.dart';
import 'package:grestapp_homeal_app/models/database/user.dart';
import 'package:grestapp_homeal_app/providers/auth_provider.dart';
import 'package:grestapp_homeal_app/utils/helpers/misc_helper.dart';

class ApiResponseDio {
  late int statusCode;
  dynamic body;
  Headers? headers;
  String? cookies;
  // ----- specifici del mio server
  String? message;
  dynamic data;
  Map<String, dynamic>? meta;
  Map<String, dynamic>? links;
  Map<String, List>? errors;
  User? user;
  // int? irc;
  // -----
  static List<int> successfulStatusCodes = [200, 201, 202, 204];
  static List<int> successfulNoContentStatusCodes = [204];
  static List<int> redirectStatusCodes = [301, 302];
  static List<int> validationErrorStatusCodes = [422];
  static List<int> unauthenticatedStatusCodes = [401];
  static List<int> warningStatusCodes = [400];

  ApiResponseDio(Response response, Uri url, [BuildContext? ctx]) {
    BuildContext context = ctx ?? globalScaffoldKey.currentContext!;

    statusCode = response.statusCode ?? 500;
    headers = response.headers;
    _parseBody(response, url);

    // organizzo le risposte del mio server
    if (url.host == Const.serverDns) {
      if (success() /*  || redirect() */) {
        if (!successNoContent()) {
          message = body!['message'];
          data = body!['data'];
          meta = body!['meta'];
          links = body!['links'];
          user = body!['user'] != null ? User.fromMap(body!['user']) : null;
        }
      } else if (hasValidationErrors()) {
        errors = Map.from(body?['errors'] ?? {}); // <-- controllare se c'è sempre
        if (errors!.isEmpty) errors = null;
        message = getValidationErrorMessages();
        // irc = body?['irc'];
      } else if (warning()) {
        message = body?['message'];
      } else if (error()) {
        message = Translate.of(context).serverError;
      }
    }
  }

  ApiResponseDio.unknownError([BuildContext? ctx]) {
    BuildContext context = ctx ?? globalScaffoldKey.currentContext!;
    statusCode = 500;
    message = Translate.of(context).serverError;
  }

  ApiResponseDio.serviceUnavailable([BuildContext? ctx]) {
    BuildContext context = ctx ?? globalScaffoldKey.currentContext!;
    statusCode = 503;
    message = Translate.of(context).noResponseFromServer;
  }

  bool success() {
    return successfulStatusCodes.contains(statusCode);
  }

  bool successNoContent() {
    return successfulNoContentStatusCodes.contains(statusCode);
  }

  bool warning() {
    return warningStatusCodes.contains(statusCode);
  }

  bool unauthenticated() {
    return unauthenticatedStatusCodes.contains(statusCode);
  }

  bool redirect() {
    return redirectStatusCodes.contains(statusCode);
  }

  bool differentUserId() {
    if (headers == null) return false;
    String? userId = userIdHeader();
    return userId != AuthProvider.userStatic?.id;
  }

  String? userIdHeader() {
    String? userId = headers?.value('Y-User-Id');
    if (userId == '') userId = null;
    return userId;
  }

  bool error() {
    return statusCode >= 500;
  }

  bool hasValidationErrors() {
    return validationErrorStatusCodes.contains(statusCode);
  }

  bool hasValidationErrorMessages() {
    return errors is Map && errors!.isNotEmpty;
  }

  String? getValidationErrorMessages() {
    if (!hasValidationErrorMessages()) return null;
    String str = '';
    for (List value in errors!.values) {
      for (String s in value) {
        if (str.isNotEmpty) str += "\n";
        str += s;
      }
    }
    return str;
  }

  void _parseBody(Response response, Uri url) {
    if (response.data is String) response.data = (response.data as String).trim();

    body = response.data == '' ? null : response.data;

    // flutterLog(body);

    if (response.data is! Map && response.data != null && response.data != '') {
      // serve per gestire risposte del tipo:
      //<html><head><title>504 Gateway Time-out</title></head><body><center><h1>504 Gateway Time-out</h1></center><hr><center>nginx</center></body></html>
      flutterLog("La risposta del server non è in formato json:\n${response.data}", json: false);
      body = null;
    }
  }
}
