import 'package:flutter/material.dart';
import '../models/weight_entry.dart';
import '../models/weight_group.dart';
import '../services/app_settings_service.dart';
import 'weight_entry_tile.dart';

typedef OnEditEntryCallback = void Function(WeightEntry entry, int groupNumber, int sackIndex);
typedef OnDeleteEntryCallback = void Function(WeightEntry entry, int groupNumber, int sackIndex);
typedef OnDeleteGroupCallback = void Function(WeightGroup group);

class WeightGroupCard extends StatelessWidget {
  final WeightGroup group;
  final OnEditEntryCallback onEditEntry;
  final OnDeleteEntryCallback onDeleteEntry;
  final OnDeleteGroupCallback? onDeleteGroup;
  final bool isEditable;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const WeightGroupCard({
    super.key,
    required this.group,
    required this.onEditEntry,
    required this.onDeleteEntry,
    this.onDeleteGroup,
    this.isEditable = true,
    this.isCollapsed = false,
    this.onToggleCollapse,
  });

  String _formatWeight(double weight) {
    if (weight == weight.roundToDouble()) {
      return weight.toInt().toString();
    }
    return weight.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFull = group.isFull;
    final settings = AppSettingsService.instance;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      elevation: isDark ? 0 : 0.5,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isDark
              ? (isFull ? Colors.green.shade800 : Colors.grey.shade800)
              : (isFull ? Colors.green.shade300 : Colors.grey.shade300),
          width: isFull ? 1.0 : 0.6,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ultra-compact Header Row: Group Number, Entry Count Pill, Delete Group, Subtotal & Collapse Chevron
            Row(
              children: [
                // Group Badge (taps to toggle collapse)
                InkWell(
                  onTap: onToggleCollapse,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E20),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${settings.tr('group')} ${group.groupNumber}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),

                // Count Badge (taps to toggle collapse)
                InkWell(
                  onTap: onToggleCollapse,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isFull
                          ? (isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50)
                          : (isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade50),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isFull
                            ? (isDark ? Colors.green.shade700 : Colors.green.shade300)
                            : (isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                        width: 0.6,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isFull)
                          Icon(Icons.check_circle, size: 10, color: isDark ? Colors.green.shade300 : Colors.green.shade700)
                        else
                          Icon(Icons.pending, size: 10, color: isDark ? Colors.amber.shade300 : Colors.amber.shade800),
                        const SizedBox(width: 2),
                        Text(
                          '${group.entryCount}/5',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isFull
                                ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
                                : (isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Delete Group Icon Button: (Group{}, {}/5, delete icon)
                // Independent touch target that directly triggers onDeleteGroup
                if (isEditable && onDeleteGroup != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => onDeleteGroup!(group),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.22 : 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: isDark ? 0.45 : 0.25),
                          width: 0.6,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_outline,
                        size: 13,
                        color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],

                // Subtotal & Chevron (tap to toggle collapse)
                Expanded(
                  child: InkWell(
                    onTap: onToggleCollapse,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          RichText(
                            text: TextSpan(
                              text: '${settings.tr('subtotal')}: ',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: settings.weightUnit == 't'
                                      ? '${(group.subtotal / 1000.0).toStringAsFixed(3)} t'
                                      : '${_formatWeight(group.subtotal)} kg',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                            size: 18,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Entries List (Only rendered if NOT collapsed)
            if (!isCollapsed) ...[
              const SizedBox(height: 3),
              Divider(
                height: 4,
                thickness: 0.5,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              const SizedBox(height: 1),

              if (group.entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Center(
                    child: Text(
                      settings.tr('no_weights_in_group'),
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                        fontSize: 11,
                      ),
                    ),
                  ),
                )
              else
                ...group.entries.asMap().entries.map((item) {
                  final idx = item.key + 1;
                  final entry = item.value;
                  return WeightEntryTile(
                    index: idx,
                    entry: entry,
                    isEditable: isEditable,
                    onEdit: () => onEditEntry(entry, group.groupNumber, idx),
                    onDelete: () => onDeleteEntry(entry, group.groupNumber, idx),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}
