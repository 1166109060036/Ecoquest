import '../l10n/tr.dart';

class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return tr('Email is required');
    }
    final emailRegex = RegExp(r'^[\w\.\-+]+@[\w\-]+\.[\w\-\.]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return tr('Invalid email format');
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return tr('Please enter your password');
    }
    if (value.length < 6) {
      return tr('Password must be at least 6 characters');
    }
    return null;
  }
}
