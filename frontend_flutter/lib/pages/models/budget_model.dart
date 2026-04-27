// lib/pages/models/budget_model.dart
import 'package:intl/intl.dart';

class BudgetModel {
  final int? budgetId;
  final int? categoryId;
  final String categoryName;
  final double? limit;
  final double? spent;
  final double? remaining;
  final double? percentage;
  final String status;
  final bool hasBudget;
  final double? dailyRecommendation;
  final double? averageDailySpent;

  BudgetModel({
    this.budgetId,
    this.categoryId,
    required this.categoryName,
    this.limit,
    this.spent,
    this.remaining,
    this.percentage,
    required this.status,
    this.hasBudget = false,
    this.dailyRecommendation,
    this.averageDailySpent,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    final limitAmount = _parseDouble(json['limit_amount']);
    final totalSpent = _parseDouble(json['total_spent']);
    final remainingAmount = _parseDouble(json['remaining_amount']);
    final usagePercentage = _parseDouble(json['usage_percentage']);
    
    return BudgetModel(
      budgetId: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      categoryId: json['category_id'] is int 
          ? json['category_id'] 
          : int.tryParse(json['category_id']?.toString() ?? ''),
      categoryName: json['category_name'] ?? 'Unknown',
      limit: limitAmount,
      spent: totalSpent,
      remaining: remainingAmount,
      percentage: usagePercentage,
      status: json['status'] ?? 'safe',
      hasBudget: json['id'] != null,
      dailyRecommendation: _parseDouble(json['daily_recommendation']),
      averageDailySpent: _parseDouble(json['average_daily_spent']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int get statusColor {
    switch (status) {
      case 'exceeded':
        return 0xFFEF4444;
      case 'danger':
        return 0xFFDC2626;
      case 'warning':
        return 0xFFF59E0B;
      case 'moderate':
        return 0xFF3B82F6;
      case 'safe':
        return 0xFF10B981;
      default:
        return 0xFF6B7280;
    }
  }

  String get statusText {
    switch (status) {
      case 'exceeded':
        return 'Melebihi';
      case 'danger':
        return 'Kritis';
      case 'warning':
        return 'Hati-hati';
      case 'moderate':
        return 'Sedang';
      case 'safe':
        return 'Aman';
      default:
        return 'Unknown';
    }
  }

  String get formattedLimit {
    if (limit == null) return 'Rp 0';
    final formatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return formatter.format(limit);
  }
}

class BudgetSummary {
  final double totalIncome;
  final double totalBudget;
  final double totalSpent;
  final double unallocatedAmount;
  final double remainingBalanced;
  final double budgetUsagePercentage;
  final double? dailyRecommendation;

  BudgetSummary({
    required this.totalIncome,
    required this.totalBudget,
    required this.totalSpent,
    required this.unallocatedAmount,
    required this.remainingBalanced,
    required this.budgetUsagePercentage,
    this.dailyRecommendation,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      totalIncome: _parseDouble(json['total_income']) ?? 0,
      totalBudget: _parseDouble(json['total_budget']) ?? 0,
      totalSpent: _parseDouble(json['total_spent']) ?? 0,
      unallocatedAmount: _parseDouble(json['unallocated_amount']) ?? 0,
      remainingBalanced: _parseDouble(json['remaining_balanced']) ?? 0,
      budgetUsagePercentage: _parseDouble(json['budget_usage_percentage']) ?? 0,
      dailyRecommendation: _parseDouble(json['daily_recommendation']),
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}