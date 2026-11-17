import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/harvest.dart';
import '../services/app_settings_service.dart';
import '../services/database_service.dart';

class HarvestFormScreen extends StatefulWidget {
  final Harvest? harvest;

  const HarvestFormScreen({super.key, this.harvest});

  @override
  State<HarvestFormScreen> createState() => _HarvestFormScreenState();
}

class _HarvestFormScreenState extends State<HarvestFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _fieldCountController;
  late TextEditingController _notesController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  bool get isEditing => widget.harvest != null;

  @override
  void initState() {
    super.initState();
    final h = widget.harvest;
    _nameController = TextEditingController(text: h?.name ?? '');
    _fieldCountController = TextEditingController(
      text: h?.formattedFieldCount ?? '',
    );
    _notesController = TextEditingController(text: h?.notes ?? '');
    _selectedDate = h?.harvestDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fieldCountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? const ColorScheme.dark(
                    primary: Color(0xFF81C784),
                    onPrimary: Colors.black,
                    surface: Color(0xFF1E1E1E),
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: const Color(0xFF1B5E20),
                    onPrimary: Colors.white,
                    onSurface: Colors.grey.shade900,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showFloatingSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1B5E20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 3,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveHarvest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final fieldText = _fieldCountController.text.trim().replaceAll(',', '.');
      final fieldCount = fieldText.isNotEmpty ? double.tryParse(fieldText) : null;
      final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

      if (isEditing) {
        final updated = widget.harvest!.copyWith(
          name: name,
          harvestDate: _selectedDate,
          riceFieldCount: fieldCount,
          notes: notes,
        );
        await DatabaseService.instance.updateHarvest(updated);
        if (mounted) {
          _showFloatingSnackBar('Harvest updated successfully');
          Navigator.pop(context, true);
        }
      } else {
        final newHarvest = Harvest(
          name: name,
          harvestDate: _selectedDate,
          riceFieldCount: fieldCount,
          notes: notes,
          status: 'in_progress',
        );
        final newId = await DatabaseService.instance.insertHarvest(newHarvest);
        if (mounted) {
          _showFloatingSnackBar('Harvest "$name" created successfully!');
          Navigator.pop(context, newId);
        }
      }
    } catch (e) {
      if (mounted) {
        _showFloatingSnackBar('Error saving harvest: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteHarvest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Harvest Record?'),
        content: Text(
          'Are you sure you want to delete "${widget.harvest!.name}"? All weight groups and entries will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await DatabaseService.instance.deleteHarvest(widget.harvest!.id!);
      if (mounted) {
        _showFloatingSnackBar('Harvest record deleted');
        Navigator.pop(context, 'deleted');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final settings = AppSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fieldFillColor = isDark ? const Color(0xFF242424) : Colors.white;
    final fieldBorderColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;
    final fieldIconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          isEditing ? settings.tr('edit_harvest_title') : settings.tr('new_harvest_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF1B5E20),
          ),
        ),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: settings.tr('delete'),
              onPressed: _deleteHarvest,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Harvest Name
                    TextFormField(
                      controller: _nameController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: settings.tr('harvest_name_label'),
                        hintText: settings.tr('harvest_name_hint'),
                        prefixIcon: Icon(Icons.grass, color: fieldIconColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20), width: 1.5),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return settings.tr('harvest_name_error');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Harvest Date Picker
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(
                          color: fieldFillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: fieldBorderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month, color: fieldIconColor),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settings.tr('harvest_date_label'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateFormat.format(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down, color: isDark ? Colors.grey.shade400 : Colors.grey),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Number of rice fields (optional)
                    TextFormField(
                      controller: _fieldCountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: settings.tr('field_count_label'),
                        hintText: settings.tr('field_count_hint'),
                        prefixIcon: Icon(Icons.landscape, color: fieldIconColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20), width: 1.5),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                      validator: (value) {
                        if (value != null && value.trim().isNotEmpty) {
                          final clean = value.trim().replaceAll(',', '.');
                          final parsed = double.tryParse(clean);
                          if (parsed == null || parsed <= 0) {
                            return settings.tr('field_count_error');
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Notes (optional)
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        labelText: settings.tr('notes_label'),
                        hintText: settings.tr('notes_hint'),
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 48),
                          child: Icon(Icons.note_alt_outlined, color: fieldIconColor),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: fieldBorderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20), width: 1.5),
                        ),
                        filled: true,
                        fillColor: fieldFillColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    FilledButton(
                      onPressed: _saveHarvest,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text(
                        isEditing ? settings.tr('update_harvest_btn') : settings.tr('create_harvest_btn'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
