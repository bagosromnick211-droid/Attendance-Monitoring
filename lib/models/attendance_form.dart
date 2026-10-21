// Database data models.
// A sheet/folder record as stored in `attendance_forms`.
class AttendanceForm {
  final String? id;
  final String userId;
  final String title;
  final String entityLabel;
  final bool includeTimeIn;
  final bool includeTimeOut;
  final DateTime startDate;
  final DateTime endDate;
  final bool ignoreWeekends;

  AttendanceForm({
    this.id,
    required this.userId,
    required this.title,
    this.entityLabel = 'Person',
    this.includeTimeIn = true,
    this.includeTimeOut = true,
    required this.startDate,
    required this.endDate,
    this.ignoreWeekends = true,
  });

  AttendanceForm copyWith({
    String? title,
    String? entityLabel,
    bool? includeTimeIn,
    bool? includeTimeOut,
    DateTime? startDate,
    DateTime? endDate,
    bool? ignoreWeekends,
  }) => AttendanceForm(
    id: id,
    userId: userId,
    title: title ?? this.title,
    entityLabel: entityLabel ?? this.entityLabel,
    includeTimeIn: includeTimeIn ?? this.includeTimeIn,
    includeTimeOut: includeTimeOut ?? this.includeTimeOut,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    ignoreWeekends: ignoreWeekends ?? this.ignoreWeekends,
  );

  Map<String, dynamic> toSupabase() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'title': title.trim(),
        'entity_label': entityLabel.trim(),
        'include_time_in': includeTimeIn,
        'include_time_out': includeTimeOut,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'ignore_weekends': ignoreWeekends,
      };

  factory AttendanceForm.fromSupabase(Map<String, dynamic> json) {
    return AttendanceForm(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      entityLabel: json['entity_label']?.toString() ?? 'Person',
      includeTimeIn: json['include_time_in'] as bool? ?? true,
      includeTimeOut: json['include_time_out'] as bool? ?? true,
      startDate: DateTime.parse(json['start_date'].toString()),
      endDate: DateTime.parse(json['end_date'].toString()),
      ignoreWeekends: json['ignore_weekends'] as bool? ?? true,
    );
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
