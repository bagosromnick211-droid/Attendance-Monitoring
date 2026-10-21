// Application state and actions.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/attendance_form.dart';
import '../models/attendance_record.dart';
import '../models/person.dart';
import '../models/dashboard_trend.dart';
import '../services/api_services.dart';
import '../utils/date_utils.dart';

// Owns sheet, member, and attendance state shared across screens.
class AttendanceController extends ChangeNotifier {
  AttendanceController({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  final ApiService _apiService;
  AttendanceForm? _currentForm;
  List<AttendanceForm> _forms = [];
  List<Person> _persons = [];
  final Map<String, Map<DateTime, AttendanceRecord>> _records = {};
  final Set<String> _savingCells = {};
  String _searchQuery = '';
  String? _groupFilter;
  bool _isLoading = false;
  String? _errorMessage;
  // Incremented when switching sheets/accounts so older HTTP results are ignored.
  int _stateEpoch = 0;

  // --- Read-only state exposed to the UI ---
  AttendanceForm? get currentForm => _currentForm;
  List<AttendanceForm> get forms => List.unmodifiable(_forms);
  String get searchQuery => _searchQuery;
  String? get groupFilter => _groupFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get memberCount => _persons.length;
  List<Person> get persons => List.unmodifiable(_persons);
  // Load dashboard totals for the chosen sheet and date period.
  Future<DashboardTrendReport> loadDashboardTrend({
    required String? sheetId,
    required DateTime start,
    required DateTime end,
  }) => _apiService.fetchDashboardTrend(sheetId: sheetId, start: start, end: end);

  set searchQuery(String val) {
    _searchQuery = val;
    notifyListeners();
  }

  set groupFilter(String? value) {
    _groupFilter = value;
    notifyListeners();
  }

  // --- Search, filters, and calendar columns ---
  // Group names available for the current sheet's filter menu.
  List<String> get groups {
    final all = _persons.map((p) => p.groupName).whereType<String>().toSet().toList();
    all.sort();
    return all;
  }

  List<Person> get filteredPersons {
    final query = _searchQuery.trim().toLowerCase();
    return _persons.where((person) {
      if (_groupFilter != null && person.groupName != _groupFilter) return false;
      return query.isEmpty ||
          person.name.toLowerCase().contains(query) ||
          (person.memberCode?.toLowerCase().contains(query) ?? false) ||
          (person.groupName?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  // Inclusive date range.
  List<DateTime> get dateColumns {
    if (_currentForm == null) return [];
    final list = <DateTime>[];
    var curr = _normalize(_currentForm!.startDate);
    final end = _normalize(_currentForm!.endDate);
    while (!curr.isAfter(end)) {
      if (!_currentForm!.ignoreWeekends ||
          (curr.weekday != DateTime.saturday && curr.weekday != DateTime.sunday)) {
        list.add(curr);
      }
      // DateTime(y, m, d+1) avoids DST changes caused by Duration(days: 1).
      curr = DateTime(curr.year, curr.month, curr.day + 1);
    }
    return list;
  }

  // --- Folder lifecycle ---
  // Fetch folders belonging to a user, with a retryable error message.
  Future<void> loadUserForms(String userId) async {
    if (userId.trim().isEmpty) {
      clearUserState();
      return;
    }
    final requestEpoch = _stateEpoch;
    _setLoading(true);
    _errorMessage = null;
    try {
      final loaded = await _apiService.fetchUserForms(userId);
      if (requestEpoch != _stateEpoch) return;
      _forms = loaded;
    } catch (error) {
      if (requestEpoch != _stateEpoch) return;
      _errorMessage = friendlyError(error);
      rethrow;
    } finally {
      if (requestEpoch == _stateEpoch) _setLoading(false);
    }
  }

  Future<void> createForm(AttendanceForm form) async {
    if (form.userId.trim().isEmpty) {
      throw StateError('Sign in before creating a sheet.');
    }
    if (form.title.trim().isEmpty) {
      throw ArgumentError('Sheet title cannot be empty.');
    }
    if (form.endDate.isBefore(form.startDate) ||
        DateTime.utc(form.endDate.year, form.endDate.month, form.endDate.day)
                .difference(DateTime.utc(form.startDate.year, form.startDate.month, form.startDate.day))
                .inDays > 366) {
      throw ArgumentError('Choose a date range of at most 367 calendar days.');
    }
    final requestEpoch = _stateEpoch;
    _setLoading(true);
    _errorMessage = null;
    try {
      final created = await _apiService.createForm(form);
      if (requestEpoch != _stateEpoch) return;
      _currentForm = created;
      _forms.removeWhere((item) => item.id == created.id);
      _forms.insert(0, created);
      _persons = [];
      _records.clear();
      _savingCells.clear();
      _searchQuery = '';
      _groupFilter = null;
    } catch (error) {
      if (requestEpoch != _stateEpoch) return;
      _errorMessage = friendlyError(error);
      rethrow;
    } finally {
      if (requestEpoch == _stateEpoch) _setLoading(false);
    }
  }

  // Load members and records together (two independent Supabase queries).
  Future<void> loadFormDetails(AttendanceForm form) async {
    if (form.id == null || form.id!.isEmpty) {
      throw StateError('This sheet does not have a valid ID.');
    }
    final requestEpoch = _stateEpoch;
    _setLoading(true);
    _errorMessage = null;
    try {
      // Both queries are independent. Fetching them in parallel shortens the
      // wait and lets the debug console identify which request is slow.
      final results = await Future.wait<Object>([
        _apiService.fetchPersons(form.id!),
        _apiService.fetchRecords(form.id!),
      ]);
      final people = results[0] as List<Person>;
      final allRecords = results[1] as List<AttendanceRecord>;
      if (requestEpoch != _stateEpoch) return;
      _currentForm = form;
      _persons = people;
      _records.clear();
      _savingCells.clear();
      for (final record in allRecords) {
        _records.putIfAbsent(record.personId, () => {})[_normalize(record.date)] = record;
      }
      _searchQuery = '';
      _groupFilter = null;
    } catch (error) {
      if (requestEpoch != _stateEpoch) return;
      _errorMessage = friendlyError(error);
      rethrow;
    } finally {
      if (requestEpoch == _stateEpoch) _setLoading(false);
    }
  }

  // Invalidate outstanding responses when leaving a sheet.
  void resetForm() {
    _stateEpoch++;
    _currentForm = null;
    _persons = [];
    _records.clear();
    _savingCells.clear();
    _searchQuery = '';
    _groupFilter = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // Flush cached data when the signed-in account changes.
  void clearUserState() {
    _stateEpoch++;
    _currentForm = null;
    _forms = [];
    _persons = [];
    _records.clear();
    _savingCells.clear();
    _searchQuery = '';
    _groupFilter = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  static void validateForm(AttendanceForm form) {
    if (form.title.trim().isEmpty || form.title.trim().length > 150) {
      throw ArgumentError('Enter a sheet name up to 150 characters.');
    }
    if (form.entityLabel.trim().isEmpty || form.entityLabel.trim().length > 60) {
      throw ArgumentError('Enter a person label up to 60 characters.');
    }
    final start = DateTime.utc(form.startDate.year, form.startDate.month, form.startDate.day);
    final end = DateTime.utc(form.endDate.year, form.endDate.month, form.endDate.day);
    if (end.isBefore(start) || end.difference(start).inDays > 366) {
      throw ArgumentError('Choose a date range of at most 367 calendar days.');
    }
  }

  Future<AttendanceForm> updateForm(AttendanceForm changes) async {
    if (changes.id == null) throw StateError('Sheet ID is missing.');
    validateForm(changes);
    final epoch = _stateEpoch;
    final result = await _apiService.updateForm(changes);
    if (epoch == _stateEpoch) {
      final index = _forms.indexWhere((f) => f.id == result.id);
      if (index >= 0) _forms[index] = result;
      if (_currentForm?.id == result.id) _currentForm = result;
      _errorMessage = null;
      notifyListeners();
    }
    return result;
  }

  Future<void> deleteForm(String formId) async {
    final epoch = _stateEpoch;
    await _apiService.deleteForm(formId);
    if (epoch != _stateEpoch) return;
    _forms.removeWhere((f) => f.id == formId);
    if (_currentForm?.id == formId) resetForm();
    notifyListeners();
  }

  // --- Member lifecycle ---
  // Edit a member without changing their database ID or attendance history.
  Future<void> editPerson(Person person) async {
    if (person.id == null || person.formId != _currentForm?.id) {
      throw StateError('Open the correct sheet before editing a person.');
    }
    final trimmed = person.name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name is required.');
    final epoch = _stateEpoch;
    final formId = _currentForm!.id;
    final saved = await _apiService.updatePerson(person);
    if (epoch != _stateEpoch || _currentForm?.id != formId) return;
    final index = _persons.indexWhere((p) => p.id == saved.id);
    if (index >= 0) _persons[index] = saved;
    _persons.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
  }

  Future<void> deletePerson(Person person) async {
    if (person.id == null || person.formId != _currentForm?.id) {
      throw StateError('Open the correct sheet before deleting a person.');
    }
    final epoch = _stateEpoch;
    final formId = _currentForm!.id;
    await _apiService.deletePerson(person.id!);
    if (epoch != _stateEpoch || _currentForm?.id != formId) return;
    _persons.removeWhere((p) => p.id == person.id);
    _records.remove(person.id);
    _savingCells.removeWhere((key) => key.startsWith('${person.id}:'));
    notifyListeners();
  }

  // Insert a member.
  Future<void> addPerson(String name, {String? memberCode, String? groupName}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError('Name cannot be empty.');
    if (_currentForm?.id == null) throw StateError('Open a sheet first.');
    final requestEpoch = _stateEpoch;
    final formId = _currentForm!.id!;
    final person = Person(
      formId: formId,
      name: trimmed,
      memberCode: memberCode,
      groupName: groupName,
    );
    try {
      final saved = await _apiService.addPerson(person);
      if (requestEpoch != _stateEpoch || _currentForm?.id != formId) return;
      _persons.add(saved);
      _persons.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (saved.id != null) _records[saved.id!] = {};
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      if (requestEpoch != _stateEpoch) return;
      _errorMessage = friendlyError(error);
      notifyListeners();
      rethrow;
    }
  }

  DateTime _normalize(DateTime date) => calendarDate(date);
  String _cellKey(String personId, DateTime date) => '$personId:${AttendanceRecord.dateOnly(date)}';

  // --- Attendance cells ---
  // A missing record means Unmarked.
  AttendanceRecord? getRecord(String personId, DateTime date) =>
      _records[personId]?[_normalize(date)];

  AttendanceStatus? getStatus(String personId, DateTime date) =>
      getRecord(personId, date)?.status;

  bool isSavingCell(String personId, DateTime date) =>
      _savingCells.contains(_cellKey(personId, date));

  void _ensureEditable(String personId, DateTime date) {
    if (_currentForm == null || !_persons.any((p) => p.id == personId)) {
      throw StateError('This person is not in the currently open sheet.');
    }
    if (!dateColumns.contains(_normalize(date))) {
      throw StateError('This date is outside the attendance period.');
    }
    if (isSavingCell(personId, date)) {
      throw StateError('This attendance cell is still saving.');
    }
  }

  // Update a status, or delete the row when clearing back to Unmarked.
  Future<void> updateStatus(String personId, DateTime date, AttendanceStatus? status) async {
    _ensureEditable(personId, date);
    final current = getRecord(personId, date);
    if (current?.status == status) return;
    final next = status == null
        ? null
        : AttendanceRecord(
            id: current?.id,
            personId: personId,
            date: _normalize(date),
            status: status,
            timeIn: (status == AttendanceStatus.present || status == AttendanceStatus.late)
                ? current?.timeIn : null,
            timeOut: (status == AttendanceStatus.present || status == AttendanceStatus.late)
                ? current?.timeOut : null,
          );
    await _saveCell(personId, date, next);
  }

  Future<void> updateTimes(String personId, DateTime date, {String? timeIn, String? timeOut}) async {
    _ensureEditable(personId, date);
    final previous = getRecord(personId, date);
    if (previous == null ||
        (previous.status != AttendanceStatus.present &&
            previous.status != AttendanceStatus.late)) {
      throw StateError('Mark Present or Late before adding times.');
    }
    final form = _currentForm!;
    final updated = AttendanceRecord(
      id: previous.id,
      personId: personId,
      date: _normalize(date),
      status: previous.status,
      // Keep previously stored values when a time option is disabled.
      timeIn: form.includeTimeIn ? timeIn : previous.timeIn,
      timeOut: form.includeTimeOut ? timeOut : previous.timeOut,
    );
    await _saveCell(personId, date, updated);
  }

  // One in-flight operation per person/date. While saving the cell is disabled.
  Future<void> _saveCell(String personId, DateTime date, AttendanceRecord? next) async {
    final norm = _normalize(date);
    final key = _cellKey(personId, norm);
    final epoch = _stateEpoch;
    final old = _records[personId]?[norm];
    _savingCells.add(key);
    _records.putIfAbsent(personId, () => {});
    if (next == null) {
      _records[personId]!.remove(norm);
    } else {
      _records[personId]![norm] = next;
    }
    notifyListeners();
    try {
      if (next == null) {
        await _apiService.deleteRecord(personId, norm);
      } else {
        final saved = await _apiService.saveOrUpdateRecord(next);
        if (epoch == _stateEpoch) _records[personId]![norm] = saved;
      }
      if (epoch == _stateEpoch) _errorMessage = null;
    } catch (error) {
      if (epoch == _stateEpoch) {
        if (old == null) {
          _records[personId]!.remove(norm);
        } else {
          _records[personId]![norm] = old;
        }
        _errorMessage = friendlyError(error);
      }
      rethrow;
    } finally {
      if (epoch == _stateEpoch) {
        _savingCells.remove(key);
        notifyListeners();
      }
    }
  }

  // --- Simple attendance statistics ---
  int getPresentCount(String id) => _count(id, AttendanceStatus.present);
  int getAbsentCount(String id) => _count(id, AttendanceStatus.absent);
  int getLateCount(String id) => _count(id, AttendanceStatus.late);

  int _count(String id, AttendanceStatus status) =>
      _records[id]?.values.where((record) => record.status == status).length ?? 0;

  double? getAttendancePercentage(String personId) {
    final present = getPresentCount(personId);
    final late = getLateCount(personId);
    final absent = getAbsentCount(personId);
    final marked = present + late + absent;
    return marked == 0 ? null : (present + late) / marked * 100;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Translate common network, auth, and PostgREST errors for users.
  static String friendlyError(Object error) {
    if (error is TimeoutException) {
      return error.message ?? 'The database request timed out. Check your connection.';
    }
    if (error is PostgrestException) {
      if (error.code == '23505') {
        return 'This ID already exists in the sheet. Please use a different ID.';
      }
      if (error.code == '42501') {
        return 'Database permission denied. Check that you are signed in, '
            'that the Supabase SQL script ran successfully, and that RLS '
            'policies allow this account to access this sheet.';
      }
      if (error.code == '42P01' || error.code == 'PGRST205') {
        return 'Database table not found. Run supabase/schema.sql in the '
            'Supabase SQL Editor and verify its tables exist.';
      }
      return error.message;
    }
    if (error is AuthException) return error.message;
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('ClientException') ||
        message.contains('Failed host lookup')) {
      return 'Cannot reach Supabase. Check internet on the emulator and '
          'verify your Supabase Project URL.';
    }
    return message.replaceFirst(RegExp(r'^(Exception|Bad state|Invalid argument)[: ]+'), '');
  }
}
