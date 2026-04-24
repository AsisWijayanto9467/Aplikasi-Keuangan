// lib/models/budget_model.dart
class BudgetModel {
  final int? budgetId;
  final int categoryId;
  final String categoryName;
  final bool hasBudget;
  final double? limit;
  final double? spent;
  final double? remaining;
  final double? percentage;
  final String status;
  final int month;
  final int year;

  BudgetModel({
    this.budgetId,
    required this.categoryId,
    required this.categoryName,
    required this.hasBudget,
    this.limit,
    this.spent,
    this.remaining,
    this.percentage,
    required this.status,
    required this.month,
    required this.year,
  });

  factory BudgetModel.fromJson(Map<String, dynamic> json) {
    return BudgetModel(
      budgetId: json['budget_id'],
      categoryId: json['category_id'],
      categoryName: json['category_name'] ?? '',
      hasBudget: json['has_budget'] ?? false,
      limit: json['limit'] != null ? double.parse(json['limit'].toString()) : null,
      spent: json['spent'] != null ? double.parse(json['spent'].toString()) : null,
      remaining: json['remaining'] != null ? double.parse(json['remaining'].toString()) : null,
      percentage: json['percentage'] != null ? double.parse(json['percentage'].toString()) : null,
      status: json['status'] ?? 'no_budget',
      month: json['month'] ?? DateTime.now().month,
      year: json['year'] ?? DateTime.now().year,
    );
  }

  // Get status color
  String get statusText {
    switch (status) {
      case 'exceeded':
        return 'Melebihi';
      case 'warning':
        return 'Hampir Habis';
      case 'half':
        return 'Setengah';
      case 'safe':
        return 'Aman';
      case 'no_budget':
        return 'Tanpa Budget';
      default:
        return status;
    }
  }

  // Get status color for UI
  int get statusColor {
    switch (status) {
      case 'exceeded':
        return 0xFFEF4444; // Red
      case 'warning':
        return 0xFFF59E0B; // Amber
      case 'half':
        return 0xFF3B82F6; // Blue
      case 'safe':
        return 0xFF10B981; // Green
      case 'no_budget':
        return 0xFF9CA3AF; // Gray
      default:
        return 0xFF9CA3AF;
    }
  }
}

class BudgetSummary {
  final int totalBudgets;
  final double totalLimit;
  final double totalSpent;
  final double? totalRemaining;
  final double? totalPercentage;

  BudgetSummary({
    required this.totalBudgets,
    required this.totalLimit,
    required this.totalSpent,
    this.totalRemaining,
    this.totalPercentage,
  });

  factory BudgetSummary.fromJson(Map<String, dynamic> json) {
    return BudgetSummary(
      totalBudgets: json['total_budgets'] ?? 0,
      totalLimit: json['total_limit'] != null ? double.parse(json['total_limit'].toString()) : 0,
      totalSpent: json['total_spent'] != null ? double.parse(json['total_spent'].toString()) : 0,
      totalRemaining: json['total_remaining'] != null ? double.parse(json['total_remaining'].toString()) : null,
      totalPercentage: json['total_percentage'] != null ? double.parse(json['total_percentage'].toString()) : null,
    );
  }
}