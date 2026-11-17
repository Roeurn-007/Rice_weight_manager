import 'weight_entry.dart';

class WeightGroup {
  final int? id;
  final int harvestId;
  final int groupNumber;
  final DateTime createdAt;
  final List<WeightEntry> entries;

  WeightGroup({
    this.id,
    required this.harvestId,
    required this.groupNumber,
    DateTime? createdAt,
    List<WeightEntry>? entries,
  })  : createdAt = createdAt ?? DateTime.now(),
        entries = entries ?? [];

  /// Calculate subtotal strictly from individual entries
  double get subtotal => entries.fold(0.0, (sum, entry) => sum + entry.weight);

  int get entryCount => entries.length;

  bool get isFull => entries.length >= 5;

  WeightGroup copyWith({
    int? id,
    int? harvestId,
    int? groupNumber,
    DateTime? createdAt,
    List<WeightEntry>? entries,
  }) {
    return WeightGroup(
      id: id ?? this.id,
      harvestId: harvestId ?? this.harvestId,
      groupNumber: groupNumber ?? this.groupNumber,
      createdAt: createdAt ?? this.createdAt,
      entries: entries ?? this.entries,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'harvest_id': harvestId,
      'group_number': groupNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WeightGroup.fromMap(Map<String, dynamic> map, {List<WeightEntry>? entries}) {
    return WeightGroup(
      id: map['id'] as int?,
      harvestId: map['harvest_id'] as int,
      groupNumber: map['group_number'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      entries: entries ?? [],
    );
  }
}
