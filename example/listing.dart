import 'dart:convert';

import 'package:grestapp_homeal_app/constants/enums/models/database/listing/listing_category.dart';
import 'package:grestapp_homeal_app/constants/enums/models/database/listing/listing_status.dart';
import 'package:grestapp_homeal_app/constants/enums/models/database/listing/listing_type.dart';
import 'package:grestapp_homeal_app/models/database/listing_image.dart';
import 'package:grestapp_homeal_app/models/database/listing_video.dart';
import 'package:grestapp_homeal_app/models/database/location.dart';
import 'package:grestapp_homeal_app/models/database/user.dart';
import 'package:grestapp_homeal_app/providers/models/saved_listings.dart';
import 'package:grestapp_homeal_app/utils/extensions/datetime_extension.dart';
import 'package:grestapp_homeal_app/utils/my-libraries/date_time_manager.dart';
import 'package:grestapp_homeal_app/providers/auth_provider.dart';

class Listing {
  String id;
  ListingCategory category;
  ListingType type;
  String price;
  String? description;
  ListingStatus status;
  String? referenceNumber;
  int viewsCount;
  int sharesCount;
  int savesCount;
  DateTime createdAt;
  DateTime updatedAt;
  Map<String, Map<String, dynamic>>? cardSpecificAttributes;
  Map<String, Map<String, dynamic>>? amenities;
  Map<String, Map<String, dynamic>>? propertyInfo;
  //resources -  collections
  User? user;
  Location location;
  List<ListingImage> photos;
  List<ListingImage>? floorplans;
  ListingVideo? video;
  List<Listing>? recommendedListings;
  bool isSaved;
  //others
  bool savedLoading = false; //per evitare che click multipli possano creare cloni
  bool isHidden;
  bool hiddenLoading = false;

  Listing({
    required this.id,
    this.user,
    required this.category,
    required this.type,
    required this.location,
    required this.price,
    required this.description,
    required this.status,
    required this.referenceNumber,
    required this.viewsCount,
    required this.sharesCount,
    required this.savesCount,
    required this.createdAt,
    required this.updatedAt,
    required this.photos,
    this.floorplans,
    this.video,
    this.recommendedListings,
    this.cardSpecificAttributes,
    this.amenities,
    this.propertyInfo,
    required this.isSaved,
    required this.isHidden,
  });

  Listing copyWith({
    String? id,
    User? user,
    ListingCategory? category,
    ListingType? type,
    Location? location,
    String? price,
    String? description,
    ListingStatus? status,
    String? referenceNumber,
    int? viewsCount,
    int? sharesCount,
    int? savesCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ListingImage>? photos,
    List<ListingImage>? floorplans,
    ListingVideo? video,
    List<Listing>? recommendedListings,
    Map<String, Map<String, dynamic>>? cardSpecificAttributes,
    Map<String, Map<String, dynamic>>? amenities,
    Map<String, Map<String, dynamic>>? propertyInfo,
    bool? isSaved,
    bool? isHidden,
  }) =>
      Listing(
        id: id ?? this.id,
        user: user ?? this.user,
        category: category ?? this.category,
        type: type ?? this.type,
        location: location ?? this.location,
        price: price ?? this.price,
        description: description ?? this.description,
        status: status ?? this.status,
        referenceNumber: referenceNumber ?? this.referenceNumber,
        viewsCount: viewsCount ?? this.viewsCount,
        sharesCount: sharesCount ?? this.sharesCount,
        savesCount: savesCount ?? this.savesCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        photos: photos ?? this.photos,
        floorplans: floorplans ?? this.floorplans,
        video: video ?? this.video,
        recommendedListings: recommendedListings ?? this.recommendedListings,
        cardSpecificAttributes: cardSpecificAttributes ?? this.cardSpecificAttributes,
        amenities: amenities ?? this.amenities,
        propertyInfo: propertyInfo ?? this.propertyInfo,
        isSaved: isSaved ?? this.isSaved,
        isHidden: isHidden ?? this.isHidden,
      );

  factory Listing.fromJson(String str) => Listing.fromMap(json.decode(str));

  String toJson() => json.encode(toMap());

  factory Listing.fromMap(Map<String, dynamic> json) => Listing(
        id: json["id"],
        user: json["user"] != null ? User.fromMap(json["user"]) : null,
        category: ListingCategory.values.byName(json['category']),
        type: ListingType.values.byName(json['type']),
        location: Location.fromMap(json["location"]),
        price: json["price"],
        description: json["description"],
        status: ListingStatus.values.byName(json['status']),
        referenceNumber: json["reference_number"],
        viewsCount: json["views_count"],
        sharesCount: json["shares_count"],
        savesCount: json["saves_count"],
        createdAt: DateTimeManager.tmp_obj(json['created_at']).toLocal(),
        updatedAt: DateTimeManager.tmp_obj(json['updated_at']).toLocal(),
        photos: List<ListingImage>.from(json["photos"].map((x) => ListingImage.fromMap(x))),
        /* json['photos'] != null && (json['photos'] as List).isNotEmpty
            ? List<ListingImage>.from(json["photos"].map((x) => ListingImage.fromMap(x)))
            : [ListingImage(url: '${Const.cdn}/api/v1/placeholder_logo.webp')], */
        floorplans: json["floorplans"] != null ? List<ListingImage>.from(json["floorplans"].map((x) => ListingImage.fromMap(x))) : null,
        video: json["video"] != null ? ListingVideo.fromMap(json["video"]) : null,
        recommendedListings:
            json["recommended_listings"] != null ? List<Listing>.from(json["recommended_listings"].map((x) => Listing.fromMap(x))) : null,
        cardSpecificAttributes: json["card_specific_attributes"] != null ? Map.from(json["card_specific_attributes"]) : null,
        amenities: json["amenities"] != null ? Map.from(json["amenities"]) : null,
        propertyInfo: json["property_info"] != null ? Map.from(json["property_info"]) : null,
        isSaved:
            AuthProvider.loggedIn() ? json['is_saved'] ?? false : (SavedListingsModelProvider.inCache.contains(json['id']) ? true : false),
        isHidden: json['is_hidden'] ?? false,
      );

  Map<String, dynamic> toMap() => {
        "id": id,
        "user": user != null ? user!.toMap() : null,
        "category": category.name,
        "type": type.name,
        "location": location.toMap(),
        "price": price,
        "description": description,
        "status": status.name,
        "reference_number": referenceNumber,
        "views_count": viewsCount,
        "shares_count": sharesCount,
        "saves_count": savesCount,
        "created_at": createdAt.secondsSinceEpoch(),
        "updated_at": updatedAt.secondsSinceEpoch(),
        "photos": List<dynamic>.from(photos.map((x) => x.toMap())),
        "floorplans": floorplans != null ? List<dynamic>.from(floorplans!.map((x) => x.toMap())) : null,
        "video": video != null ? video!.toMap() : null,
        "recommended_listings": recommendedListings != null ? List<dynamic>.from(recommendedListings!.map((x) => x.toMap())) : null,
        "card_specific_attributes": cardSpecificAttributes,
        "amenities": amenities,
        "property_info": propertyInfo,
        "is_saved": isSaved,
        "is_hidden": isHidden,
      };
}
