import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/harvest.dart';
import '../services/app_settings_service.dart';

class HarvestCard extends StatelessWidget {
  final Harvest harvest;
  final double totalWeight;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const HarvestCard({
    super.key,
    required this.harvest,
    required this.totalWeight,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
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
    final dateFormat = DateFormat('MMM dd, yyyy');
    final formattedDate = dateFormat.format(harvest.harvestDate);
    final isCompleted = harvest.isCompleted;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isDark ? 0 : 0.5,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? (isCompleted ? Colors.green.shade800 : Colors.grey.shade800)
              : (isCompleted ? Colors.green.shade200 : Colors.grey.shade300),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Harvest Name, Status Badge, and Action Icon in line and balanced
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      harvest.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B5E20),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? (isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50)
                          : (isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade50),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCompleted
                            ? (isDark ? Colors.green.shade700 : Colors.green.shade300)
                            : (isDark ? Colors.amber.shade700 : Colors.amber.shade300),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.timelapse,
                          size: 13,
                          color: isCompleted
                              ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                              : (isDark ? Colors.amber.shade300 : Colors.amber.shade800),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted
                              ? AppSettingsService.instance.tr('completed')
                              : AppSettingsService.instance.tr('in_progress'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isCompleted
                                ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
                                : (isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Options',
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text(AppSettingsService.instance.tr('edit_harvest_title')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                AppSettingsService.instance.tr('delete'),
                                style: TextStyle(color: isDark ? Colors.red.shade300 : Colors.red.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date and Fields info
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                  if (harvest.riceFieldCount != null) ...[
                    const SizedBox(width: 14),
                    Icon(
                      Icons.landscape_outlined,
                      size: 14,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${harvest.formattedFieldCount} ${AppSettingsService.instance.tr('fields_suffix')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),

              if (harvest.notes != null && harvest.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  harvest.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
              const SizedBox(height: 10),

              // Bottom Stats Row: Total Weight & Action Prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.scale_outlined,
                        size: 16,
                        color: isDark ? const Color(0xFF81C784) : Colors.green.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppSettingsService.instance.tr('total_weight'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        AppSettingsService.instance.weightUnit == 't'
                            ? '${(totalWeight / 1000.0).toStringAsFixed(3)} t'
                            : '${_formatWeight(totalWeight)} kg',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        isCompleted
                            ? AppSettingsService.instance.tr('view_details')
                            : AppSettingsService.instance.tr('enter_weights'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : (isCompleted ? Colors.green.shade800 : const Color(0xFF2E7D32)),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : (isCompleted ? Colors.green.shade800 : const Color(0xFF2E7D32)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
