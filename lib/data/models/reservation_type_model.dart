class ReservationTypeModel {
  final int id;
  final String name;
  final int? maxPlayers;
  const ReservationTypeModel({
    required this.id,
    required this.name,
    this.maxPlayers,
  });
  factory ReservationTypeModel.fromJson(Map<String, dynamic> json) {
    final maxRaw = json['max_players'] ?? json['number_of_players'];
    return ReservationTypeModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      maxPlayers: (maxRaw as num?)?.toInt(),
    );
  }
}
