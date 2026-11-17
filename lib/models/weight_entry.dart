class WeightEntry {
  final int? id;
  final int groupId;
  final double weight;
  final DateTime createdAt;
  final DateTime updatedAt;

  WeightEntry({
    this.id,
    required this.groupId,
    required this.weight,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  WeightEntry copyWith({
    int? id,
    int? groupId,
    double? weight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      weight: weight ?? this.weight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'group_id': groupId,
      'weight': weight,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory WeightEntry.fromMap(Map<String, dynamic> map) {
    return WeightEntry(
      id: map['id'] as int?,
      groupId: map['group_id'] as int,
      weight: (map['weight'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
