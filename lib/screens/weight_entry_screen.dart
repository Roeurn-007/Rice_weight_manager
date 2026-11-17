import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/harvest.dart';
import '../models/weight_entry.dart';
import '../models/weight_group.dart';
import '../services/app_settings_service.dart';
import '../services/database_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/weight_group_card.dart';
import 'harvest_detail_screen.dart';
import 'harvest_form_screen.dart';

class WeightEntryScreen extends StatefulWidget {
  final int harvestId;

  const WeightEntryScreen({super.key, required this.harvestId});

  @override
  State<WeightEntryScreen> createState() => _WeightEntryScreenState();
}

class _WeightEntryScreenState extends State<WeightEntryScreen> {
  final _weightInputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  final _scrollController = ScrollController();

  Harvest? _harvest;
  List<WeightGroup> _groups = [];
  final Set<int> _collapsedGroupIds = {};
  List<double> _quickWeightChips = [50.0, 51.0, 52.0, 49.0, 48.0];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData(showLoading: true);
  }

  @override
  void dispose() {
    _weightInputController.dispose();
    _inputFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isGroupCollapsed(WeightGroup group) {
    if (group.id == null) return false;
    return _collapsedGroupIds.contains(group.id);
  }

  void _toggleGroupCollapse(WeightGroup group) {
    if (group.id == null) return;
    setState(() {
      if (_collapsedGroupIds.contains(group.id)) {
        _collapsedGroupIds.remove(group.id);
      } else {
        _collapsedGroupIds.add(group.id!);
      }
    });
  }

  bool get _allGroupsCollapsed {
    if (_groups.isEmpty) return false;
    return _groups.every((g) => g.id != null && _collapsedGroupIds.contains(g.id));
  }

  void _toggleCollapseAll() {
    setState(() {
      if (_allGroupsCollapsed) {
        _collapsedGroupIds.clear();
      } else {
        for (var g in _groups) {
          if (g.id != null) _collapsedGroupIds.add(g.id!);
        }
      }
    });
  }

  /// Never show full-screen loader on incremental updates so keyboard remains smooth
  Future<void> _loadData({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    try {
      final harvest = await DatabaseService.instance.getHarvest(widget.harvestId);
      final groups = await DatabaseService.instance.getGroupsWithEntries(widget.harvestId);
      final frequent = await DatabaseService.instance.getFrequentWeights(harvestId: widget.harvestId);

      if (mounted) {
        setState(() {
          _harvest = harvest;
          _groups = groups;
          if (frequent.isNotEmpty) {
            _quickWeightChips = frequent;
          }
          _isLoading = false;
          if (AppSettingsService.instance.autoCollapseGroups) {
            for (var g in groups) {
              if (g.id != null && g.isFull) {
                _collapsedGroupIds.add(g.id!);
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Calculates overall weight purely from individual entries
  /// to strictly avoid double-counting group subtotals.
  double get _overallWeight {
    double total = 0.0;
    for (var group in _groups) {
      for (var entry in group.entries) {
        total += entry.weight;
      }
    }
    return total;
  }

  int get _totalEntriesCount {
    int count = 0;
    for (var group in _groups) {
      count += group.entries.length;
    }
    return count;
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  Future<void> _addWeight() async {
    final text = _weightInputController.text.trim();
    if (text.isEmpty) return;

    final cleanText = text.replaceAll(',', '.');
    final weight = double.tryParse(cleanText);
    final settings = AppSettingsService.instance;
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(settings.tr('valid_weight_error')),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    // Clear input immediately for zero-lag smooth typing
    _weightInputController.clear();
    HapticFeedback.lightImpact();

    try {
      await DatabaseService.instance.addWeightEntry(widget.harvestId, weight);
      if (!_quickWeightChips.contains(weight)) {
        setState(() {
          _quickWeightChips.insert(0, weight);
          if (_quickWeightChips.length > 7) {
            _quickWeightChips.removeLast();
          }
        });
      }
      // Reload data quietly without showing full-screen progress (keeps keyboard smooth)
      await _loadData(showLoading: false);

      // Smooth micro-scroll to bottom to reveal newly added sack
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      // No popup message shown on add for fast uninterrupted data entry
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding weight: $e')),
        );
      }
    }
  }

  Future<void> _quickAddWeight(double weight) async {
    HapticFeedback.lightImpact();

    try {
      await DatabaseService.instance.addWeightEntry(widget.harvestId, weight);
      if (!_quickWeightChips.contains(weight)) {
        setState(() {
          _quickWeightChips.insert(0, weight);
          if (_quickWeightChips.length > 7) {
            _quickWeightChips.removeLast();
          }
        });
      }
      await _loadData(showLoading: false);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      // No popup message shown on quick add for fast uninterrupted data entry
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding weight: $e')),
        );
      }
    }
  }

  /// Clearly titled and formatted Edit Dialog showing exact sack # and group #
  Future<void> _showEditDialog(WeightEntry entry, int groupNumber, int sackIndex) async {
    final settings = AppSettingsService.instance;
    final controller = TextEditingController(text: _formatNumber(entry.weight));
    // Auto-select text so typing immediately replaces without manual backspacing
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.green.shade900.withValues(alpha: 0.35)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.scale,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF81C784)
                    : const Color(0xFF1B5E20),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${settings.tr('edit_sack')}$sackIndex',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${settings.tr('group')} $groupNumber · ${settings.tr('current_colon')}${_formatNumber(entry.weight)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: settings.tr('weight_kg_label'),
                  suffixText: 'kg',
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    onPressed: () => controller.clear(),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF282828) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                      width: 2,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return settings.tr('enter_weight_error');
                  final val = double.tryParse(v.trim().replaceAll(',', '.'));
                  if (val == null || val <= 0) return settings.tr('enter_positive_error');
                  return null;
                },
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(settings.tr('delete')),
                style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
                onPressed: () async {
                  final confirmed = await _showDeleteConfirmDialog(
                    entry,
                    groupNumber,
                    sackIndex,
                    executeDelete: false,
                  );
                  if (confirmed == true && ctx.mounted) {
                    Navigator.pop(ctx, 'delete');
                  }
                },
              ),
              const Spacer(),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.grey.shade700,
                ),
                onPressed: () => Navigator.pop(ctx, 'cancel'),
                child: Text(settings.tr('cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, 'save');
                  }
                },
                child: Text(settings.tr('save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );

    if (result == 'save' && mounted) {
      final newWeight = double.parse(controller.text.trim().replaceAll(',', '.'));
      await DatabaseService.instance.updateWeightEntry(
        entry.id!,
        newWeight,
        widget.harvestId,
      );
      await _loadData(showLoading: false);
    } else if (result == 'delete' && mounted) {
      await DatabaseService.instance.deleteWeightEntry(
        entry.id!,
        entry.groupId,
        widget.harvestId,
      );
      await _loadData(showLoading: false);
    }
  }

  Future<bool?> _showDeleteConfirmDialog(
    WeightEntry entry,
    int groupNumber,
    int sackIndex, {
    bool executeDelete = true,
  }) async {
    final settings = AppSettingsService.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(settings.tr('delete_sack_title')),
        content: Text(
          '${settings.tr('delete_sack_confirm')}$sackIndex${settings.tr('from_group')}$groupNumber (${_formatNumber(entry.weight)} kg)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(settings.tr('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && executeDelete && mounted) {
      await DatabaseService.instance.deleteWeightEntry(
        entry.id!,
        entry.groupId,
        widget.harvestId,
      );
      await _loadData(showLoading: false);
    }

    return confirmed;
  }

  /// Delete entire weight group and all its sacks at once
  Future<void> _showDeleteGroupDialog(WeightGroup group) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = AppSettingsService.instance;
    final totalSacks = group.entryCount;
    final subtotalStr = settings.weightUnit == 't'
        ? '${(group.subtotal / 1000.0).toStringAsFixed(3)} t'
        : '${_formatNumber(group.subtotal)} kg';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: isDark ? 0.25 : 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${settings.tr('delete_group_title')} ${group.groupNumber}?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${settings.tr('delete_group_confirm_prefix')}${group.groupNumber}${settings.tr('delete_group_confirm_suffix')}',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242424) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ${settings.tr('total_sacks')}: $totalSacks',
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '• ${settings.tr('subtotal')}: $subtotalStr',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              settings.tr('cancel'),
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              settings.tr('delete'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && group.id != null) {
      _collapsedGroupIds.remove(group.id);
      await DatabaseService.instance.deleteWeightGroup(group.id!, widget.harvestId);
      await _loadData(showLoading: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B5E20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            content: Text(
              '${settings.tr('group')} ${group.groupNumber} ${settings.tr('deleted_successfully')}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Confirmation dialog so it is not easy to accidentally click Finish & Calculate
  Future<void> _confirmFinishAndCalculate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = AppSettingsService.instance;
    final isTon = settings.weightUnit == 't';

    if (_totalEntriesCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(settings.tr('at_least_one_weight_error'))),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: isDark ? const Color(0xFF81C784) : Colors.green.shade800,
            ),
            const SizedBox(width: 8),
            Text(
              settings.tr('finish_dialog_title'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${settings.tr('harvest_colon')}${_harvest?.name ?? ""}',
              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              '• ${settings.tr('total_weight_title')}: ${isTon ? '${(_overallWeight / 1000.0).toStringAsFixed(3)} t (${_formatNumber(_overallWeight)} kg)' : '${_formatNumber(_overallWeight)} kg'}',
              style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87),
            ),
            Text(
              '• ${settings.tr('total_sacks')}: $_totalEntriesCount',
              style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87),
            ),
            Text(
              '• ${settings.tr('groups')}: ${_groups.length}',
              style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              settings.tr('finish_dialog_desc'),
              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(settings.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              settings.tr('confirm_finish'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DatabaseService.instance.updateHarvestStatus(widget.harvestId, 'completed');
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HarvestDetailScreen(harvestId: widget.harvestId),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null || _harvest == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Harvest record not found'),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => _loadData(showLoading: true), child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final harvest = _harvest!;
    final settings = AppSettingsService.instance;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isTon = settings.weightUnit == 't';

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            titleSpacing: 16,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              harvest.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF1B5E20),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // Direct Collapse / Expand All toggle icon button nearly Finish & Calculate
              IconButton(
                icon: Icon(
                  _allGroupsCollapsed ? Icons.unfold_more : Icons.unfold_less,
                  size: 20,
                  color: isDark ? Colors.grey.shade300 : const Color(0xFF1B5E20),
                ),
                tooltip: _allGroupsCollapsed ? settings.tr('expand_all') : settings.tr('collapse_all'),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: _toggleCollapseAll,
              ),
              FilledButton.icon(
                onPressed: _confirmFinishAndCalculate,
                icon: const Icon(Icons.check_circle, size: 15, color: Colors.white),
                label: Text(
                  settings.tr('finish_and_calculate'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  elevation: 1.5,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(width: 2),
              SizedBox(
                width: 32,
                height: 32,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (value) async {
                  if (value == 'edit') {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HarvestFormScreen(harvest: harvest)),
                    );
                    if (result == 'deleted' && context.mounted) {
                      Navigator.pop(context);
                    } else {
                      _loadData(showLoading: false);
                    }
                  } else if (value == 'summary') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HarvestDetailScreen(harvestId: widget.harvestId)),
                    );
                  } else if (value == 'toggle_unit') {
                    final next = isTon ? 'kg' : 't';
                    await settings.setWeightUnit(next);
                  } else if (value == 'toggle_collapse') {
                    _toggleCollapseAll();
                  } else if (value == 'toggle_auto_collapse') {
                    final next = !settings.autoCollapseGroups;
                    await settings.setAutoCollapseGroups(next);
                    if (next) {
                      setState(() {
                        for (var g in _groups) {
                          if (g.id != null && g.isFull) {
                            _collapsedGroupIds.add(g.id!);
                          }
                        }
                      });
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'toggle_collapse',
                    child: Row(
                      children: [
                        Icon(_allGroupsCollapsed ? Icons.unfold_more : Icons.unfold_less, size: 18),
                        const SizedBox(width: 8),
                        Text(_allGroupsCollapsed ? settings.tr('expand_all') : settings.tr('collapse_all')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_auto_collapse',
                    child: Row(
                      children: [
                        Icon(
                          settings.autoCollapseGroups ? Icons.check_box : Icons.check_box_outline_blank,
                          size: 18,
                          color: settings.autoCollapseGroups
                              ? (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20))
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            settings.tr('auto_collapse_full'),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'toggle_unit',
                    child: Row(
                      children: [
                        Icon(isTon ? Icons.scale : Icons.local_shipping_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(isTon ? settings.tr('switch_to_kg') : settings.tr('switch_to_ton')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(settings.tr('edit_harvest_info')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'summary',
                    child: Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(settings.tr('view_price_summary')),
                      ],
                    ),
                  ),
                ],
              ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
            children: [
              // Live Summary Banner at Top (Compact & Interactive Unit Toggle)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
                child: InkWell(
                  onTap: () {
                    final next = isTon ? 'kg' : 't';
                    settings.setWeightUnit(next);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: SummaryCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    items: [
                      StatItem(
                        label: isTon ? settings.tr('total_tons') : settings.tr('total_weight_title'),
                        value: isTon
                            ? '${(_overallWeight / 1000.0).toStringAsFixed(3)} t'
                            : '${_formatNumber(_overallWeight)} kg',
                        icon: isTon ? Icons.local_shipping_outlined : Icons.scale,
                        color: const Color(0xFF1B5E20),
                      ),
                      StatItem(
                        label: settings.tr('total_sacks'),
                        value: '$_totalEntriesCount',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.blue.shade800,
                      ),
                      StatItem(
                        label: settings.tr('groups'),
                        value: '${_groups.length}',
                        icon: Icons.grid_view_outlined,
                        color: Colors.teal.shade800,
                      ),
                    ],
                  ),
                ),
              ),

          // Scrollable Groups List (Compact)
          Expanded(
            child: _groups.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.scale,
                            size: 48,
                            color: isDark ? const Color(0xFF81C784) : Colors.green.shade200,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            settings.tr('no_weights_yet'),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            settings.tr('enter_weights_hint_desc'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _groups.length,
                    itemBuilder: (context, index) {
                      final group = _groups[index];
                      return WeightGroupCard(
                        group: group,
                        isCollapsed: _isGroupCollapsed(group),
                        onToggleCollapse: () => _toggleGroupCollapse(group),
                        onDeleteGroup: _showDeleteGroupDialog,
                        onEditEntry: _showEditDialog,
                        onDeleteEntry: _showDeleteConfirmDialog,
                      );
                    },
                  ),
          ),

          // Quick Weight Entry Bar at Bottom
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                  offset: const Offset(0, -2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Quick Weight Chips (Dynamic from history, smaller size)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _quickWeightChips.map((w) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildQuickChip(w, isDark),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Row 2: Custom Text Field & Add Button
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _weightInputController,
                          focusNode: _inputFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.done,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          onSubmitted: (_) => _addWeight(),
                          decoration: InputDecoration(
                            hintText: settings.tr('enter_sack_weight_hint'),
                            hintStyle: TextStyle(
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                              fontSize: 13,
                            ),
                            suffixText: 'kg',
                            suffixStyle: TextStyle(
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                            prefixIcon: Icon(
                              Icons.add_circle_outline,
                              color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: isDark ? const Color(0xFF282828) : Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey.shade700 : Colors.green.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                                width: 1.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addWeight,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          settings.tr('add_btn'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
        );
      },
    );
  }

  Widget _buildQuickChip(double weight, bool isDark) {
    final label = '+${_formatNumber(weight)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _quickAddWeight(weight),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282828) : Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF388E3C) : Colors.green.shade300,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
            ),
          ),
        ),
      ),
    );
  }
}
