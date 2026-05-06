import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { en, ar }

class AppSettingsController extends ChangeNotifier {
  static const _themeKey = 'theme_mode';
  static const _languageKey = 'language_code';

  ThemeMode _themeMode = ThemeMode.light;
  AppLanguage _language = AppLanguage.en;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  Locale get locale => Locale(_language == AppLanguage.ar ? 'ar' : 'en');
  TextDirection get textDirection =>
      _language == AppLanguage.ar ? TextDirection.rtl : TextDirection.ltr;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    final savedLanguage = prefs.getString(_languageKey);
    _themeMode = savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    _language = savedLanguage == 'ar' ? AppLanguage.ar : AppLanguage.en;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _languageKey,
      language == AppLanguage.ar ? 'ar' : 'en',
    );
  }
}

class AppSettingsScope extends InheritedNotifier<AppSettingsController> {
  const AppSettingsScope({
    super.key,
    required AppSettingsController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSettingsController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'AppSettingsScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}

extension AppSettingsX on BuildContext {
  AppSettingsController get settings => AppSettingsScope.of(this);
  String t(String key) => AppStrings.translate(settings.language, key);
}

class AppStrings {
  const AppStrings._();

  static const _en = <String, String>{
    'menu': 'Menu',
    'settings': 'Settings',
    'account_settings': 'Account settings',
    'appearance': 'Appearance',
    'light': 'Light',
    'dark': 'Dark',
    'language': 'Language',
    'english': 'English',
    'arabic': 'Arabic',
    'sign_out': 'Sign out',
    'account_info': 'Account information',
    'full_name': 'Full name',
    'email': 'Email',
    'phone': 'Phone number',
    'new_password': 'New password',
    'leave_blank': 'Leave blank to keep current password',
    'save_changes': 'Save changes',
    'saved': 'Changes saved.',
    'reauth_required': 'For email/password changes, sign in again then retry.',
    'jobs_near_you': 'Jobs near you',
    'my_orders': 'My orders',
    'new_order': 'New Order',
    'dashboard': 'Dashboard',
    'users': 'Users',
    'clients': 'Clients',
    'drivers': 'Drivers',
    'all': 'All',
    'no_users': 'No users',
    'no_users_found': 'No users found.',
    'create_order': 'Create Order',
    'order': 'Order',
    'place_bid': 'Place Bid',
    'back': 'Back',
  };

  static const _ar = <String, String>{
    'menu': 'القائمة',
    'settings': 'الإعدادات',
    'account_settings': 'إعدادات الحساب',
    'appearance': 'المظهر',
    'light': 'نهار',
    'dark': 'داكن',
    'language': 'اللغة',
    'english': 'الإنجليزية',
    'arabic': 'العربية',
    'sign_out': 'تسجيل الخروج',
    'account_info': 'معلومات الحساب',
    'full_name': 'الإسم واللقب',
    'email': 'البريد الإلكتروني',
    'phone': 'رقم الهاتف',
    'new_password': 'كلمة سر جديدة',
    'leave_blank': 'اتركها فارغة للإبقاء على كلمة السر الحالية',
    'save_changes': 'حفظ التغييرات',
    'saved': 'تم حفظ التغييرات.',
    'reauth_required':
        'لتغيير البريد أو كلمة السر، سجل الدخول مرة أخرى ثم أعد المحاولة.',
    'jobs_near_you': 'الطلبات القريبة',
    'my_orders': 'طلباتي',
    'new_order': 'طلب جديد',
    'dashboard': 'لوحة التحكم',
    'users': 'المستخدمون',
    'clients': 'الزبائن',
    'drivers': 'السائقون',
    'all': 'الكل',
    'no_users': 'لا يوجد مستخدمون',
    'no_users_found': 'لم يتم العثور على مستخدمين.',
    'create_order': 'إنشاء طلب',
    'order': 'الطلب',
    'place_bid': 'إرسال عرض',
    'back': 'رجوع',
  };

  static String translate(AppLanguage language, String key) {
    final source = language == AppLanguage.ar ? _ar : _en;
    return source[key] ?? _en[key] ?? key;
  }
}
