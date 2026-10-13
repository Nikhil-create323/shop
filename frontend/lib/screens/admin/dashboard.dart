import 'package:dummy_apps/providers/admin_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isDaily = true; // true = Daily, false = Monthly

  @override
  Widget build(BuildContext context) {
    final dashboardData = ref.watch(adminDashboardProvider);

    final stats = _isDaily ? dashboardData.dailyStats : dashboardData.monthlyStats;
    final periodLabel = _isDaily ? "Today's" : "This Month's";

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(adminDashboardProvider.notifier).fetchStats(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER & FILTER TOGGLE
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Business Dashboard',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Revenue, Profit/Loss & Inventory Analytics',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () =>
                          ref.read(adminDashboardProvider.notifier).fetchStats(),
                      tooltip: 'Refresh Stats',
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // PERIOD SWITCHER (DAILY VS MONTHLY)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Daily Stats'),
                      icon: Icon(Icons.today),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Monthly Stats'),
                      icon: Icon(Icons.calendar_month),
                    ),
                  ],
                  selected: {_isDaily},
                  onSelectionChanged: (val) {
                    setState(() {
                      _isDaily = val.first;
                    });
                  },
                ),
                const SizedBox(height: 20),

                if (dashboardData.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (dashboardData.error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        dashboardData.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  )
                else ...[
                  // STATS CARDS GRID
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.35,
                    children: [
                      // REVENUE CARD
                      _buildStatCard(
                        context,
                        title: '$periodLabel Revenue',
                        value: '₹${stats.revenue.toStringAsFixed(2)}',
                        icon: Icons.account_balance_wallet_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),

                      // NET PROFIT CARD
                      _buildStatCard(
                        context,
                        title: '$periodLabel Net Profit',
                        value: '₹${stats.profit.toStringAsFixed(2)}',
                        icon: stats.profit >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: stats.profit >= 0 ? Colors.green : Colors.red,
                        subtitle: stats.cost > 0
                            ? 'Margin: ${((stats.profit / (stats.revenue == 0 ? 1 : stats.revenue)) * 100).toStringAsFixed(1)}%'
                            : null,
                      ),

                      // ORDERS COUNT CARD
                      _buildStatCard(
                        context,
                        title: '$periodLabel Orders',
                        value: '${stats.ordersCount}',
                        icon: Icons.shopping_bag_outlined,
                        color: Colors.orange,
                      ),

                      // TOTAL PRODUCTS IN STORE
                      _buildStatCard(
                        context,
                        title: 'Catalog Size',
                        value: '${dashboardData.totalProducts}',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.purple,
                      ),
                      _buildStatCard(
                        context,
                        title: 'Units in Stock',
                        value: '${dashboardData.totalStockUnits}',
                        icon: Icons.warehouse_outlined,
                        color: Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // MOST & LEAST SOLD PRODUCTS
                  Text(
                    'Product Performance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      // MOST SOLD PRODUCT
                      Expanded(
                        child: _buildProductPerformanceCard(
                          context,
                          title: 'Most Sold',
                          badgeColor: Colors.amber,
                          badgeText: '🏆 TOP SELLER',
                          item: dashboardData.mostSold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // LEAST SOLD PRODUCT
                      Expanded(
                        child: _buildProductPerformanceCard(
                          context,
                          title: 'Least Sold',
                          badgeColor: Colors.blueGrey,
                          badgeText: '🔻 LOWEST SALES',
                          item: dashboardData.leastSold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // DETAILED PROFIT & LOSS COMPARISON TABLE / CARD
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(20),
                    color: Theme.of(context).colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Financial Profit & Loss Breakdown',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildFinancialRow(
                            'Daily Gross Revenue',
                            '₹${dashboardData.dailyStats.revenue.toStringAsFixed(2)}',
                          ),
                          _buildFinancialRow(
                            'Daily Product Cost',
                            '₹${dashboardData.dailyStats.cost.toStringAsFixed(2)}',
                          ),
                          _buildFinancialRow(
                            'Daily Net Profit / Loss',
                            '₹${dashboardData.dailyStats.profit.toStringAsFixed(2)}',
                            isProfit: true,
                            profitVal: dashboardData.dailyStats.profit,
                          ),
                          const Divider(height: 20),
                          _buildFinancialRow(
                            'Monthly Gross Revenue',
                            '₹${dashboardData.monthlyStats.revenue.toStringAsFixed(2)}',
                          ),
                          _buildFinancialRow(
                            'Monthly Product Cost',
                            '₹${dashboardData.monthlyStats.cost.toStringAsFixed(2)}',
                          ),
                          _buildFinancialRow(
                            'Monthly Net Profit / Loss',
                            '₹${dashboardData.monthlyStats.profit.toStringAsFixed(2)}',
                            isProfit: true,
                            profitVal: dashboardData.monthlyStats.profit,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductPerformanceCard(
    BuildContext context, {
    required String title,
    required Color badgeColor,
    required String badgeText,
    required ProductSaleItem? item,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor is MaterialColor ? badgeColor.shade900 : badgeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (item == null || item.title == 'N/A')
              const Text(
                'No data available',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              )
            else ...[
              if (item.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    height: 70,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Units Sold: ${item.quantity}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Revenue: ₹${item.revenue.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialRow(
    String label,
    String amount, {
    bool isProfit = false,
    double profitVal = 0,
  }) {
    Color valColor = Theme.of(context).colorScheme.onSurface;
    if (isProfit) {
      valColor = profitVal >= 0 ? Colors.green : Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isProfit
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: isProfit ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isProfit ? FontWeight.bold : FontWeight.w600,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}
