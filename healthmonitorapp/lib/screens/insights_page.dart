import 'package:flutter/material.dart';
import 'package:vitality/models/health_reading.dart';
import 'package:vitality/services/health_reading_service.dart';
import 'package:vitality/theme.dart';
import 'package:vitality/widgets/stat_card.dart';
import 'package:fl_chart/fl_chart.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final HealthReadingService _readingService = HealthReadingService();

  List<HealthReading> _readings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final readings = await _readingService.getReadings();

    setState(() {
      _readings = readings;
      _isLoading = false;
    });
  }

  Map<ReadingType, double> _calculateAverages() {
    final averages = <ReadingType, double>{};
    final counts = <ReadingType, int>{};

    for (final reading in _readings) {
      averages[reading.type] = (averages[reading.type] ?? 0) + reading.value;
      counts[reading.type] = (counts[reading.type] ?? 0) + 1;
    }

    for (final type in averages.keys) {
      averages[type] = averages[type]! / counts[type]!;
    }

    return averages;
  }

  String _getTrendIndicator(ReadingType type) {
    final typeReadings = _readings.where((r) => r.type == type).toList();
    if (typeReadings.length < 2) return '—';

    typeReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final recent = typeReadings.skip(typeReadings.length ~/ 2).toList();
    final older = typeReadings.take(typeReadings.length ~/ 2).toList();

    final recentAvg =
        recent.map((r) => r.value).reduce((a, b) => a + b) / recent.length;
    final olderAvg =
        older.map((r) => r.value).reduce((a, b) => a + b) / older.length;

    final diff = recentAvg - olderAvg;
    if (diff > 2) return '📈 Increasing';
    if (diff < -2) return '📉 Decreasing';
    return '➡️ Stable';
  }

  List<FlSpot> _getChartData(ReadingType type) {
    final typeReadings = _readings.where((r) => r.type == type).toList();
    if (typeReadings.isEmpty) return [];

    typeReadings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final last7 = typeReadings.length > 7
        ? typeReadings.sublist(typeReadings.length - 7)
        : typeReadings;

    return List.generate(
      last7.length,
      (i) => FlSpot(i.toDouble(), last7[i].value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final averages = _calculateAverages();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Insights',
          style: context.textStyles.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _readings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.insights_outlined,
                            size: 64,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Text(
                            'No insights yet',
                            style: context.textStyles.titleLarge,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Add readings to see insights',
                            style: context.textStyles.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: AppSpacing.paddingLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Overview',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          StatCard(
                            label: 'Total Readings',
                            value: _readings.length.toString(),
                            subtitle: 'All time',
                            icon: Icons.analytics_outlined,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            'Averages & Trends',
                            style: context.textStyles.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          ...averages.entries.map((entry) {
                            final chartData = _getChartData(entry.key);
                            return Column(
                              children: [
                                Container(
                                  padding: AppSpacing.paddingLg,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardTheme.color,
                                    border: Border.all(
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                      width: 1,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            entry.key.icon,
                                            style:
                                                const TextStyle(fontSize: 24),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              entry.key.displayName,
                                              style: context
                                                  .textStyles.titleMedium
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Average',
                                                style: context
                                                    .textStyles.bodySmall
                                                    ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                '${entry.value.toStringAsFixed(1)} ${entry.key.unit}',
                                                style: context
                                                    .textStyles.headlineSmall
                                                    ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: AppSpacing.sm,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primaryContainer,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.sm),
                                            ),
                                            child: Text(
                                              _getTrendIndicator(entry.key),
                                              style: context
                                                  .textStyles.bodySmall
                                                  ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (chartData.length >= 2) ...[
                                        const SizedBox(height: AppSpacing.lg),
                                        SizedBox(
                                          height: 120,
                                          child: LineChart(
                                            LineChartData(
                                              gridData:
                                                  const FlGridData(show: false),
                                              titlesData: const FlTitlesData(
                                                  show: false),
                                              borderData:
                                                  FlBorderData(show: false),
                                              lineBarsData: [
                                                LineChartBarData(
                                                  spots: chartData,
                                                  isCurved: true,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  barWidth: 3,
                                                  dotData: FlDotData(
                                                    show: true,
                                                    getDotPainter: (spot,
                                                        percent,
                                                        barData,
                                                        index) {
                                                      return FlDotCirclePainter(
                                                        radius: 4,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                        strokeWidth: 0,
                                                      );
                                                    },
                                                  ),
                                                  belowBarData: BarAreaData(
                                                    show: true,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withValues(alpha: 0.1),
                                                  ),
                                                ),
                                              ],
                                              lineTouchData:
                                                  const LineTouchData(
                                                      enabled: false),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
            ),
    );
  }
}
