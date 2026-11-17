import 'package:flutter/material.dart';
import '../services/app_settings_service.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  void _showShareDialog(BuildContext context, AppSettingsService settings, bool isDark) {
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
                color: isDark ? const Color(0xFF1B2E1E) : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.share,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                settings.tr('share_dialog_title'),
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
              settings.tr('share_dialog_q'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF242424) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: Text(
                settings.tr('share_dialog_ans'),
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              settings.tr('close_btn'),
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
              ),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E20),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await settings.shareApp();
            },
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: Text(
              settings.tr('share_now_btn'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsService.instance;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return Drawer(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Column(
            children: [
              // Drawer Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/app_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                settings.tr('app_title'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                settings.tr('app_subtitle'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Settings Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    // Section: Weight Unit Preference (Kg to T)
                    _buildSectionHeader(
                      icon: Icons.scale_outlined,
                      title: settings.tr('weight_unit_title'),
                      subtitle: settings.tr('weight_unit_desc'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildChoiceTab(
                              label: settings.tr('unit_kg'),
                              icon: Icons.fitness_center,
                              isSelected: settings.weightUnit == 'kg',
                              isDark: isDark,
                              onTap: () => settings.setWeightUnit('kg'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildChoiceTab(
                              label: settings.tr('unit_ton'),
                              icon: Icons.local_shipping_outlined,
                              isSelected: settings.weightUnit == 't',
                              isDark: isDark,
                              onTap: () => settings.setWeightUnit('t'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Section: Theme Mode (Light / Dark)
                    _buildSectionHeader(
                      icon: Icons.palette_outlined,
                      title: settings.tr('theme_title'),
                      subtitle: settings.tr('theme_desc'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildChoiceTab(
                              label: settings.tr('theme_light'),
                              icon: Icons.light_mode_outlined,
                              isSelected: settings.themeMode == ThemeMode.light,
                              isDark: isDark,
                              onTap: () => settings.setThemeMode(ThemeMode.light),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildChoiceTab(
                              label: settings.tr('theme_dark'),
                              icon: Icons.dark_mode_outlined,
                              isSelected: settings.themeMode == ThemeMode.dark,
                              isDark: isDark,
                              onTap: () => settings.setThemeMode(ThemeMode.dark),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Section: Language (Khmer Default / English)
                    _buildSectionHeader(
                      icon: Icons.language,
                      title: settings.tr('language_title'),
                      subtitle: settings.tr('language_desc'),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                      ),
                      padding: const EdgeInsets.all(2.5),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildChoiceTab(
                              label: settings.tr('lang_km'),
                              icon: Icons.flag_outlined,
                              isSelected: settings.language == 'km',
                              isDark: isDark,
                              onTap: () => settings.setLanguage('km'),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _buildChoiceTab(
                              label: settings.tr('lang_en'),
                              icon: Icons.public,
                              isSelected: settings.language == 'en',
                              isDark: isDark,
                              onTap: () => settings.setLanguage('en'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Share App Menu Card
                    InkWell(
                      onTap: () => _showShareDialog(context, settings, isDark),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF263238) : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.green.shade800 : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1B5E20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.share, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    settings.tr('share_app'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: isDark ? Colors.green.shade200 : const Color(0xFF1B5E20),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    settings.tr('share_app_sub'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: 14,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Drawer Footer: Version & Developer Credits
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121212) : Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Version Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 14,
                            color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            settings.tr('version_code'),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Developer Credit with clickable website link
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => settings.openUrl('https://roeurn.rest/'),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                settings.tr('built_by'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                                  letterSpacing: 0.2,
                                  decoration: TextDecoration.underline,
                                  decorationColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Icon(
                                Icons.open_in_new,
                                size: 13,
                                color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2E7D32) : const Color(0xFF1B5E20))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
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
              size: 14,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
            ),
            const SizedBox(width: 5),
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
}
