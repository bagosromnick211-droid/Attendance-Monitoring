// Attendance app screen.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../models/attendance_form.dart';

// Lists folders.
class SheetListScreen extends StatelessWidget {
  const SheetListScreen({
    super.key,
    required this.controller,
    required this.onOpen,
    required this.onSettings,
    required this.onCreate,
    required this.onRefresh,
  });

  final AttendanceController controller;
  final Future<void> Function(AttendanceForm) onOpen;
  final void Function(AttendanceForm) onSettings;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Expanded(child: Text('My attendance sheets',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            IconButton(tooltip: 'Refresh', onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 6),
          Text('Open or manage your folders.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          if (controller.isLoading) const LinearProgressIndicator(),
          if (controller.errorMessage != null)
            Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Text(controller.errorMessage!))),
          if (controller.forms.isEmpty && !controller.isLoading)
            Card(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(children: [
                const Icon(Icons.folder_open_outlined, size: 44),
                const SizedBox(height: 12),
                const Text('No sheets yet'),
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: onCreate,
                    icon: const Icon(Icons.add), label: const Text('Create a sheet')),
              ])))
          else
            ...controller.forms.map((form) => Card(
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: const CircleAvatar(child: Icon(Icons.folder_outlined)),
                title: Text(form.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${form.entityLabel} • ${_date(form.startDate)} – ${_date(form.endDate)}'),
                onTap: controller.isLoading ? null : () => onOpen(form),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Folder actions',
                  onSelected: (value) {
                    if (value == 'settings') {
                      onSettings(form);
                    } else {
                      onOpen(form);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'open', child: Text('Open sheet')),
                    PopupMenuItem(value: 'settings', child: Text('Folder settings')),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 16),
          OutlinedButton.icon(onPressed: onCreate,
              icon: const Icon(Icons.add_circle_outline), label: const Text('New sheet')),
        ],
      ),
    );
  }

  static String _date(DateTime date) => '${date.month}/${date.day}/${date.year}';
}
