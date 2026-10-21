// Database data models.
// Read-only dashboard totals returned by the `attendance_dashboard` RPC.
class DashboardSummary {
  const DashboardSummary({
    required this.sheets,
    required this.people,
    required this.present,
    required this.absent,
    required this.late,
  });

  final int sheets;
  final int people;
  final int present;
  final int absent;
  final int late;

  int get marked => present + absent + late;
  double? get rate => marked == 0 ? null : (present + late) * 100 / marked;

  factory DashboardSummary.fromJson(Map<String, dynamic> value) {
    int number(String name) => (value[name] as num?)?.toInt() ?? 0;
    return DashboardSummary(
      sheets: number('sheets'),
      people: number('people'),
      present: number('present'),
      absent: number('absent'),
      late: number('late'),
    );
  }
}
