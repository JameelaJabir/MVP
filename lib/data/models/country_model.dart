class CountryModel {
  final int id;
  final String name;
  final String phoneCode;
  final String flag;
  CountryModel({
    required this.id,
    required this.name,
    required this.phoneCode,
    required this.flag,
  });
  factory CountryModel.fromJson(Map<String, dynamic> json) {
    final raw = json['phone_code']?.toString() ??
        json['phoneCode']?.toString() ??
        json['calling_code']?.toString() ??
        json['dial_code']?.toString() ??
        '';
    final phoneCode = raw.isEmpty
        ? ''
        : raw.startsWith('+') ? raw : '+$raw';
    String flag = json['flag']?.toString() ??
        json['emoji']?.toString() ??
        json['flag_emoji']?.toString() ?? '';
    if (flag.isEmpty) {
      final code = json['code']?.toString() ?? '';
      if (code.length == 2) {
        flag = code.toUpperCase().codeUnits
            .map((c) => String.fromCharCode(c - 0x41 + 0x1F1E6))
            .join();
      }
    }
    return CountryModel(
      id: json['id'] as int,
      name: json['name']?.toString() ?? '',
      phoneCode: phoneCode,
      flag: flag,
    );
  }
}
