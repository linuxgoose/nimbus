import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nimbus/app/data/db.dart';
import 'package:nimbus/main.dart';

class AlertHistoryPage extends StatefulWidget {
  const AlertHistoryPage({super.key});

  @override
  State<AlertHistoryPage> createState() => _AlertHistoryPageState();
}

class _AlertHistoryPageState extends State<AlertHistoryPage> {
  List<AlertHistory> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  void _loadAlerts() {
    setState(() {
      _isLoading = true;
    });

    // Load all alerts, sorted by timestamp descending (newest first)
    final allAlerts = isar.alertHistorys.getAllSync([]);
    final alerts = allAlerts.whereType<AlertHistory>().toList();
    alerts.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    setState(() {
      _alerts = alerts;
      _isLoading = false;
    });
  }

  void _clearHistory() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Alert History'),
        content: const Text(
          'Are you sure you want to delete all alert history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              isar.writeTxnSync(() {
                isar.alertHistorys.clearSync();
              });
              Navigator.pop(context);
              _loadAlerts();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'extreme':
        return Colors.red;
      case 'severe':
        return Colors.orange;
      case 'moderate':
        return Colors.amber.shade700;
      default:
        return Colors.blue;
    }
  }

  IconData _getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'extreme':
        return LucideIcons.shieldAlert;
      case 'severe':
        return LucideIcons.triangleAlert;
      case 'moderate':
        return LucideIcons.info;
      default:
        return LucideIcons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert History'),
        actions: [
          if (_alerts.isNotEmpty)
            IconButton(
              icon: const Icon(LucideIcons.trash2),
              onPressed: _clearHistory,
              tooltip: 'Clear History',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alerts.isEmpty
          ? _buildEmptyState()
          : _buildAlertList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.bellOff,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const Gap(16),
          Text(
            'No Alert History',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Gap(8),
          Text(
            'Weather alerts will appear here when received',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertList() {
    // Group alerts by date
    final Map<String, List<AlertHistory>> groupedAlerts = {};
    final dateFormat = DateFormat('EEEE, MMMM d, y');

    for (var alert in _alerts) {
      final dateKey = dateFormat.format(alert.timestamp);
      groupedAlerts.putIfAbsent(dateKey, () => []).add(alert);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedAlerts.length,
      itemBuilder: (context, index) {
        final dateKey = groupedAlerts.keys.elementAt(index);
        final alertsForDate = groupedAlerts[dateKey]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                dateKey,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...alertsForDate.map((alert) => _buildAlertCard(alert)),
            const Gap(8),
          ],
        );
      },
    );
  }

  Widget _buildAlertCard(AlertHistory alert) {
    final color = _getSeverityColor(alert.severity);
    final icon = _getSeverityIcon(alert.severity);
    final timeFormat = DateFormat('h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showAlertDetails(alert),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 24),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              alert.event,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            timeFormat.format(alert.timestamp),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                          ),
                        ],
                      ),
                      const Gap(4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          alert.severity.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      if (alert.description != null) ...[
                        const Gap(8),
                        Text(
                          alert.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(AlertHistory alert) {
    final color = _getSeverityColor(alert.severity);
    final dateFormat = DateFormat('EEEE, MMMM d, y \'at\' h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    _getSeverityIcon(alert.severity),
                    color: color,
                    size: 32,
                  ),
                  const Gap(12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.event,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Gap(4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            alert.severity.toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Gap(16),
              Text(
                dateFormat.format(alert.timestamp),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const Gap(8),
              Text(
                'Location: ${alert.lat.toStringAsFixed(4)}, ${alert.lon.toStringAsFixed(4)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const Gap(20),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (alert.description != null) ...[
                        Text(
                          'Description',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Gap(8),
                        Text(
                          alert.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const Gap(16),
                      ],
                      if (alert.startTime != null || alert.endTime != null) ...[
                        Text(
                          'Duration',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const Gap(8),
                        if (alert.startTime != null)
                          Text(
                            'Start: ${dateFormat.format(alert.startTime!)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (alert.endTime != null)
                          Text(
                            'End: ${dateFormat.format(alert.endTime!)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
