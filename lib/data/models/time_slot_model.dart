class TimeSlotModel {
  final String startTime;
  final String endTime;
  final bool isPeak;
  final bool isAvailable;
  final double price;
  final List<SubCourtRef> availableSubCourts;
  const TimeSlotModel({
    required this.startTime,
    required this.endTime,
    required this.isPeak,
    required this.isAvailable,
    required this.price,
    this.availableSubCourts = const [],
  });
  String get displayTime {
    try {
      final parts = startTime.split(' ');
      if (parts.length < 2) return startTime;
      final timeParts = parts[1].split(':');
      if (timeParts.length < 2) return startTime;
      int hour = int.parse(timeParts[0]);
      final int minute = int.parse(timeParts[1]);
      final String period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) {
        hour = 12;
      } else if (hour > 12) {
        hour -= 12;
      }
      final String minStr = minute.toString().padLeft(2, '0');
      return '$hour:$minStr $period';
    } catch (_) {
      return startTime;
    }
  }
  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    String startRaw;
    String endRaw;
    if (json['date'] != null && json['start'] != null) {
      final start = json['start'].toString().length == 5
          ? json['start'].toString()
          : json['start'].toString().padLeft(5, '0');
      final end = json['end'].toString().length == 5
          ? json['end'].toString()
          : json['end'].toString().padLeft(5, '0');
      startRaw = '${json['date']} $start:00';
      endRaw = '${json['date']} $end:00';
    } else {
      startRaw = json['start_time']?.toString() ?? json['start']?.toString() ?? '';
      endRaw = json['end_time']?.toString() ?? json['end']?.toString() ?? '';
    }
    final isPeakRaw = json['is_peak'] ?? json['peak'];
    bool isAvailable;
    if (json['disabled'] != null) {
      isAvailable = !(json['disabled'] == true || json['disabled'] == 1);
    } else {
      final raw = json['is_available'] ?? json['available'];
      isAvailable = raw == null ? true : (raw == true || raw == 1);
    }
    final subCourts = (json['available_sub_courts'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SubCourtRef.fromJson)
            .toList() ??
        [];
    return TimeSlotModel(
      startTime: startRaw,
      endTime: endRaw,
      isPeak: isPeakRaw == true || isPeakRaw == 1,
      isAvailable: isAvailable,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      availableSubCourts: subCourts,
    );
  }
}
class SubCourtRef {
  final int id;
  final String name;
  const SubCourtRef({required this.id, required this.name});
  factory SubCourtRef.fromJson(Map<String, dynamic> json) => SubCourtRef(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: json['name']?.toString() ?? '',
      );
}
