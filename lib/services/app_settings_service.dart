import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_service.dart';

class AppSettingsService extends ChangeNotifier {
  static final AppSettingsService instance = AppSettingsService._init();
  static const MethodChannel _shareChannel = MethodChannel('com.example.rice_weight_manager/share');

  String _weightUnit = 'kg'; // 'kg' or 't'
  ThemeMode _themeMode = ThemeMode.light;
  String _language = 'km'; // 'km' (Khmer - Default) or 'en' (English)
  bool _autoCollapseGroups = false;
  bool _isLoaded = false;

  AppSettingsService._init();

  String get weightUnit => _weightUnit;
  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  bool get isKhmer => _language == 'km';
  bool get autoCollapseGroups => _autoCollapseGroups;
  bool get isLoaded => _isLoaded;

  Future<void> init() async {
    try {
      final unit = await DatabaseService.instance.getSetting('weight_unit');
      if (unit != null) _weightUnit = unit;

      final theme = await DatabaseService.instance.getSetting('theme_mode');
      if (theme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else if (theme == 'light') {
        _themeMode = ThemeMode.light;
      }

      final lang = await DatabaseService.instance.getSetting('language');
      if (lang != null) {
        _language = lang;
      } else {
        _language = 'km'; // Default is Khmer
      }

      final autoCol = await DatabaseService.instance.getSetting('auto_collapse_groups');
      if (autoCol != null) {
        _autoCollapseGroups = autoCol == '1';
      }
    } catch (_) {}
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> setAutoCollapseGroups(bool val) async {
    if (_autoCollapseGroups == val) return;
    _autoCollapseGroups = val;
    notifyListeners();
    await DatabaseService.instance.saveSetting('auto_collapse_groups', val ? '1' : '0');
  }

  Future<void> setWeightUnit(String unit) async {
    if (_weightUnit == unit) return;
    _weightUnit = unit;
    notifyListeners();
    await DatabaseService.instance.saveSetting('weight_unit', unit);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final str = mode == ThemeMode.dark ? 'dark' : 'light';
    await DatabaseService.instance.saveSetting('theme_mode', str);
  }

  Future<void> setLanguage(String lang) async {
    if (_language == lang) return;
    _language = lang;
    notifyListeners();
    await DatabaseService.instance.saveSetting('language', lang);
  }

  Future<bool> shareApp() async {
    try {
      final result = await _shareChannel.invokeMethod<bool>('shareApp');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> shareText(String text, {String? subject}) async {
    try {
      final result = await _shareChannel.invokeMethod<bool>('shareText', {
        'text': text,
        'subject': subject ?? 'Rice Harvest Receipt',
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openUrl(String url) async {
    try {
      final result = await _shareChannel.invokeMethod<bool>('openUrl', {'url': url});
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  // -------------------------------------------------------------
  // Translations dictionary
  // -------------------------------------------------------------
  static final Map<String, Map<String, String>> _strings = {
    'km': {
      'app_title': 'គ្រប់គ្រងទម្ងន់ស្រូវ',
      'app_subtitle': 'កត់ត្រាទម្ងន់ និងគណនាតម្លៃស្រូវ',
      'total_records': 'កំណត់ត្រាសរុប',
      'in_progress': 'កំពុងដំណើរការ',
      'completed': 'បានបញ្ចប់',
      'all': 'ទាំងអស់',
      'search_hint': 'ស្វែងរកការច្រូតកាត់តាមឈ្មោះ...',
      'new_harvest': 'ច្រូតកាត់ថ្មី',
      'total_weight': 'ទម្ងន់សរុប:',
      'view_details': 'មើលព័ត៌មានលម្អិត',
      'enter_weights': 'បញ្ចូលទម្ងន់បាវ',
      'settings': 'ការកំណត់ (Settings)',
      'weight_unit_title': 'ខ្នាតបង្ហាញទម្ងន់សរុប',
      'weight_unit_desc': 'បង្ហាញទម្ងន់សរុបជា គីឡូក្រាម (Kg) ឬ តោន (T)',
      'unit_kg': 'គីឡូក្រាម (Kg)',
      'unit_ton': 'តោន (T)',
      'theme_title': 'រូបរាងកម្មវិធី (Theme)',
      'theme_desc': 'ជ្រើសរើសរបៀបពន្លឺ ឬងងឹត',
      'theme_light': 'ពន្លឺ (Light)',
      'theme_dark': 'ងងឹត (Dark)',
      'language_title': 'ភាសា (Language)',
      'language_desc': 'ជ្រើសរើសភាសាសម្រាប់កម្មវិធី',
      'lang_km': 'ភាសាខ្មែរ (Default)',
      'lang_en': 'English',
      'share_app': 'ចែករំលែកកម្មវិធីទៅទូរស័ព្ទផ្សេង',
      'share_app_sub': 'ផ្ញើឯកសារ APK ទៅកាន់ទូរស័ព្ទផ្សេងទៀត',
      'app_version': 'កំណែទម្រង់កម្មវិធី',
      'version_code': 'Version 1.0.0 (16/11/2026)',
      'built_by': 'បង្កើត និងរចនាដោយ Roeurn Rors',
      'share_dialog_title': 'ចែករំលែកកម្មវិធីទៅទូរស័ព្ទផ្សេង',
      'share_dialog_q': 'តើទូរស័ព្ទផ្សេងទៀតអាចប្រើបាន និងរក្សាទុកទិន្នន័យដោយរបៀបណា?',
      'share_dialog_ans': 'បាទ/ចាស! កម្មវិធីនេះដំណើរការ Offline 100% ដោយមិនចាំបាច់មានអ៊ីនធឺណិតឡើយ។\n\nពេលដែលអ្នកចែករំលែកកម្មវិធីនេះ (តាម Bluetooth, Quick Share, Telegram, WhatsApp...):\n• ទូរស័ព្ទដែលបានដំឡើង នឹងទទួលបានប្រព័ន្ធ SQLite Database ផ្ទាល់ខ្លួនរបស់ពួកគេ។\n• ទិន្នន័យស្រូវ និងទម្ងន់បាវរបស់អ្នក នៅតែមានសុវត្ថិភាព និងឯកជន 100% លើទូរស័ព្ទរបស់អ្នក។',
      'share_now_btn': 'ចែករំលែកឯកសារ APK ឥឡូវនេះ',
      'close_btn': 'បិទ',
      'no_harvests': 'មិនទាន់មានកំណត់ត្រាច្រូតកាត់ទេ',
      'no_matching': 'រកមិនឃើញការច្រូតកាត់ដែលត្រូវគ្នាទេ',
      'tap_to_start': 'ចុចប៊ូតុង "+ ច្រូតកាត់ថ្មី" ខាងក្រោមដើម្បីចាប់ផ្តើម។',
      'delete_harvest_title': 'លុបកំណត់ត្រាច្រូតកាត់?',
      'delete_harvest_confirm': 'តើអ្នកប្រាកដជាចង់លុប "',
      'undone_warning': '"? សកម្មភាពនេះមិនអាចត្រឡប់វិញបានទេ។',
      'harvest_deleted': 'បានលុបការច្រូតកាត់ដោយជោគជ័យ',

      // Weight Entry Screen
      'finish_and_calculate': 'បញ្ចប់ និងគណនា',
      'switch_to_kg': 'ប្តូរទៅ គីឡូក្រាម (kg)',
      'switch_to_ton': 'ប្តូរទៅ តោន (t)',
      'edit_harvest_info': 'កែប្រែព័ត៌មានច្រូតកាត់',
      'view_price_summary': 'មើលតម្លៃ និងសង្ខេប',
      'total_tons': 'សរុប (តោន)',
      'total_weight_title': 'ទម្ងន់សរុប',
      'total_sacks': 'បាវសរុប',
      'groups': 'ក្រុម',
      'group': 'ក្រុម',
      'subtotal': 'សរុបរង',
      'sack': 'បាវ',
      'delete_group_title': 'លុបក្រុមទី',
      'delete_group_confirm_prefix': 'តើអ្នកប្រាកដជាចង់លុបក្រុមទី ',
      'delete_group_confirm_suffix': ' និងបាវស្រូវទាំងអស់នៅក្នុងក្រុមនេះមែនទេ?',
      'delete_group_tooltip': 'លុបក្រុមនេះ',
      'deleted_successfully': 'ត្រូវបានលុបដោយជោគជ័យ',
      'collapse_all': 'បង្រួមក្រុមទាំងអស់',
      'expand_all': 'ពង្រីកក្រុមទាំងអស់',
      'auto_collapse_full': 'បង្រួមក្រុមពេញស្វ័យប្រវត្តិ (5/5)',
      'enter_sack_weight_hint': 'បញ្ចូលទម្ងន់បាវជា គីឡូក្រាម...',
      'add_btn': 'បន្ថែម',
      'no_weights_yet': 'មិនទាន់មានទម្ងន់នៅឡើយទេ',
      'enter_weights_hint_desc': 'បញ្ចូលទម្ងន់បាវខាងក្រោម។ ក្រុមនីមួយៗផ្ទុក ៥ បាវដោយស្វ័យប្រវត្តិ។',
      'valid_weight_error': 'សូមបញ្ចូលទម្ងន់វិជ្ជមានត្រឹមត្រូវ (ឧ. 50 ឬ 48.5)',
      'at_least_one_weight_error': 'សូមបញ្ចូលទម្ងន់យ៉ាងហោចណាស់មួយបាវមុនពេលបញ្ចប់។',
      'no_weights_in_group': 'គ្មានទម្ងន់ក្នុងក្រុមនេះទេ',

      // Finish & Calculate Confirmation Dialog
      'finish_dialog_title': 'បញ្ចប់ និងគណនា?',
      'harvest_colon': 'ការច្រូតកាត់: ',
      'finish_dialog_desc': 'វានឹងសម្គាល់ការច្រូតកាត់នេះថា បានបញ្ចប់ ហើយបើកផ្ទាំងគណនាតម្លៃលក់។ អ្នកនៅតែអាចកែប្រែទម្ងន់នៅពេលក្រោយបាន។',
      'cancel': 'បោះបង់',
      'confirm_finish': 'យល់ព្រម និងបញ្ចប់',

      // Edit / Delete Sack Dialogs
      'edit_sack': 'កែសម្រួលបាវ #',
      'current_colon': 'បច្ចុប្បន្ន: ',
      'weight_kg_label': 'ទម្ងន់ (គីឡូក្រាម)',
      'enter_weight_error': 'សូមបញ្ចូលទម្ងន់',
      'enter_positive_error': 'សូមបញ្ចូលលេខធំជាង ០',
      'delete': 'លុប',
      'save': 'រក្សាទុក',
      'delete_sack_title': 'លុបបាវនេះ?',
      'delete_sack_confirm': 'តើអ្នកចង់លុបបាវ #',
      'from_group': ' ពីក្រុម ',

      // Harvest Detail Screen
      'harvest_summary_title': 'សង្ខេបការច្រូតកាត់',
      'reopen_harvest': 'បើកការច្រូតកាត់ឡើងវិញ',
      'mark_completed': 'សម្គាល់ថាបានបញ្ចប់',
      'fields_suffix': 'ហិកតា',
      'overall_total': 'សរុបទាំងអស់',
      'metric_tons': 'តោន',
      'kilograms': 'គីឡូក្រាម',
      'selling_calculator_title': 'ម៉ាស៊ីនគណនាតម្លៃលក់',
      'currency_label': 'រូបិយប័ណ្ណ:',
      'riel': 'រៀល',
      'dollar': 'ដុល្លារ',
      'price_per_kg': 'តម្លៃក្នុង ១ គីឡូក្រាម',
      'price_per_ton': 'តម្លៃក្នុង ១ តោន',
      'selling_price_per_kg': 'តម្លៃលក់ក្នុង ១ គីឡូក្រាម',
      'selling_price_per_ton': 'តម្លៃលក់ក្នុង ១ តោន',
      'ton_helper': '១ តោន = ១,០០០ គីឡូក្រាម',
      'unit_price_per_kg_label': 'តម្លៃឯកតា (ក្នុង ១ គីឡូក្រាម):',
      'unit_price_per_ton_label': 'តម្លៃឯកតា (ក្នុង ១ តោន):',
      'equivalent_per_kg': 'ស្មើនឹងក្នុង ១ គីឡូក្រាម:',
      'total_weight_label': 'ទម្ងន់សរុប:',
      'estimated_total_value': 'តម្លៃសរុបប៉ាន់ស្មាន:',
      'not_set': 'មិនទាន់កំណត់',
      'weight_groups_and_sacks': 'ក្រុមទម្ងន់ និងបាវ',
      'add_edit_sacks': 'បន្ថែម / កែប្រែបាវ',
      'marked_completed': 'ការច្រូតកាត់ត្រូវបានសម្គាល់ថា បានបញ្ចប់',
      'reopened_in_progress': 'ការច្រូតកាត់ត្រូវបានបើកឡើងវិញ (កំពុងដំណើរការ)',
      'no_weights_recorded_yet': 'មិនទាន់មានទិន្នន័យថ្លឹងនៅឡើយទេ',
      'not_found': 'រកមិនឃើញ',
      'harvest_not_found': 'រកមិនឃើញទិន្នន័យច្រូតកាត់ទេ',
      'share_receipt': 'ចែករំលែកបង្កាន់ដៃ',
      'receipt_preview': 'មើលបង្កាន់ដៃថ្លឹងស្រូវ',
      'receipt_title': 'បង្កាន់ដៃថ្លឹងស្រូវ',
      'copy_receipt': 'ចម្លងអត្ថបទ',
      'receipt_copied': 'បានចម្លងបង្កាន់ដៃទៅក្ដារតម្បៀតខ្ទាស់',
      'share_via_apps': 'ផ្ញើទៅ Telegram / កម្មវិធីផ្សេងៗ',
      'breakdown_by_group': 'បញ្ជីទម្ងន់តាមក្រុម',
      'recorded_via': 'កត់ត្រាដោយកម្មវិធី គ្រប់គ្រងទម្ងន់ស្រូវ (Rice Weight Manager)',
      'undo': 'ត្រឡប់ក្រោយ',
      'sack_added_prefix': 'បានបញ្ចូលបាវ ',
      'sack_undone': 'បានលុបបាវចុងក្រោយវិញ',
      'nothing_to_undo': 'គ្មានបាវសម្រាប់ត្រឡប់ក្រោយទេ',
      'quick_weights': 'ទម្ងន់រហ័ស',
      'repeat_last': 'ដូចមុន',

      // Harvest Form Screen
      'new_harvest_title': 'បង្កើតការច្រូតកាត់ថ្មី',
      'edit_harvest_title': 'កែប្រែការច្រូតកាត់',
      'harvest_name_label': 'ឈ្មោះការច្រូតកាត់ *',
      'harvest_name_hint': 'ឧ. ស្រែខាងកើត ២០២៦',
      'harvest_name_error': 'សូមបញ្ចូលឈ្មោះការច្រូតកាត់',
      'field_count_label': 'ទំហំដី (ហិកតា)',
      'field_count_hint': 'ឧ. 2.5 (ហិកតា)',
      'field_count_error': 'សូមបញ្ចូលលេខវិជ្ជមានត្រឹមត្រូវ (ឧ. 1.5 ឬ 3)',
      'harvest_date_label': 'កាលបរិច្ឆេទច្រូតកាត់',
      'notes_label': 'កំណត់ចំណាំផ្សេងៗ',
      'notes_hint': 'ឧ. ស្រូវផ្ការំដួល, ស្រូវធ្ងន់...',
      'create_harvest_btn': 'បង្កើតការច្រូតកាត់',
      'update_harvest_btn': 'កែប្រែការច្រូតកាត់',
    },
    'en': {
      'app_title': 'Rice Weight Manager',
      'app_subtitle': 'Offline Rice Harvest & Sack Weighing',
      'total_records': 'Total Records',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'all': 'All',
      'search_hint': 'Search harvest records by name...',
      'new_harvest': 'New Harvest',
      'total_weight': 'Total Weight:',
      'view_details': 'View Details',
      'enter_weights': 'Enter Weights',
      'settings': 'Settings',
      'weight_unit_title': 'Harvest Total Weight Unit',
      'weight_unit_desc': 'Display harvest total weight in Kilograms (Kg) or Metric Tons (T)',
      'unit_kg': 'Kilograms (Kg)',
      'unit_ton': 'Metric Tons (T)',
      'theme_title': 'App Theme',
      'theme_desc': 'Choose between Light and Dark mode',
      'theme_light': 'Light Mode',
      'theme_dark': 'Dark Mode',
      'language_title': 'Language',
      'language_desc': 'Select application language',
      'lang_km': 'Khmer (ភាសាខ្មែរ)',
      'lang_en': 'English',
      'share_app': 'Share App to Another Phone',
      'share_app_sub': 'Send APK to other phones',
      'app_version': 'App Version',
      'version_code': 'Version 1.0.0 (16/11/2026)',
      'built_by': 'Developed & Built by Roeurn Rors',
      'share_dialog_title': 'Share Rice Weight Manager',
      'share_dialog_q': 'How does it work on another phone?',
      'share_dialog_ans': 'YES, absolutely! This app runs 100% offline with zero internet required.\n\nWhen you share this APK (via Bluetooth, Quick Share, Telegram, WhatsApp...):\n• The recipient phone installs its own independent SQLite database.\n• Your recorded harvests remain 100% private on your own phone.\n• They can start recording sacks offline immediately.',
      'share_now_btn': 'Share APK Now',
      'close_btn': 'Close',
      'no_harvests': 'No harvest records yet',
      'no_matching': 'No matching harvest records',
      'tap_to_start': 'Tap "+ New Harvest" below to record your first rice batch.',
      'delete_harvest_title': 'Delete Harvest Record?',
      'delete_harvest_confirm': 'Are you sure you want to delete "',
      'undone_warning': '"? This action cannot be undone.',
      'harvest_deleted': 'Harvest deleted successfully',

      // Weight Entry Screen
      'finish_and_calculate': 'Finish & Calculate',
      'switch_to_kg': 'Switch to kg',
      'switch_to_ton': 'Switch to Ton (t)',
      'edit_harvest_info': 'Edit Harvest Info',
      'view_price_summary': 'View Price & Summary',
      'total_tons': 'Total (Tons)',
      'total_weight_title': 'Total Weight',
      'total_sacks': 'Total Sacks',
      'groups': 'Groups',
      'group': 'Group',
      'subtotal': 'Subtotal',
      'sack': 'Sack',
      'delete_group_title': 'Delete Group',
      'delete_group_confirm_prefix': 'Are you sure you want to delete Group ',
      'delete_group_confirm_suffix': ' and all sacks in this group?',
      'delete_group_tooltip': 'Delete this group',
      'deleted_successfully': 'deleted successfully',
      'collapse_all': 'Collapse All Groups',
      'expand_all': 'Expand All Groups',
      'auto_collapse_full': 'Auto-collapse full groups (5/5)',
      'enter_sack_weight_hint': 'Enter sack weight in kg...',
      'add_btn': 'Add',
      'no_weights_yet': 'No weight entries yet',
      'enter_weights_hint_desc': 'Enter sack weights below. Each group holds 5 sacks automatically.',
      'valid_weight_error': 'Please enter a valid positive weight (e.g. 50 or 48.5)',
      'at_least_one_weight_error': 'Please enter at least one weight before finishing.',
      'no_weights_in_group': 'No weights in this group',

      // Finish & Calculate Confirmation Dialog
      'finish_dialog_title': 'Finish & Calculate?',
      'harvest_colon': 'Harvest: ',
      'finish_dialog_desc': 'This will mark the harvest as Completed and open the Selling Price Calculator. You can still edit weights later if needed.',
      'cancel': 'Cancel',
      'confirm_finish': 'Confirm & Finish',

      // Edit / Delete Sack Dialogs
      'edit_sack': 'Edit Sack #',
      'current_colon': 'Current: ',
      'weight_kg_label': 'Weight (kg)',
      'enter_weight_error': 'Enter a weight',
      'enter_positive_error': 'Enter a valid number > 0',
      'delete': 'Delete',
      'save': 'Save',
      'delete_sack_title': 'Delete Sack?',
      'delete_sack_confirm': 'Delete Sack #',
      'from_group': ' from Group ',

      // Harvest Detail Screen
      'harvest_summary_title': 'Harvest Summary',
      'reopen_harvest': 'Reopen Harvest',
      'mark_completed': 'Mark Completed',
      'fields_suffix': 'Hectare',
      'overall_total': 'Overall Total',
      'metric_tons': 'Metric Tons',
      'kilograms': 'Kilograms',
      'selling_calculator_title': 'Selling Price Calculator',
      'currency_label': 'Currency:',
      'riel': 'Riel',
      'dollar': 'Dollar',
      'price_per_kg': 'Price per kg',
      'price_per_ton': 'Price per Ton',
      'selling_price_per_kg': 'Selling Price per kg',
      'selling_price_per_ton': 'Selling Price per Ton',
      'ton_helper': '1 ton = 1,000 kg',
      'unit_price_per_kg_label': 'Unit Price (per kg):',
      'unit_price_per_ton_label': 'Unit Price (per ton):',
      'equivalent_per_kg': 'Equivalent per kg:',
      'total_weight_label': 'Total Weight:',
      'estimated_total_value': 'Estimated Total Value:',
      'not_set': 'Not set',
      'weight_groups_and_sacks': 'Weight Groups & Sacks',
      'add_edit_sacks': 'Add / Edit Sacks',
      'marked_completed': 'Harvest marked as Completed',
      'reopened_in_progress': 'Harvest reopened (In Progress)',
      'no_weights_recorded_yet': 'No weights recorded yet',
      'not_found': 'Not Found',
      'harvest_not_found': 'Harvest not found',
      'share_receipt': 'Share Receipt',
      'receipt_preview': 'Receipt Preview',
      'receipt_title': 'Rice Harvest Receipt',
      'copy_receipt': 'Copy Text',
      'receipt_copied': 'Receipt copied to clipboard',
      'share_via_apps': 'Share to Telegram / Apps',
      'breakdown_by_group': 'Breakdown by Group',
      'recorded_via': 'Recorded via Rice Weight Manager',
      'undo': 'Undo',
      'sack_added_prefix': 'Added sack ',
      'sack_undone': 'Last sack undone',
      'nothing_to_undo': 'Nothing to undo',
      'quick_weights': 'Quick Weights',
      'repeat_last': 'Repeat',

      // Harvest Form Screen
      'new_harvest_title': 'New Harvest Record',
      'edit_harvest_title': 'Edit Harvest Record',
      'harvest_name_label': 'Harvest Name *',
      'harvest_name_hint': 'e.g. East Field Batch 1',
      'harvest_name_error': 'Please enter a harvest name',
      'field_count_label': 'Land Area (Hectare)',
      'field_count_hint': 'e.g. 2.5 (Hectare)',
      'field_count_error': 'Please enter a valid positive number (e.g. 1.5 or 3)',
      'harvest_date_label': 'Harvest Date',
      'notes_label': 'Notes / Remarks',
      'notes_hint': 'e.g. Jasmine variety, damp weather conditions...',
      'create_harvest_btn': 'Create Harvest',
      'update_harvest_btn': 'Update Harvest',
    }
  };

  String tr(String key) {
    return _strings[_language]?[key] ?? _strings['en']?[key] ?? key;
  }
}
