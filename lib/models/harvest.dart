class Harvest {
  final int? id;
  final String name;
  final DateTime harvestDate;
  final double? riceFieldCount;
  final String? notes;
  final String status; // 'in_progress' or 'completed'
  final double? pricePerKg;
  final String currency; // 'KHR' or 'USD'
  final DateTime createdAt;
  final DateTime updatedAt;

  Harvest({
    this.id,
    required this.name,
    required this.harvestDate,
    this.riceFieldCount,
    this.notes,
    this.status = 'in_progress',
    this.pricePerKg,
    this.currency = 'KHR',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isCompleted => status == 'completed';

  String? get formattedFieldCount {
    if (riceFieldCount == null) return null;
    if (riceFieldCount! % 1 == 0) {
      return riceFieldCount!.toInt().toString();
    }
    return riceFieldCount!.toString().replaceAll(RegExp(r'\.?0+$'), '');
  }

  Harvest copyWith({
    int? id,
    String? name,
    DateTime? harvestDate,
    double? riceFieldCount,
    String? notes,
    String? status,
    double? pricePerKg,
    String? currency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Harvest(
      id: id ?? this.id,
      name: name ?? this.name,
      harvestDate: harvestDate ?? this.harvestDate,
      riceFieldCount: riceFieldCount ?? this.riceFieldCount,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      pricePerKg: pricePerKg ?? this.pricePerKg,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'harvest_date': harvestDate.toIso8601String(),
      'rice_field_count': riceFieldCount,
      'notes': notes,
      'status': status,
      'price_per_kg': pricePerKg,
      'currency': currency,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Harvest.fromMap(Map<String, dynamic> map) {
    return Harvest(
      id: map['id'] as int?,
      name: map['name'] as String,
      harvestDate: DateTime.parse(map['harvest_date'] as String),
      riceFieldCount: (map['rice_field_count'] != null)
          ? (map['rice_field_count'] as num).toDouble()
          : null,
      notes: map['notes'] as String?,
      status: (map['status'] as String?) ?? 'in_progress',
      pricePerKg: (map['price_per_kg'] != null)
          ? (map['price_per_kg'] as num).toDouble()
          : null,
      currency: (map['currency'] as String?) ?? 'KHR',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
