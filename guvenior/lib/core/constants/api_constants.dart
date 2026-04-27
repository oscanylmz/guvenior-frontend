import 'package:flutter/foundation.dart';

class ApiConstants {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5219';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:5219',
      _ => 'http://127.0.0.1:5219',
    };
  }

  static const String register = '/api/Auth/register';
  static const String login = '/api/Auth/login';
  static const String profile = '/api/Auth/profile';
  static const String updateSalary = '/api/Auth/update-salary';
  static const String income = '/api/Income';
  static const String expense = '/api/Expense';
  static const String budget = '/api/Budget';
  static const String recurringExpense = '/api/RecurringExpense';
}
