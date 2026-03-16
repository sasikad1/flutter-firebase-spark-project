import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme {
  light,
  dark,
  system,
}

class ThemeProvider extends ChangeNotifier {
  static const String _themePrefKey = 'app_theme';

  AppTheme _currentTheme = AppTheme.system;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  AppTheme get currentTheme => _currentTheme;

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themePrefKey) ?? AppTheme.system.index;
      _currentTheme = AppTheme.values[themeIndex];
      notifyListeners();
    } catch (e) {
      print('Error loading theme preference: $e');
    }
  }

  Future<void> setTheme(AppTheme theme) async {
    _currentTheme = theme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themePrefKey, theme.index);
    notifyListeners();
  }

  ThemeData getThemeData(bool isDarkMode) {
    if (_currentTheme == AppTheme.system) {
      return isDarkMode ? _buildDarkTheme() : _buildLightTheme();
    } else if (_currentTheme == AppTheme.dark) {
      return _buildDarkTheme();
    } else {
      return _buildLightTheme();
    }
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primarySwatch: Colors.pink,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      colorScheme: const ColorScheme.light(
        primary: Colors.pink,
        secondary: Colors.pinkAccent,
        surface: Colors.white,
        background: Colors.white,
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
        onError: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.pink, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.pink,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.pink,
        foregroundColor: Colors.white,
      ),
      colorScheme: const ColorScheme.dark(
        primary: Colors.pink,
        secondary: Colors.pinkAccent,
        surface: Color(0xFF1E1E1E),
        background: Color(0xFF121212),
        error: Colors.red,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        color: Color(0xFF1E1E1E),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.pink, width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}