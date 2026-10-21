// Attendance app screen.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/attendance_record.dart';
import '../models/person.dart';
import '../widgets/add_person_dialog.dart';
import '../widgets/edit_person_dialog.dart';
import '../widgets/attendance_table_viewport.dart';
import '../widgets/search_bar.dart';
import '../widgets/attendance_data_source.dart';
import '../widgets/attendance_time_dialog.dart';
import '../utils/date_utils.dart';

// Attendance workspace for one sheet: filters, date pagination, and actions.
class SheetGridScreen extends StatefulWidget {
  final AttendanceController controller;
  final AuthController authController;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onBackToSheets;

  const SheetGridScreen({
    super.key,
    required this.controller,
    required this.authController,
    this.onOpenDrawer,
    this.onOpenSettings,
    this.onBackToSheets,
  });

  @override
  State<SheetGridScreen> createState() => _SheetGridScreenState();
}

class _SheetGridScreenState extends State<SheetGridScreen> {
  AttendanceController get controller => widget.controller;
  AuthController get authController => widget.authController;

  // Show only two weeks of dates at a time. Building an entire year's
  // attendance cells in one horizontal table can stall slower emulators.
  static const int _datesPerPage = 14;
  int _datePage = 0;

  void _showError(BuildContext context, String lead, Object error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$lead: ${AttendanceController.friendlyError(error)}'),
      backgroundColor: Colors.red,
    ));
  }

  // Save via the controller.
  Future<void> _updateStatus(
    BuildContext context,
    String personId,
    DateTime date,
    AttendanceStatus? status,
  ) async {
    try {
      await controller.updateStatus(personId, date, status);
    } catch (error) {
      _showError(context, 'Could not save attendance', error);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await authController.signOut();
    } catch (error) {
      _showError(context, 'Could not sign out', error);
    }
  }

  // Open an independent dialog for time values so its local UI state.
  Future<void> _editTimes(
      BuildContext context, String personId, DateTime date) async {
    final record = controller.getRecord(personId, date);
    final form = controller.currentForm;
    if (record == null || form == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => AttendanceTimeDialog(
        record: record,
        form: form,
        date: date,
        errorMessage: AttendanceController.friendlyError,
        onSave: (timeIn, timeOut) => controller.updateTimes(
          personId,
          date,
          timeIn: timeIn,
          timeOut: timeOut,
        ),
      ),
    );
  }

  Future<void> _editPerson(BuildContext context, Person person) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          EditPersonDialog(person: person, onSave: controller.editPerson),
    );
  }

  // Confirm this destructive operation before asking the controller to delete.
  Future<void> _deletePerson(BuildContext context, Person person) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete person?'),
        content: Text(
            'Delete “${person.name}” and all their attendance records? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete permanently')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await controller.deletePerson(person);
    } catch (error) {
      _showError(context, 'Could not delete person', error);
    }
  }

  // Only 14 date columns appear at once to keep wide sheets manageable.
  @override
  Widget build(BuildContext context) {
    final form = controller.currentForm!;
    final allDates = controller.dateColumns;
    final lastPage =
        allDates.isEmpty ? 0 : (allDates.length - 1) ~/ _datesPerPage;
    final activePage =
        _datePage < 0 ? 0 : (_datePage > lastPage ? lastPage : _datePage);
    final start = activePage * _datesPerPage;
    final dates = allDates.skip(start).take(_datesPerPage).toList();
    final people = controller.filteredPersons;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Open navigation',
          onPressed: widget.onOpenDrawer,
          icon: const Icon(Icons.menu),
        ),
        title: Text(form.title),
        actions: [
          IconButton(
            tooltip: 'Folder settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: widget.onOpenSettings,
          ),
          IconButton(
            tooltip: 'Back to sheets',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: widget.onBackToSheets ?? controller.resetForm,
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed:
                authController.isLoading ? null : () => _signOut(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPersonDialog(context),
        icon: const Icon(Icons.add),
        label: Text('Add ${form.entityLabel}'),
      ),
      body: Column(
        children: [
          PersonSearchBar(onChanged: (value) => controller.searchQuery = value),
          if (controller.groups.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButton<String>(
                isExpanded: true,
                value: controller.groupFilter,
                hint: const Text('All groups'),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('All groups')),
                  ...controller.groups.map((group) => DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      )),
                ],
                onChanged: (value) => controller.groupFilter = value,
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${controller.memberCount} ${form.entityLabel.toLowerCase()}(s) • '
                '${allDates.length} dates • Tap status to mark, or In/Out to edit times',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (allDates.length > _datesPerPage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous dates',
                    onPressed: activePage == 0
                        ? null
                        : () => setState(() => _datePage = activePage - 1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      'Dates ${start + 1}–${start + dates.length} of ${allDates.length}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next dates',
                    onPressed: activePage >= lastPage
                        ? null
                        : () => setState(() => _datePage = activePage + 1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          if (people.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    controller.searchQuery.trim().isEmpty &&
                            controller.groupFilter == null
                        ? 'No ${form.entityLabel.toLowerCase()}s yet. Tap Add to begin.'
                        : 'No matching ${form.entityLabel.toLowerCase()}s found.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: AttendanceTableViewport(
                  dateColumnCount: dates.length,
                  child: PaginatedDataTable(
                    showCheckboxColumn: false,
                    // Keep attendance cells compact on narrow devices.
                    columnSpacing: 22,
                    horizontalMargin: 14,
                    dataRowMinHeight: 90,
                    dataRowMaxHeight: 120,
                    rowsPerPage: 10,
                    availableRowsPerPage: const [10],
                    columns: [
                      DataColumn(label: Text(form.entityLabel)),
                      ...dates.map((date) => DataColumn(
                              label: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(weekdayAbbreviation(date),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text('${date.month}/${date.day}',
                                  style: const TextStyle(fontSize: 11)),
                            ],
                          ))),
                      const DataColumn(label: Text('P')),
                      const DataColumn(label: Text('A')),
                      const DataColumn(label: Text('L')),
                      const DataColumn(label: Text('Rate')),
                    ],
                    source: AttendanceDataSource(
                      context: context,
                      people: people,
                      dates: dates,
                      form: form,
                      controller: controller,
                      selectStatus: (personId, date, status) =>
                          _updateStatus(context, personId, date, status),
                      editTimes: (personId, date) =>
                          _editTimes(context, personId, date),
                      editPerson: (person) => _editPerson(context, person),
                      deletePerson: (person) => _deletePerson(context, person),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddPersonDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddPersonDialog(
        entityLabel: controller.currentForm?.entityLabel ?? 'Person',
        onSave: controller.addPerson,
        errorMessage: AttendanceController.friendlyError,
      ),
    );
  }
}
