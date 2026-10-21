// Supabase database access.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_form.dart';
import '../models/attendance_record.dart';
import '../models/person.dart';
import '../models/dashboard_trend.dart';

// All database operations have a bounded wait and a readable debug log.
class ApiService {
  ApiService({SupabaseClient? client}) : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;
  static const int pageSize = 500;
  static const Duration requestTimeout = Duration(seconds: 20);

  // Common request wrapper: log, time out, and rethrow errors to controller.
  Future<T> _run<T>(String action, Future<T> Function() operation) async {
    final watch = Stopwatch()..start();
    if (kDebugMode) debugPrint('[Attendance API] START $action');
    try {
      final result = await operation().timeout(requestTimeout);
      if (kDebugMode) {
        debugPrint('[Attendance API] OK $action (${watch.elapsedMilliseconds} ms)');
      }
      return result;
    } on TimeoutException {
      if (kDebugMode) debugPrint('[Attendance API] TIMEOUT $action (20 seconds)');
      throw TimeoutException(
        '$action took longer than 20 seconds. Check internet access on the '
        'emulator and your Supabase project status. If this was a save, '
        'refresh the sheet before trying again to avoid duplicates.',
        requestTimeout,
      );
    } catch (error) {
      if (kDebugMode) debugPrint('[Attendance API] FAILED $action: $error');
      rethrow;
    } finally {
      watch.stop();
    }
  }

  // --- Attendance folders ---
  // Fetch every page. PostgREST limits the number of rows per response.
  Future<List<AttendanceForm>> fetchUserForms(String userId) async {
    final all = <AttendanceForm>[];
    for (var offset = 0;; offset += pageSize) {
      final rows = await _run('Load sheets (page ${offset ~/ pageSize + 1})', () =>
          _supabase
              .from('attendance_forms')
              .select()
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .order('id')
              .range(offset, offset + pageSize - 1));
      all.addAll(rows.map(AttendanceForm.fromSupabase));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  Future<AttendanceForm> createForm(AttendanceForm form) async {
    final row = await _run('Create sheet', () => _supabase
        .from('attendance_forms')
        .insert(form.toSupabase())
        .select()
        .single());
    return AttendanceForm.fromSupabase(row);
  }

  Future<AttendanceForm> updateForm(AttendanceForm form) async {
    if (form.id == null) throw StateError('Sheet ID is missing.');
    final values = form.toSupabase()
      ..remove('id')
      ..remove('user_id');
    final row = await _run('Update sheet', () => _supabase
        .from('attendance_forms').update(values).eq('id', form.id!).select().single());
    return AttendanceForm.fromSupabase(row);
  }

  Future<void> deleteForm(String formId) async {
    await _run('Delete sheet', () => _supabase
        .from('attendance_forms').delete().eq('id', formId));
  }

  Future<Person> updatePerson(Person person) async {
    if (person.id == null) throw StateError('Person ID is missing.');
    final values = person.toSupabase()
      ..remove('id')
      ..remove('form_id');
    final row = await _run('Update person', () => _supabase
        .from('persons').update(values).eq('id', person.id!).select().single());
    return Person.fromSupabase(row);
  }

  Future<void> deletePerson(String id) async {
    await _run('Delete person', () => _supabase
        .from('persons').delete().eq('id', id));
  }

  // --- Dashboard ---
  // Retrieve dated counts using the read-only v10 SQL aggregate function.
  Future<DashboardTrendReport> fetchDashboardTrend({
    required String? sheetId,
    required DateTime start,
    required DateTime end,
  }) async {
    final result = await _run('Load attendance trend', () =>
        _supabase.rpc('attendance_dashboard_trend', params: {
          'p_sheet_id': sheetId,
          'p_start_date': AttendanceRecord.dateOnly(start),
          'p_end_date': AttendanceRecord.dateOnly(end),
        }));
    if (result is! List) {
      throw const FormatException('Invalid dashboard trend response.');
    }
    return DashboardTrendReport.fromRows(result);
  }

  // --- People and attendance records ---
  // Fetch members page-by-page to avoid silently missing large classes.
  Future<List<Person>> fetchPersons(String formId) async {
    final all = <Person>[];
    for (var offset = 0;; offset += pageSize) {
      final rows = await _run('Load students/employees (page ${offset ~/ pageSize + 1})', () =>
          _supabase
              .from('persons')
              .select()
              .eq('form_id', formId)
              .order('name')
              .order('id')
              .range(offset, offset + pageSize - 1));
      all.addAll(rows.map(Person.fromSupabase));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  Future<Person> addPerson(Person person) async {
    final row = await _run('Add student/employee', () => _supabase
        .from('persons')
        .insert(person.toSupabase())
        .select()
        .single());
    return Person.fromSupabase(row);
  }

  // Load all record pages for the selected sheet.
  Future<List<AttendanceRecord>> fetchRecords(String formId) async {
    final all = <AttendanceRecord>[];
    for (var offset = 0;; offset += pageSize) {
      final rows = await _run('Load attendance records (page ${offset ~/ pageSize + 1})', () =>
          _supabase
              .from('attendance_records')
              .select('id,person_id,date,status,time_in,time_out,persons!inner(form_id)')
              .eq('persons.form_id', formId)
              .order('person_id')
              .order('date')
              .range(offset, offset + pageSize - 1));
      all.addAll(rows.map(AttendanceRecord.fromSupabase));
      if (rows.length < pageSize) break;
    }
    return all;
  }

  Future<AttendanceRecord> saveOrUpdateRecord(AttendanceRecord record) async {
    final row = await _run('Save attendance', () => _supabase
        .from('attendance_records')
        .upsert(record.toSupabase(), onConflict: 'person_id,date')
        .select()
        .single());
    return AttendanceRecord.fromSupabase(row);
  }

  Future<void> deleteRecord(String personId, DateTime date) async {
    await _run('Clear attendance', () => _supabase
        .from('attendance_records')
        .delete()
        .eq('person_id', personId)
        .eq('date', AttendanceRecord.dateOnly(date)));
  }
}
