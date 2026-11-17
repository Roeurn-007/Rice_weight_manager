import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/harvest.dart';
import '../models/weight_entry.dart';
import '../models/weight_group.dart';
import '../services/app_settings_service.dart';
import '../services/database_service.dart';
import '../utils/formatters.dart';
import '../widgets/summary_card.dart';
import '../widgets/weight_group_card.dart';
import 'harvest_form_screen.dart';
import 'weight_entry_screen.dart';

enum PriceMode { perKg, perTon }
enum CurrencyMode { riel, dollar }

class HarvestDetailScreen extends StatefulWidget {
  final int harvestId;

  const HarvestDetailScreen({super.key, required this.harvestId});

  @override
  State<HarvestDetailScreen> createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen> {
  final _priceController = TextEditingController();
  final _moneyFormat = NumberFormat('#,##0');
  final _dollarFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('EEEE, MMM dd, yyyy');

  Harvest? _harvest;
  List<WeightGroup> _groups = [];
  final Set<int> _collapsedGroupIds = {};
  bool _isLoading = true;
  PriceMode _priceMode = PriceMode.perKg;
  CurrencyMode _currencyMode = CurrencyMode.riel;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _priceController.dispose();
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final harvest = await DatabaseService.instance.getHarvest(widget.harvestId);
    final groups = await DatabaseService.instance.getGroupsWithEntries(widget.harvestId);

    if (mounted) {
      setState(() {
        _harvest = harvest;
        _groups = groups;
        _isLoading = false;
        _currencyMode = (harvest?.currency == 'USD') ? CurrencyMode.dollar : CurrencyMode.riel;

        if (AppSettingsService.instance.autoCollapseGroups) {
          for (var g in groups) {
            if (g.id != null && g.isFull) {
              _collapsedGroupIds.add(g.id!);
            }
          }
        }

        if (AppSettingsService.instance.weightUnit == 't') {
          _priceMode = PriceMode.perTon;
        }

        // Initialize price controller
        if (harvest?.pricePerKg != null) {
          if (_priceMode == PriceMode.perKg) {
            _priceController.text = _formatNumber(harvest!.pricePerKg!);
          } else {
            _priceController.text = _formatNumber(harvest!.pricePerKg! * 1000);
          }
        }
      });
    }
  }

  double get _overallWeight {
    double total = 0.0;
    for (var group in _groups) {
      for (var entry in group.entries) {
        total += entry.weight;
      }
    }
    return total;
  }

  double get _overallWeightTons => _overallWeight / 1000.0;

  int get _totalEntriesCount {
    int count = 0;
    for (var group in _groups) {
      count += group.entries.length;
    }
    return count;
  }

  double? _parsePriceText(String input) {
    String text = input.trim();
    if (text.isEmpty) return null;
    if (RegExp(r'^\d{1,3}(,\d{3})+(\.\d+)?$').hasMatch(text)) {
      text = text.replaceAll(',', '');
    } else {
      text = text.replaceAll(',', '.');
    }
    return double.tryParse(text);
  }

  double? get _currentPricePerKg {
    final val = _parsePriceText(_priceController.text);
    if (val == null || val <= 0) return null;

    if (_priceMode == PriceMode.perKg) {
      return val;
    } else {
      // 1 ton = 1,000 kg => price_per_kg = price_per_ton / 1,000
      return val / 1000.0;
    }
  }

  double? get _estimatedTotalValue {
    final pricePerKg = _currentPricePerKg;
    if (pricePerKg == null) return null;
    return _overallWeight * pricePerKg;
  }

  String _formatNumber(double val) {
    if (val == val.roundToDouble()) {
      return _moneyFormat.format(val.toInt());
    }
    final intPart = val.toInt();
    final decPart = (val - intPart).abs();
    final decStr = decPart.toStringAsFixed(3).substring(2);
    final cleanDec = decStr.endsWith('0') ? decPart.toStringAsFixed(2).substring(2) : decStr;
    return '${_moneyFormat.format(intPart)}.$cleanDec';
  }

