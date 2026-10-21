// Database data models.
// An unmarked attendance cell is represented by NO database row (null status).
// 'noClass' is an explicit user selection, not the absence of attendance.
enum AttendanceStatus { present, late, absent, noClass }

// One person's attendance for a date, optionally with in/out times.
class AttendanceRecord {
  final String? id;
  final String personId;
  final DateTime date;
  final AttendanceStatus status;
  final String? timeIn;
  final String? timeOut;

  AttendanceRecord({
    this.id,
    required this.personId,
    required this.date,
    required this.status,
    this.timeIn,
    this.timeOut,
  });

  // Convert Dart fields to Supabase snake_case database column names.
  Map<String, dynamic> toSupabase() => {
        // Never send the existing ID in the upsert: the unique constraint
        // (person_id, date) is the conflict key for both new and old records.
        'person_id': personId,
        'date': dateOnly(date),
        'status': status.name,
        'time_in': status == AttendanceStatus.noClass ? null : timeIn,
        'time_out': status == AttendanceStatus.noClass ? null : timeOut,
      };

  // Parse PostgREST JSON into a strongly typed Dart object.
  factory AttendanceRecord.fromSupabase(Map<String, dynamic> json) =>
      AttendanceRecord(
        id: json['id']?.toString(),
        personId: json['person_id']?.toString() ?? '',
        date: DateTime.parse(json['date'].toString()),
        status: AttendanceStatus.values.firstWhere(
          (status) => status.name == json['status'],
          orElse: () => throw FormatException('Unknown attendance status: ${json['status']}'),
        ),
        timeIn: json['time_in']?.toString(),
        timeOut: json['time_out']?.toString(),
      );

  static String dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
