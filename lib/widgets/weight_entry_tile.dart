import 'package:flutter/material.dart';
import '../models/weight_entry.dart';
import '../services/app_settings_service.dart';

class WeightEntryTile extends StatelessWidget {
  final int index;
  final WeightEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isEditable;

  const WeightEntryTile({
    super.key,
    required this.index,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    this.isEditable = true,
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

    return InkWell(
      onTap: isEditable ? onEdit : null,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        child: Row(
          children: [
            // Ultra-compact Sack number badge
            Container(
              width: 17,
              height: 17,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isDark ? Colors.green.shade700 : Colors.green.shade200,
                  width: 0.5,
                ),
              ),
              child: Text(
                '$index',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.green.shade300 : Colors.green.shade900,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${AppSettingsService.instance.tr('sack')} $index',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${_formatWeight(entry.weight)} kg',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
              ),
            ),
            if (isEditable) ...[
              const SizedBox(width: 8),
              // Compact touch targets without bulky IconButton margins
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(Icons.close, size: 14, color: Colors.red.shade300),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
