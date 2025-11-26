import 'package:flutter/material.dart';
import 'package:vitality/models/health_reading.dart';
import 'package:vitality/services/health_reading_service.dart';
import 'package:vitality/theme.dart';
import 'package:vitality/widgets/reading_list_item.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HealthReadingService _readingService = HealthReadingService();

  List<HealthReading> _allReadings = [];
  List<HealthReading> _filteredReadings = [];
  ReadingType? _selectedFilter;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final readings = await _readingService.getReadings();
    readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _allReadings = readings;
      _filteredReadings = readings;
      _isLoading = false;
    });
  }

  void _filterReadings(ReadingType? type) {
    setState(() {
      _selectedFilter = type;
      if (type == null) {
        _filteredReadings = _allReadings;
      } else {
        _filteredReadings = _allReadings.where((r) => r.type == type).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'History',
          style: context.textStyles.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  Container(
                    padding: AppSpacing.paddingLg,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            isSelected: _selectedFilter == null,
                            onTap: () => _filterReadings(null),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ...ReadingType.values.map((type) => Padding(
                                padding:
                                    const EdgeInsets.only(right: AppSpacing.sm),
                                child: _FilterChip(
                                  label: type.displayName,
                                  icon: type.icon,
                                  isSelected: _selectedFilter == type,
                                  onTap: () => _filterReadings(type),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filteredReadings.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.history_outlined,
                                  size: 64,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'No readings found',
                                  style: context.textStyles.titleLarge,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  _selectedFilter == null
                                      ? 'Add your first reading'
                                      : 'No ${_selectedFilter!.displayName.toLowerCase()} readings',
                                  style:
                                      context.textStyles.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: AppSpacing.paddingLg,
                            itemCount: _filteredReadings.length,
                            itemBuilder: (context, index) {
                              final reading = _filteredReadings[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.md),
                                child: ReadingListItem(
                                  reading: reading,
                                  onDelete: () async {
                                    await _readingService
                                        .deleteReading(reading.id);
                                    _loadData();
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).cardTheme.color,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Text(
                icon!,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              label,
              style: context.textStyles.bodyMedium?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
