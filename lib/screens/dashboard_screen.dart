// Attendance dashboard: sheet scope, calendar filters, and trend chart.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../models/attendance_form.dart';
import '../models/dashboard_trend.dart';
import '../widgets/attendance_trend_chart.dart';
import '../widgets/dashboard_sheet_picker.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.controller});

  final AttendanceController controller;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardPeriod _period = DashboardPeriod.week;
  String? _sheetId; // null means All Sheets.
  late DashboardCalendar _calendar;
  late Future<DashboardTrendReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) _load();
  }

  // Refresh the date bounds and request aggregated attendance counts.
  void _load() {
    _calendar = DashboardCalendar(_period, DateTime.now());
    _reportFuture = widget.controller.loadDashboardTrend(
      sheetId: _sheetId,
      start: _calendar.start,
      end: _calendar.queryEnd,
    );
  }

  Future<void> _refresh() async {
    setState(_load);
    try {
      await _reportFuture;
    } catch (_) {
      // FutureBuilder displays the error and Retry action.
    }
  }

  // Change the period without changing the selected sheet.
  void _setPeriod(DashboardPeriod period) {
    if (_period == period) return;
    setState(() {
      _period = period;
      _load();
    });
  }

  // Open the searchable sheet selector.
  Future<void> _pickSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        final availableHeight = media.size.height - media.viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: SizedBox(
            height: availableHeight * 0.65,
            child: DashboardSheetPicker(
              forms: widget.controller.forms,
              selectedSheetId: _sheetId,
            ),
          ),
        );
      },
    );
    if (!mounted || result == null) return;
    final next = result == dashboardAllSheetsSelection ? null : result;
    if (next == _sheetId) return;
    setState(() {
      _sheetId = next;
      _load();
    });
  }

  AttendanceForm? get _selectedSheet {
    for (final form in widget.controller.forms) {
      if (form.id == _sheetId) return form;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _selectedSheet;
    final scopeName =
        _sheetId == null ? 'All Sheets' : (selected?.title ?? 'Selected sheet');
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text('Dashboard',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Attendance overview and performance',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 22),
          Text('View statistics for', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          // Searchable scope filter; uses sheet IDs rather than names.
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: Icon(_sheetId == null
                  ? Icons.layers_outlined
                  : Icons.folder_outlined),
              title: Text(scopeName),
              subtitle: Text(_sheetId == null
                  ? 'Combined attendance data'
                  : (selected?.entityLabel ?? 'Individual attendance sheet')),
              trailing: const Icon(Icons.keyboard_arrow_down),
              onTap: _pickSheet,
            ),
          ),
          const SizedBox(height: 20),
          Text('Attendance trend period', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            // Smaller phones wrap the filters to avoid horizontal overflow.
            if (constraints.maxWidth < 340) {
              return Wrap(spacing: 6, children: [
                for (final choice in DashboardPeriod.values)
                  ChoiceChip(
                    label:
                        Text(DashboardCalendar(choice, DateTime.now()).heading),
                    selected: _period == choice,
                    onSelected: (_) => _setPeriod(choice),
                  ),
              ]);
            }
            return SegmentedButton<DashboardPeriod>(
              segments: const [
                ButtonSegment(
                    value: DashboardPeriod.week, label: Text('This Week')),
                ButtonSegment(
                    value: DashboardPeriod.month, label: Text('This Month')),
                ButtonSegment(
                    value: DashboardPeriod.year, label: Text('This Year')),
              ],
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: (value) => _setPeriod(value.first),
            );
          }),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.calendar_today_outlined, size: 15),
            const SizedBox(width: 8),
            Text(_calendar.rangeLabel, style: theme.textTheme.bodySmall),
          ]),
          const SizedBox(height: 22),
          FutureBuilder<DashboardTrendReport>(
            future: _reportFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(42),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Card(
                    child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Unable to load dashboard statistics.'),
                      const SizedBox(height: 8),
                      const Text(
                          'Run supabase/migrations/20261015_v10_dashboard_trends.sql '
                          'in your existing Supabase SQL Editor.'),
                      const SizedBox(height: 8),
                      Text(AttendanceController.friendlyError(snapshot.error!),
                          style: theme.textTheme.bodySmall),
                      TextButton(
                          onPressed: _refresh, child: const Text('Retry')),
                    ],
                  ),
                ));
              }
              final report = snapshot.data!;
              final points = _calendar.group(report.days);
              final present = points.fold<int>(0, (sum, p) => sum + p.present);
              final late = points.fold<int>(0, (sum, p) => sum + p.late);
              final absent = points.fold<int>(0, (sum, p) => sum + p.absent);
              final marked = present + late + absent;
              final rate = marked == 0 ? null : (present + late) * 100 / marked;
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        _sheetId == null
                            ? 'Overall Statistics'
                            : '$scopeName Statistics',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                        '${_sheetId == null ? 'All attendance sheets' : '$scopeName only'} '
                        '· ${_calendar.heading}',
                        style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    // Compact overview: context, recorded statuses, and rate.
                    LayoutBuilder(builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 370 ? 3 : 2;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(spacing: 10, runSpacing: 10, children: [
                        _metric(
                            width,
                            _sheetId == null
                                ? Icons.folder_outlined
                                : Icons.people_outline,
                            _sheetId == null ? 'Sheets' : 'People',
                            '${_sheetId == null ? report.sheets : report.people}'),
                        _metric(width, Icons.assignment_turned_in_outlined,
                            'Records', '$marked'),
                        _metric(width, Icons.trending_up, 'Attendance rate',
                            rate == null ? '—' : '${rate.toStringAsFixed(1)}%'),
                      ]);
                    }),
                    const SizedBox(height: 20),
                    // Status distribution appears only once on the dashboard.
                    Card(
                        child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Attendance Breakdown',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 18),
                            Row(children: [
                              _statusStat(
                                  'Present', present, const Color(0xff2d985f)),
                              _statusStat(
                                  'Late', late, const Color(0xffd49c37)),
                              _statusStat(
                                  'Absent', absent, const Color(0xffd85a5a)),
                            ]),
                            const SizedBox(height: 16),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  height: 9,
                                  child: Row(children: [
                                    if (marked > 0) ...[
                                      if (present > 0)
                                        Expanded(
                                            flex: present,
                                            child: Container(
                                                color:
                                                    const Color(0xff2d985f))),
                                      if (late > 0)
                                        Expanded(
                                            flex: late,
                                            child: Container(
                                                color:
                                                    const Color(0xffd49c37))),
                                      if (absent > 0)
                                        Expanded(
                                            flex: absent,
                                            child: Container(
                                                color:
                                                    const Color(0xffd85a5a))),
                                    ] else
                                      Expanded(
                                          child: Container(
                                              color: theme.dividerColor)),
                                  ])),
                            ),
                          ]),
                    )),
                    const SizedBox(height: 20),
                    // Trend graph: days this week, weeks this month, months this year.
                    Card(
                        child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Attendance Trend',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(_calendar.grouping,
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 14),
                            AttendanceTrendChart(points: points),
                          ]),
                    )),
                  ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _metric(double width, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return SizedBox(
        width: width,
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: theme.colorScheme.primary, size: 22),
              const SizedBox(height: 12),
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(label,
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ));
  }

  Widget _statusStat(String name, int value, Color color) => Expanded(
        child: Column(children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: color,
            child: Text('$value',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 6),
          Text(name, style: Theme.of(context).textTheme.bodySmall),
        ]),
      );
}
