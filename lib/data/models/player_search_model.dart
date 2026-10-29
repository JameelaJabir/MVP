class PlayerSearchModel {
  final int id;
  final String name;
  final String? photoUrl;
  final String? email;
  final double? rating;
  final bool isFavourite;
  final String? membershipTier;
  const PlayerSearchModel({
    required this.id,
    required this.name,
    this.photoUrl,
    this.email,
    this.rating,
    this.isFavourite = false,
    this.membershipTier,
  });
  factory PlayerSearchModel.fromJson(Map<String, dynamic> json) {
    final firstName = json['first_name']?.toString() ??
        json['name']?.toString() ?? '';
    final lastName = json['last_name']?.toString() ?? '';
    final combined = '$firstName $lastName'.trim();
    double? parseRating(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v);
      return null;
    }
    return PlayerSearchModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: combined.isNotEmpty ? combined : '',
      photoUrl: json['profile_image_url']?.toString() ??
          json['photo_url']?.toString() ??
          json['photo']?.toString() ??
          json['image']?.toString(),
      email: json['email']?.toString(),
      rating: parseRating(json['rating']) ??
          parseRating(json['wppr_rating']) ??
          parseRating(json['avg_rating']) ??
          parseRating(json['player_rating']),
      isFavourite: json['is_favourite'] == true,
      membershipTier: json['membership_tier']?.toString() ??
          json['membership_type']?.toString() ??
          json['tier']?.toString() ??
          json['plan_name']?.toString() ??
          json['membership']?.toString(),
    );
  }
}
