import 'dart:convert';
import 'package:flutter_gen/gen_l10n/translate.dart';
import 'package:flutter/material.dart';

class Address {
  final String? raw;
  final String pre; // pretty/preformatted address

  Address({required this.raw, required this.pre});

  factory Address.fromJson(String str) => Address.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory Address.fromMap(Map<String, dynamic> json) => Address(
        raw: json['raw'],
        pre: fixUnnamedStreet(json['pre']),
      );

  Map<String, dynamic> toMap() => {
        "raw": raw,
        "pre": pre,
      };

  /// Se address è null, il server ritorna la stringa " • Lipjan • Pristhinë" invece di "Lipjan • Pristhinë"
  /// Bisognerebbe farlo lato server ma si romperebbe la compatibilità con le vecchie versioni dell'app
  static String fixUnnamedStreet(String value) {
    return value.replaceAll(RegExp(r'^\s*\u2022\s*'), ''); // \u2022 ---> •
  }

  String unnamedStreet(BuildContext context) {
    assert(raw == null);
    return Translate.of(context).no_name_street + " \u{2022} " + pre;
  }
}
