// Dashboard trend data and calendar grouping.

// Calendar periods available in the dashboard.
enum DashboardPeriod { week, month, year }

// Attendance totals for one calendar day.
class DailyAttendanceTotal {
  const DailyAttendanceTotal({
    required this.date,
    required this.present,
    required this.late,
    required this.absent,
  });

  final DateTime date;
  final int present;
  final int late;
  final int absent;

  int get recorded => present + late + absent;

  factory DailyAttendanceTotal.fromJson(Map<String, dynamic> json) =>
      DailyAttendanceTotal(
        date: DateTime.parse(json['attendance_date'].toString()),
        present: (json['present_count'] as num?)?.toInt() ?? 0,
        late: (json['late_count'] as num?)?.toInt() ?? 0,
        absent: (json['absent_count'] as num?)?.toInt() ?? 0,
      );
}

// Overview counts and the dated attendance totals from Supabase.
class DashboardTrendReport {
  const DashboardTrendReport({
    required this.sheets,
    required this.people,
    required this.days,
  });

  final int sheets;
  final int people;
  final List<DailyAttendanceTotal> days;

  // The RPC also returns one counts-only row when there are no attendance records.
  factory DashboardTrendReport.fromRows(List<dynamic> rows) {
    if (rows.isEmpty) {
      throw const FormatException('Dashboard returned no scope information.');
    }
    final first = Map<String, dynamic>.from(rows.first as Map);
    final days = <DailyAttendanceTotal>[];
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw as Map);
      if (row['attendance_date'] != null) {
        days.add(DailyAttendanceTotal.fromJson(row));
      }
    }
    return DashboardTrendReport(
      sheets: (first['sheets'] as num?)?.toInt() ?? 0,
      people: (first['people'] as num?)?.toInt() ?? 0,
      days: days,
    );
  }
}

// One point in the trend chart (a day, a week, or a month).
class AttendanceTrendPoint {
  const AttendanceTrendPoint({
    required this.label,
    required this.description,
    required this.present,
    required this.late,
    required this.absent,
  });

  final String label;
  final String description;
  final int present;
  final int late;
  final int absent;

  int get recorded => present + late + absent;
  double? get rate => recorded == 0 ? null : (present + late) * 100 / recorded;
}

// Date bounds, point labels, and grouping for the selected period.
class DashboardCalendar {
  DashboardCalendar(DashboardPeriod period, DateTime now)
      : period = period,
        today = DateTime(now.year, now.month, now.day);

  final DashboardPeriod period;
  final DateTime today;

  DateTime get start {
    switch (period) {
      case DashboardPeriod.week:
        return DateTime(today.year, today.month, today.day - today.weekday + 1);
      case DashboardPeriod.month:
        return DateTime(today.year, today.month, 1);
      case DashboardPeriod.year:
        return DateTime(today.year, 1, 1);
    }
  }

  DateTime get end {
    switch (period) {
      case DashboardPeriod.week:
        return DateTime(start.year, start.month, start.day + 6);
      case DashboardPeriod.month:
        return DateTime(today.year, today.month + 1, 0);
      case DashboardPeriod.year:
        return DateTime(today.year, 12, 31);
    }
  }

  // Future days are never included in a Supabase trend query.
  DateTime get queryEnd => today.isBefore(end) ? today : end;

  String get heading {
    switch (period) {
      case DashboardPeriod.week:
        return 'This Week';
      case DashboardPeriod.month:
        return 'This Month';
      case DashboardPeriod.year:
        return 'This Year';
    }
  }

  String get grouping {
    switch (period) {
      case DashboardPeriod.week:
        return 'Daily · Monday to Sunday';
      case DashboardPeriod.month:
        return 'Weekly · Monday-based calendar weeks';
      case DashboardPeriod.year:
        return 'Monthly · January to December';
    }
  }

  String get rangeLabel {
    final year = today.year;
    switch (period) {
      case DashboardPeriod.week:
        return '${_shortDate(start)}, ${start.year} – ${_shortDate(end)}, ${end.year}';
      case DashboardPeriod.month:
        return '${_monthNames[today.month - 1]} $year';
      case DashboardPeriod.year:
        return '$year';
    }
  }

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _shortDate(DateTime day) => '${_monthNames[day.month - 1]} ${day.day}';

  // Aggregate daily database counts into chart points without filling missing dates as 0%.
  List<AttendanceTrendPoint> group(List<DailyAttendanceTotal> days) {
    final buckets = <List<DailyAttendanceTotal>>[];
    final labels = <String>[];
    final descriptions = <String>[];

    if (period == DashboardPeriod.week) {
      for (var i = 0; i < 7; i++) {
        final date = DateTime(start.year, start.month, start.day + i);
        buckets.add([]);
        labels.add(_weekdays[i]);
        descriptions.add('${_weekdays[i]}, ${_shortDate(date)}');
      }
    } else if (period == DashboardPeriod.month) {
      final firstWeekday = start.weekday;
      final daysInMonth = end.day;
      final weekCount = ((daysInMonth + firstWeekday - 2) ~/ 7) + 1;
      for (var i = 0; i < weekCount; i++) {
        final fromDay = i == 0 ? 1 : i * 7 - firstWeekday + 2;
        final throughDay = (i + 1) * 7 - firstWeekday + 1;
        final toDay = throughDay > daysInMonth ? daysInMonth : throughDay;
        buckets.add([]);
        labels.add('W${i + 1}');
        descriptions.add('${_monthNames[today.month - 1]} $fromDay–$toDay');
      }
    } else {
      for (var i = 0; i < 12; i++) {
        buckets.add([]);
        labels.add(_monthNames[i]);
        descriptions.add('${_monthNames[i]} ${today.year}');
      }
    }

    for (final day in days) {
      final date = DateTime(day.date.year, day.date.month, day.date.day);
      if (date.isBefore(start) || date.isAfter(queryEnd)) continue;
      int index;
      switch (period) {
        case DashboardPeriod.week:
          index = date.weekday - 1;
          break;
        case DashboardPeriod.month:
          index = (date.day + start.weekday - 2) ~/ 7;
          break;
        case DashboardPeriod.year:
          index = date.month - 1;
          break;
      }
      buckets[index].add(day);
    }

    return List.generate(buckets.length, (i) {
      final entries = buckets[i];
      return AttendanceTrendPoint(
        label: labels[i],
        description: descriptions[i],
        present: entries.fold(0, (sum, day) => sum + day.present),
        late: entries.fold(0, (sum, day) => sum + day.late),
        absent: entries.fold(0, (sum, day) => sum + day.absent),
      );
    });
  }
}
