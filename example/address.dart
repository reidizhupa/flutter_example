import 'dart:convert'; // For JSON encoding and decoding
import 'package:flutter_gen/gen_l10n/translate.dart'; // For localization
import 'package:flutter/material.dart'; // For BuildContext and other Flutter widgets

/// The `Address` class represents an address with optional raw and preformatted versions.
/// It handles JSON serialization, deserialization, and corrects improperly formatted
/// addresses returned by the server. Specifically, it removes unnecessary leading
/// bullet points (e.g., " • Lipjan • Pristhinë" becomes "Lipjan • Pristhinë").
///
/// Additionally, it supports localization for unnamed streets by appending a
/// user-friendly string when the raw address is null.
class Address {
  final String? raw; // The raw address string, nullable.
  final String pre; // The preformatted (pretty) address string.

  /// Constructor for creating an [Address] instance.
  Address({required this.raw, required this.pre});

  /// Factory constructor to create an [Address] from a JSON string.
  factory Address.fromJson(String str) => Address.fromMap(json.decode(str));

  /// Converts the [Address] instance into a JSON string.
  String toJson() => json.encode(toMap());

  /// Factory constructor to create an [Address] from a Map.
  factory Address.fromMap(Map<String, dynamic> json) => Address(
        raw: json['raw'],
        pre: fixUnnamedStreet(json['pre']),
      );

  /// Converts the [Address] instance into a Map.
  Map<String, dynamic> toMap() => {
        "raw": raw,
        "pre": pre,
      };

  /// Fixes improperly formatted `pre` strings by removing leading bullet points.
  static String fixUnnamedStreet(String value) {
    return value.replaceAll(RegExp(r'^\s*\u2022\s*'), '');
  }

  /// Returns a localized string for unnamed streets, combining a translation with `pre`.
  String unnamedStreet(BuildContext context) {
    assert(raw == null);
    return Translate.of(context).no_name_street + " \u{2022} " + pre;
  }
}
