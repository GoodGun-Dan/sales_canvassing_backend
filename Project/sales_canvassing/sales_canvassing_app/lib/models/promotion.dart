class Promotion {
  final int promotionId;
  final String promotionCode;
  final String description;
  final String type;
  final Map<String, dynamic> conditions;
  final Map<String, dynamic> reward;
  final String startDate;
  final String endDate;
  final bool isActive;

  Promotion({
    required this.promotionId,
    required this.promotionCode,
    required this.description,
    required this.type,
    required this.conditions,
    required this.reward,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      promotionId: _toInt(json['promotion_id']),
      promotionCode: json['promotion_code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      conditions: json['conditions'] is Map
          ? Map<String, dynamic>.from(json['conditions'])
          : {},
      reward: json['reward'] is Map
          ? Map<String, dynamic>.from(json['reward'])
          : {},
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString() ?? '',
      isActive: json['is_active'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }
}
