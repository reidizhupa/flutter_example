import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:grestapp_homeal_app/api/api_response_dio.dart';
import 'package:grestapp_homeal_app/constants/enums/models/database/user/user_gender.dart';
import 'package:grestapp_homeal_app/constants/enums/models/database/user/user_type.dart';
import 'package:grestapp_homeal_app/models/database/listing.dart';
import 'package:grestapp_homeal_app/utils/my-libraries/date_time_manager.dart';
import 'package:grestapp_homeal_app/models/database/company.dart';
import 'package:grestapp_homeal_app/utils/my-libraries/http_dio.dart';

class User {
  String id;
  String? email; // può essere null quando un utente non ha verificato la mail
  UserType type;
  String avatarUrl;
  String name;
  String surname;
  Company? company;
  UserGender? gender;
  DateTime? dateOfBirth;
  String? phoneNumber;
  List<Listing>? listings;
  // -----
  DateTime? emailVerifiedAt;
  DateTime? phoneNumberVerifiedAt;

  User({
    required this.id,
    required this.email,
    required this.type,
    required this.avatarUrl,
    required this.name,
    required this.surname,
    this.company,
    this.gender,
    this.dateOfBirth,
    this.phoneNumber,
    this.listings,
    this.emailVerifiedAt,
    this.phoneNumberVerifiedAt,
  });

  User copyWith({
    String? id,
    String? email,
    UserType? type,
    String? avatarUrl,
    String? name,
    String? surname,
    Company? company,
    UserGender? gender,
    DateTime? dateOfBirth,
    String? phoneNumber,
    List<Listing>? listings,
    DateTime? emailVerifiedAt,
    DateTime? phoneNumberVerifiedAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        type: type ?? this.type,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        name: name ?? this.name,
        surname: surname ?? this.surname,
        company: company ?? this.company,
        gender: gender ?? this.gender, //gender != null ? (gender is UserGender ? gender : UserGender.values.byName(gender)) : this.gender
        dateOfBirth: dateOfBirth ?? this.dateOfBirth,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        listings: listings ?? this.listings,
        emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
        phoneNumberVerifiedAt: phoneNumberVerifiedAt ?? this.phoneNumberVerifiedAt,
      );

  factory User.fromJson(String str) => User.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  // assert(!AuthProvider.loggedIn() || (AuthProvider.loggedIn() && ));
  factory User.fromMap(Map<String, dynamic> json) => User(
        id: json["id"],
        email: json["email"],
        type: UserType.values.byName(json['type']),
        avatarUrl: json["avatar_url"],
        name: json["name"],
        surname: json["surname"],
        company: json["company"] != null ? Company.fromMap(json["company"]) : null,
        gender: json['gender'] != null ? UserGender.values.byName(json['gender']) : null,
        dateOfBirth: json['date_of_birth'] != null ? DateTimeManager.str_obj(json['date_of_birth'], 'yyyy-MM-dd', isUtc: true) : null,
        phoneNumber: json['phone_number'],
        listings: json['listings'] != null ? List<Listing>.from(json["listings"].map((x) => Listing.fromMap(x))) : null,
        emailVerifiedAt:
            json['email_verified_at'] != null ? DateTimeManager.str_obj(json['email_verified_at'], 'yyyy-MM-dd', isUtc: true) : null,
        phoneNumberVerifiedAt: json['phone_number_verified_at'] != null
            ? DateTimeManager.str_obj(json['phone_number_verified_at'], 'yyyy-MM-dd', isUtc: true)
            : null,
      );

  Map<String, dynamic> toMap([forCache = false]) => {
        "id": id,
        "email": email,
        "type": type.name,
        "avatar_url": avatarUrl,
        "name": name,
        "surname": surname,
        "company": !forCache ? company?.toMap() : null,
        "gender": gender?.name,
        "date_of_birth": dateOfBirth != null ? DateTimeManager.obj_str(dateOfBirth!, 'yyyy-MM-dd') : null,
        "phone_number": phoneNumber,
        'listings': !forCache ? (listings != null ? List<dynamic>.from(listings!.map((x) => x.toMap())) : null) : null,
        'email_verified_at': emailVerifiedAt != null ? DateTimeManager.obj_str(emailVerifiedAt!, 'yyyy-MM-dd') : null,
        'phone_number_verified_at': phoneNumberVerifiedAt != null ? DateTimeManager.obj_str(phoneNumberVerifiedAt!, 'yyyy-MM-dd') : null,
      };

  Map<String, dynamic> forCache() => toMap(true);

  static Future<User?> fetch(BuildContext context /*, {bool a = false}*/) async {
    //if (dataLoaded && a != true) return null;
    ApiResponseDio response = await HttpDio_(HttpDioMethod.get, '/user/profile').send();
    if (response.success()) {
      return User.fromMap(response.data['user']);
    }
    return null;
  }
}
