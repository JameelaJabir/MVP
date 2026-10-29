class ClubModel {
  final int id;
  final String name;
  ClubModel({required this.id, required this.name});
  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
}
