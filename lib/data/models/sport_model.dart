class SportModel {
  final int id;
  final String name;
  SportModel({required this.id, required this.name});
  factory SportModel.fromJson(Map<String, dynamic> json) {
    return SportModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
    );
  }
  String get emoji {
    final n = name.toLowerCase();
    if (n.contains('padel')) return '🏓';
    if (n.contains('tennis')) return '🎾';
    if (n.contains('squash')) return '🏸';
    if (n.contains('badminton')) return '🏸';
    if (n.contains('pickle')) return '🏓';
    return '🏅';
  }
}
