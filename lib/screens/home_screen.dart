import 'package:flutter/material.dart';
import '../models/harvest.dart';
import '../services/app_settings_service.dart';
import '../services/database_service.dart';
import '../widgets/harvest_card.dart';
import '../widgets/settings_drawer.dart';
import '../widgets/summary_card.dart';
import 'harvest_detail_screen.dart';
import 'harvest_form_screen.dart';
import 'weight_entry_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  List<Harvest> _harvests = [];
  Map<int, double> _weightsMap = {};
  Map<String, dynamic> _counts = {'total': 0, 'in_progress': 0, 'completed': 0};
  String _statusFilter = 'all'; // 'all', 'in_progress', 'completed'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final counts = await DatabaseService.instance.getDashboardCounts();
      final harvests = await DatabaseService.instance.getAllHarvests(
        searchQuery: _searchController.text,
        statusFilter: _statusFilter,
      );

      // Load total weights for each harvest
      Map<int, double> weights = {};
      for (var h in harvests) {
        if (h.id != null) {
          final w = await DatabaseService.instance.getTotalWeightForHarvest(h.id!);
          weights[h.id!] = w;
        }
      }

      if (mounted) {
        setState(() {
          _counts = counts;
          _harvests = harvests;
          _weightsMap = weights;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading harvests: $e')),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _loadData();
  }

  void _onFilterChanged(String filter) {
    setState(() => _statusFilter = filter);
    _loadData();
  }

  Future<void> _openNewHarvest() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HarvestFormScreen()),
    );
    if (result != null) {
      if (_statusFilter == 'completed') {
        setState(() => _statusFilter = 'all');
      }
      await _loadData();
      if (result is int && mounted) {
        // Automatically open weight entry for newly created harvest
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WeightEntryScreen(harvestId: result),
          ),
        ).then((_) => _loadData());
      }
    }
  }

  Future<void> _editHarvest(Harvest harvest) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HarvestFormScreen(harvest: harvest)),
    );
    if (result != null) {
      _loadData();
    }
  }

  Future<void> _deleteHarvest(Harvest harvest) async {
    final settings = AppSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          settings.tr('delete_harvest_title'),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          '${settings.tr('delete_harvest_confirm')}${harvest.name}${settings.tr('undone_warning')}',
          style: TextStyle(
            color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              settings.tr('cancel'),
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
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

    if (confirmed == true && mounted) {
      await DatabaseService.instance.deleteHarvest(harvest.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF1B5E20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            elevation: 3,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  settings.tr('harvest_deleted'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadData();
      }
    }
  }

  void _openHarvest(Harvest harvest) {
    if (harvest.isCompleted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HarvestDetailScreen(harvestId: harvest.id!),
        ),
      ).then((_) => _loadData());
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WeightEntryScreen(harvestId: harvest.id!),
        ),
      ).then((_) => _loadData());
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: const SettingsDrawer(),
          backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: settings.tr('settings'),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            titleSpacing: 0,
            title: InkWell(
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo (taps to open drawer)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/app_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // App Title
                    Flexible(
                      child: Text(
                        settings.tr('app_title'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : const Color(0xFF1B5E20),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              // Language Flag Switcher (nearly the dark/light mode icon)
              IconButton(
                tooltip: settings.isKhmer ? 'Switch to English' : 'ប្តូរទៅភាសាខ្មែរ',
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () {
                  final next = settings.isKhmer ? 'en' : 'km';
                  settings.setLanguage(next);
                },
                icon: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey.shade800 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade700 : Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    settings.isKhmer ? '🇰🇭' : '🇬🇧',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 2),

              // Dark / Light Mode Switcher
              IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode : Icons.dark_mode_outlined,
                  color: isDark ? Colors.amber : const Color(0xFF1B5E20),
                ),
                tooltip: isDark ? settings.tr('theme_light') : settings.tr('theme_dark'),
                onPressed: () {
                  settings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                },
              ),
              const SizedBox(width: 4),
            ],
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                height: 1,
              ),
            ),
          ),
          body: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            behavior: HitTestBehavior.translucent,
            child: Column(
              children: [
                // Pinned Top Summary Cards (Never scrolls behind AppBar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: SummaryCard(
                    items: [
                      StatItem(
                        label: settings.tr('total_records'),
                        value: '${_counts['total'] ?? 0}',
                        icon: Icons.list_alt,
                        color: const Color(0xFF1B5E20),
                      ),
                      StatItem(
                        label: settings.tr('in_progress'),
                        value: '${_counts['in_progress'] ?? 0}',
                        icon: Icons.timelapse,
                        color: Colors.amber.shade900,
                      ),
                      StatItem(
                        label: settings.tr('completed'),
                        value: '${_counts['completed'] ?? 0}',
                        icon: Icons.check_circle_outline,
                        color: Colors.green.shade800,
                      ),
                    ],
                  ),
                ),

                // Pinned Search Bar (Compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: settings.tr('search_hint'),
                        hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 18),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF242424) : Colors.white,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                          borderSide: BorderSide(color: Color(0xFF1B5E20), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pinned Filter Chips (Compact)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Row(
                    children: [
                      _buildFilterChip(settings.tr('all'), 'all', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip(settings.tr('in_progress'), 'in_progress', isDark),
                      const SizedBox(width: 6),
                      _buildFilterChip(settings.tr('completed'), 'completed', isDark),
                    ],
                  ),
                ),

                const SizedBox(height: 4),

                // Content Area (Scrolls only when records overflow, pull-to-refresh supported)
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          color: const Color(0xFF1B5E20),
                          child: _harvests.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      physics: const AlwaysScrollableScrollPhysics(
                                        parent: ClampingScrollPhysics(),
                                      ),
                                      child: SizedBox(
                                        height: constraints.maxHeight,
                                        child: Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(32),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 64,
                                                  color: Colors.grey.shade300,
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  _searchController.text.isNotEmpty || _statusFilter != 'all'
                                                      ? settings.tr('no_matching')
                                                      : settings.tr('no_harvests'),
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  _searchController.text.isNotEmpty || _statusFilter != 'all'
                                                      ? 'Try clearing the search or changing the filter.'
                                                      : settings.tr('tap_to_start'),
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(color: Colors.grey.shade500),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: ClampingScrollPhysics(),
                                  ),
                                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                                  padding: const EdgeInsets.only(top: 4, bottom: 80),
                                  itemCount: _harvests.length,
                                  itemBuilder: (context, index) {
                                    final harvest = _harvests[index];
                                    final totalWeight = _weightsMap[harvest.id] ?? 0.0;
                                    return HarvestCard(
                                      harvest: harvest,
                                      totalWeight: totalWeight,
                                      onTap: () => _openHarvest(harvest),
                                      onEdit: () => _editHarvest(harvest),
                                      onDelete: () => _deleteHarvest(harvest),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openNewHarvest,
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 3,
            icon: const Icon(Icons.add),
            label: Text(
              settings.tr('new_harvest'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(value),
      showCheckmark: false,
      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      backgroundColor: isDark ? const Color(0xFF242424) : Colors.white,
      selectedColor: isDark ? const Color(0xFF2E7D32).withValues(alpha: 0.3) : const Color(0xFFE8F5E9),
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20))
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
      ),
      side: BorderSide(
        color: isSelected
            ? (isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20))
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        width: isSelected ? 1.2 : 0.8,
      ),
    );
  }
}
