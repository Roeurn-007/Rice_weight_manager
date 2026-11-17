import 'package:flutter/material.dart';

class StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class SummaryCard extends StatelessWidget {
  final List<StatItem> items;
  final EdgeInsetsGeometry? padding;

  const SummaryCard({
    super.key,
    required this.items,
    this.padding,
  });

  Color _adaptColor(Color color, bool isDark) {
    if (!isDark) return color;
    if (color == const Color(0xFF1B5E20) ||
        color == Colors.green.shade800 ||
        color == Colors.green.shade900 ||
        color == Colors.green) {
      return const Color(0xFF81C784);
    }
    if (color == Colors.amber.shade900 ||
        color == Colors.amber.shade800 ||
        color == Colors.amber) {
      return Colors.amber.shade300;
    }
    if (color == Colors.teal.shade800 ||
        color == Colors.teal.shade900 ||
        color == Colors.teal) {
      return Colors.teal.shade300;
    }
    if (color == Colors.indigo.shade800 ||
        color == Colors.indigo.shade900 ||
        color == Colors.indigo) {
      return Colors.indigo.shade200;
    }
    if (color == Colors.blueGrey.shade800 ||
        color == Colors.blueGrey.shade900 ||
        color == Colors.blueGrey) {
      return Colors.blueGrey.shade300;
    }
    return color;
  }

  Widget _buildItem(StatItem item, bool isDark) {
    final effectiveColor = _adaptColor(item.color, isDark);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 16, color: effectiveColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          item.value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: effectiveColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? const Color(0xFF2E4632)
        : Colors.green.shade200.withValues(alpha: 0.6);

    return Card(
      elevation: 0,
      color: isDark
          ? const Color(0xFF1B231D)
          : Colors.green.shade50.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF2E4632) : Colors.green.shade100,
        ),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: items.length == 4
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildItem(items[0], isDark)),
                      Container(height: 38, width: 1, color: dividerColor),
                      Expanded(child: _buildItem(items[1], isDark)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, thickness: 0.8, color: dividerColor),
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildItem(items[2], isDark)),
                      Container(height: 38, width: 1, color: dividerColor),
                      Expanded(child: _buildItem(items[3], isDark)),
                    ],
                  ),
                ],
              )
            : Row(
                children: items.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value;
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildItem(item, isDark)),
                        if (idx < items.length - 1)
                          Container(
                            height: 36,
                            width: 1,
                            color: dividerColor,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),
    );
  }
}
