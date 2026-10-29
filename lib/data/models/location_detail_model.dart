class LocationDetailModel {
  final int id;
  final String name;
  final String address;
  final String? imageUrl;
  final String? about;
  final List<SubCourtModel> courts;
  final List<CourtAddonModel> addons;
  final List<InstructorModel> instructors;
  final List<FacilityModel> facilities;
  final List<LessonTypeModel> lessonTypes;
  const LocationDetailModel({
    required this.id,
    required this.name,
    required this.address,
    this.imageUrl,
    this.about,
    required this.courts,
    required this.addons,
    required this.instructors,
    required this.facilities,
    required this.lessonTypes,
  });
  static String _parseAddress(dynamic raw) {
    if (raw == null) return '';
    if (raw is String) return raw;
    if (raw is Map<String, dynamic>) {
      final parts = <String>[];
      final line = raw['address_line']?.toString() ??
          raw['addressline']?.toString() ??
          raw['address1']?.toString() ??
          raw['street']?.toString() ??
          '';
      final city = raw['city']?.toString() ?? '';
      final state = raw['state']?.toString() ?? raw['province']?.toString() ?? '';
      final country = raw['country']?.toString() ?? '';
      if (line.isNotEmpty) parts.add(line);
      if (city.isNotEmpty) parts.add(city);
      if (state.isNotEmpty) parts.add(state);
      if (country.isNotEmpty) parts.add(country);
      return parts.join(', ');
    }
    return raw.toString();
  }
  factory LocationDetailModel.fromJson(Map<String, dynamic> raw) {
    final json = raw['data'] is Map<String, dynamic>
        ? raw['data'] as Map<String, dynamic>
        : raw;
    List<dynamic> courtsRaw =
        (json['courts'] ?? json['sub_courts'] ?? []) as List<dynamic>;
    List<dynamic> addonsRaw =
        (json['attributes'] ?? json['court_attributes'] ?? []) as List<dynamic>;
    List<dynamic> instructorsRaw =
        (json['instructors'] ?? []) as List<dynamic>;
    List<dynamic> facilitiesRaw =
        (json['facilities'] ?? json['amenities'] ?? []) as List<dynamic>;
    List<dynamic> lessonTypesRaw =
        (json['lesson_types'] ?? json['lessons'] ?? []) as List<dynamic>;
    return LocationDetailModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      address: _parseAddress(json['address']),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      about: json['about']?.toString() ?? json['description']?.toString(),
      courts: courtsRaw
          .whereType<Map<String, dynamic>>()
          .map(SubCourtModel.fromJson)
          .toList(),
      addons: addonsRaw
          .whereType<Map<String, dynamic>>()
          .map(CourtAddonModel.fromJson)
          .toList(),
      instructors: instructorsRaw
          .whereType<Map<String, dynamic>>()
          .map(InstructorModel.fromJson)
          .toList(),
      facilities: facilitiesRaw
          .whereType<Map<String, dynamic>>()
          .map(FacilityModel.fromJson)
          .toList(),
      lessonTypes: lessonTypesRaw
          .whereType<Map<String, dynamic>>()
          .map(LessonTypeModel.fromJson)
          .toList(),
    );
  }
}
class SubCourtModel {
  final int id;
  final String name;
  final String? imageUrl;
  const SubCourtModel({
    required this.id,
    required this.name,
    this.imageUrl,
  });
  factory SubCourtModel.fromJson(Map<String, dynamic> json) {
    return SubCourtModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
    );
  }
}
class CourtAddonModel {
  final int id;
  final int courtAttributeId;
  final String name;
  final String? imageUrl;
  final double price;
  int quantity;
  CourtAddonModel({
    required this.id,
    required this.courtAttributeId,
    required this.name,
    this.imageUrl,
    required this.price,
    this.quantity = 0,
  });
  factory CourtAddonModel.fromJson(Map<String, dynamic> json) {
    return CourtAddonModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      courtAttributeId:
          (json['court_attribute_id'] as num?)?.toInt() ??
              (json['id'] as num?)?.toInt() ??
              0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      quantity: 0,
    );
  }
}
class InstructorModel {
  final int id;
  final String name;
  final String? photoUrl;
  const InstructorModel({
    required this.id,
    required this.name,
    this.photoUrl,
  });
  factory InstructorModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';
    final combined = '$firstName $lastName'.trim();
    final name = combined.isNotEmpty
        ? combined
        : json['name']?.toString() ?? '';
    return InstructorModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: name,
      photoUrl:
          json['photo_url']?.toString() ?? json['photo']?.toString() ?? json['image']?.toString(),
    );
  }
}
class FacilityModel {
  final int id;
  final String name;
  final String? iconUrl;
  const FacilityModel({
    required this.id,
    required this.name,
    this.iconUrl,
  });
  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      iconUrl: json['icon_url']?.toString() ?? json['icon']?.toString() ?? json['image']?.toString(),
    );
  }
}
class LessonTypeModel {
  final int id;
  final String name;
  final String? imageUrl;
  const LessonTypeModel({
    required this.id,
    required this.name,
    this.imageUrl,
  });
  factory LessonTypeModel.fromJson(Map<String, dynamic> json) {
    return LessonTypeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString(),
    );
  }
}
