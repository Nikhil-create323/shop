import 'dart:convert';
import 'package:dummy_apps/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ProductSaleItem {
  final String id;
  final String title;
  final int quantity;
  final double revenue;
  final double costPrice;
  final String imageUrl;

  ProductSaleItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.revenue,
    required this.costPrice,
    required this.imageUrl,
  });

  factory ProductSaleItem.fromJson(Map<String, dynamic> json) {
    return ProductSaleItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: json['title']?.toString() ?? 'N/A',
      quantity: json['quantity'] is num ? (json['quantity'] as num).toInt() : 0,
      revenue: json['revenue'] is num ? (json['revenue'] as num).toDouble() : 0.0,
      costPrice: json['costPrice'] is num ? (json['costPrice'] as num).toDouble() : 0.0,
      imageUrl: json['imageUrl']?.toString() ?? '',
    );
  }
}

class PeriodStats {
  final double revenue;
  final double cost;
  final double profit;
  final int ordersCount;

  PeriodStats({
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.ordersCount,
  });

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    return PeriodStats(
      revenue: json['revenue'] is num ? (json['revenue'] as num).toDouble() : 0.0,
      cost: json['cost'] is num ? (json['cost'] as num).toDouble() : 0.0,
      profit: json['profit'] is num ? (json['profit'] as num).toDouble() : 0.0,
      ordersCount: json['ordersCount'] is num ? (json['ordersCount'] as num).toInt() : 0,
    );
  }
}

class AdminDashboardData {
  final ProductSaleItem? mostSold;
  final ProductSaleItem? leastSold;
  final PeriodStats dailyStats;
  final PeriodStats monthlyStats;
  final int totalProducts;
  final int totalStockUnits;
  final int totalOrders;
  final bool isLoading;
  final String? error;

  AdminDashboardData({
    this.mostSold,
    this.leastSold,
    required this.dailyStats,
    required this.monthlyStats,
    this.totalProducts = 0,
    this.totalStockUnits = 0,
    this.totalOrders = 0,
    this.isLoading = false,
    this.error,
  });

  factory AdminDashboardData.empty() {
    return AdminDashboardData(
      dailyStats: PeriodStats(revenue: 0, cost: 0, profit: 0, ordersCount: 0),
      monthlyStats: PeriodStats(revenue: 0, cost: 0, profit: 0, ordersCount: 0),
      totalProducts: 0,
      totalStockUnits: 0,
      totalOrders: 0,
      isLoading: false,
    );
  }

  AdminDashboardData copyWith({
    ProductSaleItem? mostSold,
    ProductSaleItem? leastSold,
    PeriodStats? dailyStats,
    PeriodStats? monthlyStats,
    int? totalProducts,
    int? totalStockUnits,
    int? totalOrders,
    bool? isLoading,
    String? error,
  }) {
    return AdminDashboardData(
      mostSold: mostSold ?? this.mostSold,
      leastSold: leastSold ?? this.leastSold,
      dailyStats: dailyStats ?? this.dailyStats,
      monthlyStats: monthlyStats ?? this.monthlyStats,
      totalProducts: totalProducts ?? this.totalProducts,
      totalStockUnits: totalStockUnits ?? this.totalStockUnits,
      totalOrders: totalOrders ?? this.totalOrders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminDashboardNotifier extends Notifier<AdminDashboardData> {
  @override
  AdminDashboardData build() {
    fetchStats();
    return AdminDashboardData.empty();
  }

  Future<void> fetchStats() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/admin/dashboard'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = AdminDashboardData(
          mostSold: data['mostSold'] != null ? ProductSaleItem.fromJson(data['mostSold']) : null,
          leastSold: data['leastSold'] != null ? ProductSaleItem.fromJson(data['leastSold']) : null,
          dailyStats: PeriodStats.fromJson(data['dailyStats'] ?? {}),
          monthlyStats: PeriodStats.fromJson(data['monthlyStats'] ?? {}),
          totalProducts: data['totalProducts'] ?? 0,
          totalStockUnits: data['totalStockUnits'] ?? 0,
          totalOrders: data['totalOrders'] ?? 0,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to load stats: ${response.statusCode}',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error fetching stats: $e',
      );
    }
  }
}

final adminDashboardProvider =
    NotifierProvider<AdminDashboardNotifier, AdminDashboardData>(
  AdminDashboardNotifier.new,
);
