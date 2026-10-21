// Reusable interface component.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../models/attendance_form.dart';
import '../models/attendance_record.dart';
import '../models/person.dart';
import 'attendance_cell.dart';

// Signature for changes made to an attendance cell.
typedef AttendanceStatusChange = void Function(
    String personId, DateTime date, AttendanceStatus? status);
typedef AttendanceTimeEdit = void Function(String personId, DateTime date);

// Turns the current people into rows for Flutter's PaginatedDataTable.
class AttendanceDataSource extends DataTableSource {
  AttendanceDataSource({
    required this.context,
    required this.people,
    required this.dates,
    required this.form,
    required this.controller,
    required this.selectStatus,
    required this.editTimes,
    required this.editPerson,
    required this.deletePerson,
  });

  final BuildContext context;
  final List<Person> people;
  final List<DateTime> dates;
  final AttendanceForm form;
  final AttendanceController controller;
  final AttendanceStatusChange selectStatus;
  final AttendanceTimeEdit editTimes;
  final void Function(Person) editPerson;
  final void Function(Person) deletePerson;

  @override
  int get rowCount => people.length;
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;

  // Build one row on demand.
  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= people.length) return null;
    final person = people[index];
    final id = person.id;
    final rate = id == null ? null : controller.getAttendancePercentage(id);
    return DataRow.byIndex(index: index, cells: [
      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
        ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(person.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (person.memberCode != null)
                  Text(person.memberCode!,
                      style: Theme.of(context).textTheme.bodySmall),
                if (person.groupName != null)
                  Text(person.groupName!,
                      style: Theme.of(context).textTheme.labelSmall),
              ],
            )),
        PopupMenuButton<String>(
          tooltip: 'Edit or delete ${person.name}',
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (value) {
            if (value == 'edit') {
              editPerson(person);
            } else {
              deletePerson(person);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ])),
      ...dates.map((date) {
        final record = id == null ? null : controller.getRecord(id, date);
        return DataCell(id == null
            ? const Icon(Icons.error_outline)
            : AttendanceCellTile(
                status: record?.status,
                saving: controller.isSavingCell(id, date),
                timeInEnabled: form.includeTimeIn,
                timeOutEnabled: form.includeTimeOut,
                timeIn: record?.timeIn,
                timeOut: record?.timeOut,
                onStatusSelected: (status) => selectStatus(id, date, status),
                onEditTimes: () => editTimes(id, date),
              ));
      }),
      DataCell(Text(id == null ? '0' : '${controller.getPresentCount(id)}',
          style: const TextStyle(color: Colors.green))),
      DataCell(Text(id == null ? '0' : '${controller.getAbsentCount(id)}',
          style: const TextStyle(color: Colors.red))),
      DataCell(Text(id == null ? '0' : '${controller.getLateCount(id)}',
          style: TextStyle(color: Colors.amber.shade800))),
      DataCell(Text(rate == null ? '—' : '${rate.toStringAsFixed(0)}%')),
    ]);
  }
}
