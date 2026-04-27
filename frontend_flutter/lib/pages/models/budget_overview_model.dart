class BudgetOverview {
  final int month;
  final int year;
  final String monthLabel;
  final IncomeData? income;
  final double todaySpent;
  final List<BudgetItem> budgets;
  final AlertsData alerts;

  BudgetOverview({
    required this.month,
    required this.year,
    required this.monthLabel,
    this.income,
    required this.todaySpent,
    required this.budgets,
    required this.alerts,
  });

  factory BudgetOverview.fromJson(Map<String, dynamic> json) {
    return BudgetOverview(
      month: json['month'],
      year: json['year'],
      monthLabel: json['month_label'],
      income: json['income'] != null ? IncomeData.fromJson(json['income']) : null,
      todaySpent: (json['today_spent'] ?? 0).toDouble(),
      budgets: (json['budgets'] as List<dynamic>)
          .map((b) => BudgetItem.fromJson(b))
          .toList(),
      alerts: AlertsData.fromJson(json['alerts'] ?? {}),
    );
  }
}

class IncomeData {
  final double totalIncome;
  final double totalBudget;
  final double totalSpent;
  final double unallocatedAmount;
  final double remainingBalanced;
  final double budgetUsagePercentage;
  final double dailyRecommendation;

  IncomeData({
    required this.totalIncome,
    required this.totalBudget,
    required this.totalSpent,
    required this.unallocatedAmount,
    required this.remainingBalanced,
    required this.budgetUsagePercentage,
    required this.dailyRecommendation,
  });

  factory IncomeData.fromJson(Map<String, dynamic> json) {
    return IncomeData(
      totalIncome: (json['total_income'] ?? 0).toDouble(),
      totalBudget: (json['total_budget'] ?? 0).toDouble(),
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      unallocatedAmount: (json['unallocated_amount'] ?? 0).toDouble(),
      remainingBalanced: (json['remaining_balanced'] ?? 0).toDouble(),
      budgetUsagePercentage: (json['budget_usage_percentage'] ?? 0).toDouble(),
      dailyRecommendation: (json['daily_recommendation'] ?? 0).toDouble(),
    );
  }
}

class BudgetItem {
  final int id;
  final int categoryId;
  final String categoryName;
  final double limitAmount;
  final double totalSpent;
  final double remainingAmount;
  final double usagePercentage;
  final String status;
  final int remainingDays;
  final double dailyRecommendation;
  final double averageDailySpent;

  BudgetItem({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.limitAmount,
    required this.totalSpent,
    required this.remainingAmount,
    required this.usagePercentage,
    required this.status,
    required this.remainingDays,
    required this.dailyRecommendation,
    required this.averageDailySpent,
  });

  factory BudgetItem.fromJson(Map<String, dynamic> json) {
    return BudgetItem(
      id: json['id'] ?? 0,
      categoryId: json['category_id'] ?? 0,
      categoryName: json['category_name'] ?? '',
      limitAmount: (json['limit_amount'] ?? 0).toDouble(),
      totalSpent: (json['total_spent'] ?? 0).toDouble(),
      remainingAmount: (json['remaining_amount'] ?? 0).toDouble(),
      usagePercentage: (json['usage_percentage'] ?? 0).toDouble(),
      status: json['status'] ?? 'safe',
      remainingDays: json['remaining_days'] ?? 0,
      dailyRecommendation: (json['daily_recommendation'] ?? 0).toDouble(),
      averageDailySpent: (json['average_daily_spent'] ?? 0).toDouble(),
    );
  }
}

class AlertsData {
  final List<AlertItem> almostExceeded;
  final AlertItem? mostUsedBudget;

  AlertsData({required this.almostExceeded, this.mostUsedBudget});

  factory AlertsData.fromJson(Map<String, dynamic> json) {
    return AlertsData(
      almostExceeded: (json['almost_exceeded'] as List<dynamic>?)
              ?.map((e) => AlertItem.fromJson(e))
              .toList() ??
          [],
      mostUsedBudget: json['most_used_budget'] != null
          ? AlertItem.fromJson(json['most_used_budget'])
          : null,
    );
  }
}

class AlertItem {
  final String categoryName;
  final double usagePercentage;
  final double remainingAmount;

  AlertItem({
    required this.categoryName,
    required this.usagePercentage,
    required this.remainingAmount,
  });

  factory AlertItem.fromJson(Map<String, dynamic> json) {
    return AlertItem(
      categoryName: json['category_name'] ?? '',
      usagePercentage: (json['usage_percentage'] ?? 0).toDouble(),
      remainingAmount: (json['remaining_amount'] ?? 0).toDouble(),
    );
  }
}