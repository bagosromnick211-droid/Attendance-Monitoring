// Searchable sheet selector used by dashboard filters.
import 'package:flutter/material.dart';
import '../models/attendance_form.dart';

// A sentinel distinguishes choosing All Sheets from dismissing the sheet picker.
const dashboardAllSheetsSelection = '__all_attendance_sheets__';

class DashboardSheetPicker extends StatefulWidget {
  const DashboardSheetPicker({
    super.key,
    required this.forms,
    required this.selectedSheetId,
  });

  final List<AttendanceForm> forms;
  final String? selectedSheetId;

  @override
  State<DashboardSheetPicker> createState() => _DashboardSheetPickerState();
}

class _DashboardSheetPickerState extends State<DashboardSheetPicker> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_updateSearch);
  }

  void _updateSearch() => setState(() {});

  @override
  void dispose() {
    _search.removeListener(_updateSearch);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = widget.forms.where((form) =>
        form.title.toLowerCase().contains(query) ||
        form.entityLabel.toLowerCase().contains(query)).toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('Select attendance sheet',
                style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            autofocus: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: 'Search sheet name or label',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(child: ListView.builder(
            itemCount: visible.length + (query.isEmpty ||
                'all sheets'.contains(query) ? 1 : 0),
            itemBuilder: (context, index) {
              final showAll = query.isEmpty || 'all sheets'.contains(query);
              if (showAll && index == 0) {
                return ListTile(
                  leading: const Icon(Icons.layers_outlined),
                  title: const Text('All Sheets'),
                  subtitle: const Text('Combined attendance data'),
                  trailing: widget.selectedSheetId == null
                      ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.pop(context, dashboardAllSheetsSelection),
                );
              }
              final form = visible[index - (showAll ? 1 : 0)];
              return ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(form.title),
                subtitle: Text(form.entityLabel),
                trailing: widget.selectedSheetId == form.id
                    ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, form.id),
              );
            },
          )),
          if (visible.isEmpty && query.isNotEmpty &&
              !'all sheets'.contains(query))
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No matching attendance sheets.'),
            ),
        ]),
      ),
    );
  }
}
