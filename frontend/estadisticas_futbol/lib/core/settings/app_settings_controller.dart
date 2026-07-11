import 'package:flutter/foundation.dart';

import '../../data/local/database_helper.dart';

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({DatabaseHelper? databaseHelper})
      : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  static const _cacheKey = 'app_settings_preferences';
  static const availableFormations = ['4-3-3', '4-4-2', '4-2-3-1', '3-5-2', '3-4-3'];

  final DatabaseHelper _databaseHelper;
  AppSettings _settings = AppSettings.defaults();

  AppSettings get settings => _settings;

  Future<void> initialize() async {
    try {
      final saved = await _databaseHelper.readJsonMap(_cacheKey);
      _settings = AppSettings.fromJson(saved ?? const {});
    } catch (_) {
      _settings = AppSettings.defaults();
    }
  }

  Future<void> save(AppSettings value) async {
    _settings = value;
    notifyListeners();
    await _persist();
  }

  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaults();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      await _databaseHelper.saveJson(_cacheKey, _settings.toJson());
    } catch (_) {
      // Settings remain active in memory even if local persistence fails.
    }
  }
}

class AppSettings {
  final bool showDashboardGreeting;
  final String defaultFormation;
  final bool showOnlyAvailablePlayers;
  final bool rememberLastFormation;
  final bool automaticSync;
  final bool showPendingSync;

  const AppSettings({
    required this.showDashboardGreeting,
    required this.defaultFormation,
    required this.showOnlyAvailablePlayers,
    required this.rememberLastFormation,
    required this.automaticSync,
    required this.showPendingSync,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      showDashboardGreeting: true,
      defaultFormation: '4-3-3',
      showOnlyAvailablePlayers: false,
      rememberLastFormation: true,
      automaticSync: true,
      showPendingSync: true,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final defaults = AppSettings.defaults();
    return AppSettings(
      showDashboardGreeting:
          json['showDashboardGreeting'] as bool? ?? defaults.showDashboardGreeting,
      defaultFormation:
          AppSettingsController.availableFormations.contains(json['defaultFormation'])
          ? json['defaultFormation'] as String
          : defaults.defaultFormation,
      showOnlyAvailablePlayers: json['showOnlyAvailablePlayers'] as bool? ??
          defaults.showOnlyAvailablePlayers,
      rememberLastFormation:
          json['rememberLastFormation'] as bool? ?? defaults.rememberLastFormation,
      automaticSync: json['automaticSync'] as bool? ?? defaults.automaticSync,
      showPendingSync: json['showPendingSync'] as bool? ?? defaults.showPendingSync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'showDashboardGreeting': showDashboardGreeting,
      'defaultFormation': defaultFormation,
      'showOnlyAvailablePlayers': showOnlyAvailablePlayers,
      'rememberLastFormation': rememberLastFormation,
      'automaticSync': automaticSync,
      'showPendingSync': showPendingSync,
    };
  }

  AppSettings copyWith({
    bool? showDashboardGreeting,
    String? defaultFormation,
    bool? showOnlyAvailablePlayers,
    bool? rememberLastFormation,
    bool? automaticSync,
    bool? showPendingSync,
  }) {
    return AppSettings(
      showDashboardGreeting:
          showDashboardGreeting ?? this.showDashboardGreeting,
      defaultFormation: defaultFormation ?? this.defaultFormation,
      showOnlyAvailablePlayers:
          showOnlyAvailablePlayers ?? this.showOnlyAvailablePlayers,
      rememberLastFormation:
          rememberLastFormation ?? this.rememberLastFormation,
      automaticSync: automaticSync ?? this.automaticSync,
      showPendingSync: showPendingSync ?? this.showPendingSync,
    );
  }
}