  String _formatDollarUnit(double val, {bool isTon = false}) {
    if (isTon || val >= 10) {
      return '\$${_dollarFormat.format(val)}';
    }
    final fixed3 = val.toStringAsFixed(3);
    if (fixed3.endsWith('0')) {
      return '\$${_dollarFormat.format(val)}';
    }
    return '\$${NumberFormat('#,##0.000').format(val)}';
  }

  Future<void> _onPriceChanged(String value) async {
    final pricePerKg = _currentPricePerKg;
    // Persist selling price and currency without modifying weights
    await DatabaseService.instance.updateHarvestPrice(
      widget.harvestId,
      pricePerKg,
      currency: _currencyMode == CurrencyMode.dollar ? 'USD' : 'KHR',
    );
    setState(() {});
  }

  void _switchPriceMode(PriceMode mode) {
    if (_priceMode == mode) return;

    final currentPerKg = _currentPricePerKg;
    setState(() {
      _priceMode = mode;
      if (currentPerKg != null) {
        if (mode == PriceMode.perKg) {
          _priceController.text = _formatNumber(currentPerKg);
        } else {
          _priceController.text = _formatNumber(currentPerKg * 1000.0);
        }
      }
    });
  }

  Future<void> _switchCurrencyMode(CurrencyMode mode) async {
    if (_currencyMode == mode) return;

    setState(() {
      _currencyMode = mode;
    });

    final pricePerKg = _currentPricePerKg;
    await DatabaseService.instance.updateHarvestPrice(
      widget.harvestId,
      pricePerKg,
      currency: mode == CurrencyMode.dollar ? 'USD' : 'KHR',
    );

    if (_priceController.text.isNotEmpty) {
      _priceController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _priceController.text.length,
      );
    }
  }

  Future<void> _showEditDialog(WeightEntry entry, int groupNumber, int sackIndex) async {
    final controller = TextEditingController(text: _formatNumber(entry.weight));
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    final formKey = GlobalKey<FormState>();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settings = AppSettingsService.instance;

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.scale,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
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
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    '${settings.tr('group')} $groupNumber · ${settings.tr('current_colon')}${_formatNumber(entry.weight)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
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
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  labelText: settings.tr('weight_kg_label'),
                  suffixText: 'kg',
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    onPressed: () => controller.clear(),
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF282828) : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
                  foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700,
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
      await _loadData();
    } else if (result == 'delete' && mounted) {
      await DatabaseService.instance.deleteWeightEntry(
        entry.id!,
        entry.groupId,
        widget.harvestId,
      );
      await _loadData();
    }
  }

  Future<bool?> _showDeleteConfirmDialog(
    WeightEntry entry,
    int groupNumber,
    int sackIndex, {
    bool executeDelete = true,
  }) async {
    final settings = AppSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.red.shade900.withValues(alpha: 0.35) : Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline,
                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                settings.tr('delete_sack_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '${settings.tr('delete_sack_confirm')}$sackIndex${settings.tr('from_group')}$groupNumber (${_formatNumber(entry.weight)} kg)?',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
            fontSize: 14,
          ),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

    if (confirmed == true && executeDelete && mounted) {
      await DatabaseService.instance.deleteWeightEntry(
        entry.id!,
        entry.groupId,
        widget.harvestId,
      );
      await _loadData();
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
      await _loadData();
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

  Future<void> _toggleStatus() async {
    final settings = AppSettingsService.instance;
    final newStatus = _harvest!.isCompleted ? 'in_progress' : 'completed';
    await DatabaseService.instance.updateHarvestStatus(widget.harvestId, newStatus);
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B5E20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: Text(
            newStatus == 'completed'
                ? settings.tr('marked_completed')
                : settings.tr('reopened_in_progress'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildCompactCurrencyTab({
    required CurrencyMode currency,
    required String symbol,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _switchCurrencyMode(currency),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              symbol,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20)),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitTab({
    required PriceMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () => _switchPriceMode(mode),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildReceiptText() {
    final harvest = _harvest;
    if (harvest == null) return '';
    final settings = AppSettingsService.instance;
    final isKm = settings.isKhmer;
    final dateStr = DateFormat('dd/MM/yyyy').format(harvest.harvestDate);
    final totalKg = _overallWeight;
    final totalTons = _overallWeightTons;
    final totalSacks = _totalEntriesCount;
    final groupsCount = _groups.length;
    final pricePerKg = _currentPricePerKg;
    final totalVal = _estimatedTotalValue;
    const divider = '------------------------';

    final buffer = StringBuffer();
    buffer.writeln(isKm ? '🌾 បង្កាន់ដៃថ្លឹងស្រូវ' : '🌾 RICE HARVEST RECEIPT');
    buffer.writeln(divider);
    buffer.writeln('${isKm ? 'កាលបរិច្ឆេទ' : 'Date'}: $dateStr');
    buffer.writeln('${isKm ? 'ការច្រូតកាត់' : 'Harvest'}: ${harvest.name}');
    if (harvest.riceFieldCount != null) {
      buffer.writeln('${isKm ? 'ទំហំដី' : 'Land Area'}: ${harvest.formattedFieldCount} ${settings.tr('fields_suffix')}');
    }
    if (harvest.notes != null && harvest.notes!.trim().isNotEmpty) {
      buffer.writeln('${isKm ? 'ចំណាំ' : 'Notes'}: ${harvest.notes!.trim()}');
    }
    buffer.writeln(divider);
    buffer.writeln('${isKm ? 'ចំនួនបាវសរុប' : 'Total Sacks'}: $totalSacks ${settings.tr('sack')} ($groupsCount ${settings.tr('groups')})');
    buffer.writeln('${isKm ? 'ទម្ងន់សរុប' : 'Total Weight'}: ${_formatNumber(totalKg)} kg (${totalTons.toStringAsFixed(3)} ${settings.tr('metric_tons')})');

    if (pricePerKg != null) {
      final priceStr = _currencyMode == CurrencyMode.riel
          ? '${_moneyFormat.format(pricePerKg.round())} ៛/kg (${_moneyFormat.format((pricePerKg * 1000).round())} ៛/តោន)'
          : '${_formatDollarUnit(pricePerKg)}/kg (${_formatDollarUnit(pricePerKg * 1000, isTon: true)}/ton)';
      buffer.writeln('${isKm ? 'តម្លៃលក់' : 'Price'}: $priceStr');
    }

    if (totalVal != null) {
      final valStr = _currencyMode == CurrencyMode.riel
          ? '${_moneyFormat.format(totalVal.round())} ៛'
          : '\$${_dollarFormat.format(totalVal)}';
      buffer.writeln('${isKm ? 'ទឹកប្រាក់សរុប' : 'Total Value'}: $valStr');
    }

    if (_groups.isNotEmpty) {
      buffer.writeln(divider);
      buffer.writeln('${isKm ? '📋 បញ្ជីទម្ងន់តាមក្រុម' : '📋 Breakdown by Group'}:');
      for (var group in _groups) {
        final weights = group.entries.map((e) => _formatNumber(e.weight)).join(', ');
        final groupTotal = group.entries.fold<double>(0.0, (sum, e) => sum + e.weight);
        buffer.writeln('• ${settings.tr('group')} ${group.groupNumber}: $weights = ${_formatNumber(groupTotal)} kg');
      }
    }

    buffer.writeln(divider);
    buffer.writeln(settings.tr('recorded_via'));
    return buffer.toString();
  }

  void _showShareReceiptDialog() {
    final settings = AppSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final receiptText = _buildReceiptText();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.receipt_long,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                settings.tr('receipt_title'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141414) : const Color(0xFFF9FBF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.green.shade900 : Colors.green.shade200,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      receiptText,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.45,
                        color: isDark ? Colors.green.shade100 : const Color(0xFF1B3B1B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: Text(
                    settings.tr('copy_receipt'),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: receiptText));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF1B5E20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                settings.tr('receipt_copied'),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                  label: Text(
                    settings.tr('share_receipt'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await settings.shareText(
                      receiptText,
                      subject: '${_harvest?.name ?? 'Rice'} - ${settings.tr('receipt_title')}',
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_harvest == null) {
      return Scaffold(
        appBar: AppBar(title: Text(settings.tr('not_found'))),
        body: Center(child: Text(settings.tr('harvest_not_found'))),
      );
    }

    final harvest = _harvest!;
    final estimatedValue = _estimatedTotalValue;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isTon = settings.weightUnit == 't';

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text(
              settings.tr('harvest_summary_title'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1B5E20),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: isDark ? Colors.white : const Color(0xFF1B5E20),
                ),
                tooltip: settings.tr('share_receipt'),
                onPressed: _showShareReceiptDialog,
              ),
              IconButton(
                icon: Icon(
                  isTon ? Icons.scale : Icons.local_shipping_outlined,
                  color: isDark ? Colors.white : const Color(0xFF1B5E20),
                ),
                tooltip: isTon ? settings.tr('switch_to_kg') : settings.tr('switch_to_ton'),
                onPressed: () {
                  final next = isTon ? 'kg' : 't';
                  settings.setWeightUnit(next);
                  setState(() {
                    if (next == 't') {
                      _switchPriceMode(PriceMode.perTon);
                    } else {
                      _switchPriceMode(PriceMode.perKg);
                    }
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.edit_note_outlined,
                  color: isDark ? Colors.white : const Color(0xFF1B5E20),
                ),
                tooltip: settings.tr('edit_harvest_info'),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HarvestFormScreen(harvest: harvest),
                    ),
                  );
                  if (result == 'deleted' && context.mounted) {
                    Navigator.pop(context);
                  } else {
                    _loadData();
                  }
                },
              ),
              IconButton(
                icon: Icon(
                  harvest.isCompleted ? Icons.lock_open_outlined : Icons.check_circle_outline,
                  color: isDark ? Colors.white : const Color(0xFF1B5E20),
                ),
                tooltip: harvest.isCompleted ? settings.tr('reopen_harvest') : settings.tr('mark_completed'),
                onPressed: _toggleStatus,
              ),
            ],
          ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Harvest Info Banner Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.green.shade800 : Colors.green.shade200,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          harvest.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: harvest.isCompleted
                              ? (isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50)
                              : (isDark ? Colors.amber.shade900.withValues(alpha: 0.35) : Colors.amber.shade50),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: harvest.isCompleted
                                ? (isDark ? Colors.green.shade700 : Colors.green.shade400)
                                : (isDark ? Colors.amber.shade700 : Colors.amber.shade400),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              harvest.isCompleted ? Icons.check_circle : Icons.timelapse,
                              size: 13,
                              color: harvest.isCompleted
                                  ? (isDark ? Colors.green.shade300 : Colors.green.shade800)
                                  : (isDark ? Colors.amber.shade300 : Colors.amber.shade900),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              harvest.isCompleted ? settings.tr('completed') : settings.tr('in_progress'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: harvest.isCompleted
                                    ? (isDark ? Colors.green.shade200 : Colors.green.shade800)
                                    : (isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.calendar_month, size: 15, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        _dateFormat.format(harvest.harvestDate),
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      ),
                      if (harvest.riceFieldCount != null) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.landscape_outlined, size: 15, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          '${harvest.formattedFieldCount} ${settings.tr('fields_suffix')}',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                  if (harvest.notes != null && harvest.notes!.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF282828) : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notes, size: 15, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              harvest.notes!,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Overall Summary Card (Section 6 & 8)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SummaryCard(
                items: [
                  StatItem(
                    label: isTon ? settings.tr('total_tons') : settings.tr('overall_total'),
                    value: isTon
                        ? '${_overallWeightTons.toStringAsFixed(3)} t'
                        : '${_formatNumber(_overallWeight)} kg',
                    icon: isTon ? Icons.local_shipping_outlined : Icons.scale,
                    color: const Color(0xFF1B5E20),
                  ),
                  StatItem(
                    label: isTon ? settings.tr('kilograms') : settings.tr('metric_tons'),
                    value: isTon
                        ? '${_formatNumber(_overallWeight)} kg'
                        : '${_overallWeightTons.toStringAsFixed(3)} t',
                    icon: isTon ? Icons.scale : Icons.local_shipping_outlined,
                    color: Colors.indigo.shade800,
                  ),
                  StatItem(
                    label: settings.tr('total_sacks'),
                    value: '$_totalEntriesCount',
                    icon: Icons.inventory_2_outlined,
                    color: Colors.teal.shade800,
                  ),
                  StatItem(
                    label: settings.tr('groups'),
                    value: '${_groups.length}',
                    icon: Icons.grid_view,
                    color: Colors.blueGrey.shade800,
                  ),
                ],
              ),
            ),

            // Selling Price Calculator Card (Section 7)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.green.shade800 : Colors.green.shade300,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green.shade900.withValues(alpha: 0.35) : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.monetization_on_outlined,
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        settings.tr('selling_calculator_title'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1B5E20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Currency Selection: Compact pills
                  Row(
                    children: [
                      Text(
                        settings.tr('currency_label'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF282828) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.all(2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildCompactCurrencyTab(
                              currency: CurrencyMode.riel,
                              symbol: '៛',
                              label: settings.tr('riel'),
                              isSelected: _currencyMode == CurrencyMode.riel,
                              isDark: isDark,
                            ),
                            _buildCompactCurrencyTab(
                              currency: CurrencyMode.dollar,
                              symbol: '\$',
                              label: settings.tr('dollar'),
                              isSelected: _currencyMode == CurrencyMode.dollar,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Pricing Unit: Clean 2-tab bar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF282828) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildUnitTab(
                            mode: PriceMode.perKg,
                            label: settings.tr('price_per_kg'),
                            icon: Icons.scale_outlined,
                            isSelected: _priceMode == PriceMode.perKg,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildUnitTab(
                            mode: PriceMode.perTon,
                            label: settings.tr('price_per_ton'),
                            icon: Icons.local_shipping_outlined,
                            isSelected: _priceMode == PriceMode.perTon,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selling Price Input
                  TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      ThousandsSeparatorInputFormatter(allowFraction: _currencyMode == CurrencyMode.dollar),
                    ],
                    onChanged: _onPriceChanged,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: _currencyMode == CurrencyMode.riel
                          ? (_priceMode == PriceMode.perKg
                              ? '${settings.tr('selling_price_per_kg')} (៛)'
                              : '${settings.tr('selling_price_per_ton')} (៛)')
                          : (_priceMode == PriceMode.perKg
                              ? '${settings.tr('selling_price_per_kg')} (\$)'
                              : '${settings.tr('selling_price_per_ton')} (\$)'),
                      labelStyle: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                      hintText: _currencyMode == CurrencyMode.riel
                          ? (_priceMode == PriceMode.perKg ? 'e.g. 1,200' : 'e.g. 1,200,000')
                          : (_priceMode == PriceMode.perKg ? 'e.g. 0.30' : 'e.g. 300'),
                      hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                      helperText: _priceMode == PriceMode.perTon ? settings.tr('ton_helper') : null,
                      helperStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Text(
                          _currencyMode == CurrencyMode.riel ? '៛' : '\$',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                          ),
                        ),
                      ),
                      suffixText: _currencyMode == CurrencyMode.riel
                          ? (_priceMode == PriceMode.perKg ? '៛ / kg' : '៛ / ton')
                          : (_priceMode == PriceMode.perKg ? '\$ / kg' : '\$ / ton'),
                      suffixStyle: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      suffixIcon: _priceController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                              onPressed: () {
                                _priceController.clear();
                                _onPriceChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                          width: 1.8,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF282828) : Colors.grey.shade50,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Estimated Value Result Display
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF162519) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2E5E36) : Colors.green.shade200,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _priceMode == PriceMode.perKg
                                  ? settings.tr('unit_price_per_kg_label')
                                  : settings.tr('unit_price_per_ton_label'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              _currentPricePerKg != null
                                  ? (_currencyMode == CurrencyMode.riel
                                      ? (_priceMode == PriceMode.perKg
                                          ? '${_moneyFormat.format(_currentPricePerKg!.round())} ៛ / kg'
                                          : '${_moneyFormat.format((_currentPricePerKg! * 1000).round())} ៛ / ton')
                                      : (_priceMode == PriceMode.perKg
                                          ? '${_formatDollarUnit(_currentPricePerKg!)} / kg'
                                          : '${_formatDollarUnit(_currentPricePerKg! * 1000, isTon: true)} / ton'))
                                  : settings.tr('not_set'),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (_priceMode == PriceMode.perTon && _currentPricePerKg != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                settings.tr('equivalent_per_kg'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                _currencyMode == CurrencyMode.riel
                                    ? '${_moneyFormat.format(_currentPricePerKg!.round())} ៛ / kg'
                                    : '${_formatDollarUnit(_currentPricePerKg!)} / kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settings.tr('total_weight_label'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                              ),
                            ),
                            Text(
                              isTon
                                  ? '${_overallWeightTons.toStringAsFixed(3)} tons (${_formatNumber(_overallWeight)} kg)'
                                  : '${_formatNumber(_overallWeight)} kg (${_overallWeightTons.toStringAsFixed(3)} tons)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Divider(
                            height: 1,
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              settings.tr('estimated_total_value'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                              ),
                            ),
                            Text(
                              estimatedValue != null
                                  ? (_currencyMode == CurrencyMode.riel
                                      ? '${_moneyFormat.format(estimatedValue.round())} ៛'
                                      : '\$${_dollarFormat.format(estimatedValue)}')
                                  : (_currencyMode == CurrencyMode.riel ? '— ៛' : '— \$'),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Share Receipt Button
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.receipt_long, size: 18, color: Colors.white),
                      label: Text(
                        settings.tr('share_receipt'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      onPressed: _showShareReceiptDialog,
                    ),
                  ),
                ],
              ),
            ),

            // Section Header: Weight Groups & Sacks
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    settings.tr('weight_groups_and_sacks'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_groups.isNotEmpty)
                        IconButton(
                          icon: Icon(
                            _allGroupsCollapsed ? Icons.unfold_more : Icons.unfold_less,
                            size: 20,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                          ),
                          tooltip: _allGroupsCollapsed ? settings.tr('expand_all') : settings.tr('collapse_all'),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          onPressed: _toggleCollapseAll,
                        ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                        ),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(settings.tr('add_edit_sacks')),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WeightEntryScreen(harvestId: widget.harvestId),
                            ),
                          );
                          _loadData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Groups List
            if (_groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    settings.tr('no_weights_recorded_yet'),
                    style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                ),
              )
            else
              ..._groups.map((group) {
                return WeightGroupCard(
                  group: group,
                  isCollapsed: _isGroupCollapsed(group),
                  onToggleCollapse: () => _toggleGroupCollapse(group),
                  onDeleteGroup: _showDeleteGroupDialog,
                  onEditEntry: _showEditDialog,
                  onDeleteEntry: _showDeleteConfirmDialog,
                );
              }),
          ],
        ),
      ),
    ),
    );
      },
    );
  }
}
