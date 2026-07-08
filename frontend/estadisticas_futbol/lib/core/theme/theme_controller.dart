import 'package:flutter/foundation.dart';

import '../../data/local/database_helper.dart';
import 'app_colors.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  static const _cacheKey = 'app_theme_preference';

  final DatabaseHelper _databaseHelper;
  bool _isDarkMode = true;

  bool get isDarkMode => _isDarkMode;

  Future<void> initialize() async {
    try {
      final saved = await _databaseHelper.readJsonMap(_cacheKey);
      _isDarkMode = saved?['isDarkMode'] as bool? ?? true;
    } catch (_) {
      _isDarkMode = true;
    }
    AppColors.setDarkMode(_isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    AppColors.setDarkMode(value);
    notifyListeners();

    try {
      await _databaseHelper.saveJson(
        _cacheKey,
        {'isDarkMode': value},
      );
    } catch (_) {
      // The selected theme remains active even if local persistence fails.
    }
  }
}
