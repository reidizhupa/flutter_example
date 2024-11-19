import 'package:flutter_gen/gen_l10n/translate.dart'; // For localization
import 'package:dio/dio.dart'; // For HTTP requests and responses
import 'package:flutter/material.dart'; // For BuildContext
import 'package:app/constants/constants.dart'; // App constants
import 'package:app/models/database/user.dart'; // User model
import 'package:app/providers/auth_provider.dart'; // Authentication provider

/// Handles and organizes server responses using Dio.
/// Parses status codes, headers, and server-specific fields like `message`, `data`, and `errors`.
/// Supports localized error messages and validation error formatting.
class ApiResponseDio {
  late int statusCode;
  dynamic body, data;
  Headers? headers;
  String? cookies, message;
  Map<String, dynamic>? meta, links;
  Map<String, List>? errors;
  User? user;

  static final successCodes = [200, 201, 202, 204];
  static final noContentCodes = [204];
  static final validationCodes = [422];
  static final warningCodes = [400];

  ApiResponseDio(Response response, Uri url, [BuildContext? ctx]) {
    BuildContext context = ctx ?? globalScaffoldKey.currentContext!;
    statusCode = response.statusCode ?? 500;
    headers = response.headers;
    _parseBody(response);

    if (url.host == Const.serverDns) {
      if (success()) {
        if (!noContent()) {
          message = body?['message'];
          data = body?['data'];
          meta = body?['meta'];
          links = body?['links'];
          user = body?['user'] != null ? User.fromMap(body!['user']) : null;
        }
      } else if (hasValidationErrors()) {
        errors = Map.from(body?['errors'] ?? {});
        message = _validationErrorMessages();
      } else {
        message = warning() ? body?['message'] : Translate.of(context).serverError;
      }
    }
  }

  ApiResponseDio.unknownError([BuildContext? ctx])
      : this._fromStatus(500, Translate.of(ctx ?? globalScaffoldKey.currentContext!).serverError);

  ApiResponseDio.serviceUnavailable([BuildContext? ctx])
      : this._fromStatus(503, Translate.of(ctx ?? globalScaffoldKey.currentContext!).noResponseFromServer);

  ApiResponseDio._fromStatus(this.statusCode, this.message);

  bool success() => successCodes.contains(statusCode);
  bool noContent() => noContentCodes.contains(statusCode);
  bool warning() => warningCodes.contains(statusCode);
  bool hasValidationErrors() => validationCodes.contains(statusCode);

  void _parseBody(Response response) {
    body = (response.data is String) ? (response.data as String).trim() : response.data;
    if (body is! Map && body != null) body = null; // Ensure JSON format.
  }

  String? _validationErrorMessages() {
    if (errors == null || errors!.isEmpty) return null;
    return errors!.values.expand((v) => v).join("\n");
  }
}
