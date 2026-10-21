// App navigation and routing.
import 'package:flutter/material.dart';

import '../controllers/attendance_controller.dart';
import '../controllers/auth_controller.dart';
import '../models/attendance_form.dart';
import '../screens/app_settings_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/folder_settings_screen.dart';
import '../screens/form_creation_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sheet_grid_screen.dart';
import '../screens/sheet_list_screen.dart';
import '../utils/email_utils.dart';

// Which workspace page is currently visible. This is UI navigation state.
enum _Page { dashboard, sheets, create, profile, appSettings, settings, grid }

// Scaffold for authenticated screens. Owns the drawer and page selection.
class AppWorkspace extends StatefulWidget {
  const AppWorkspace({required this.authController, required this.controller});
  final AuthController authController;
  final AttendanceController controller;

  @override
  State<AppWorkspace> createState() => _AppWorkspaceState();
}

class _AppWorkspaceState extends State<AppWorkspace> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  _Page _page = _Page.dashboard;
  AttendanceForm? _settingsForm;
  _Page _returnFromSettings = _Page.sheets;
  bool _opening = false;

  Future<void> _refreshSheets() async {
    final id = widget.authController.currentUser?.id;
    if (id == null) return;
    try {
      await widget.controller.loadUserForms(id);
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  void _showError(Object error) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AttendanceController.friendlyError(error)),
    ));
  }

  // Closes the drawer, clears sheet-only state, then changes the visible page.
  void _navigate(_Page page) {
    Navigator.of(context).maybePop(); // closes drawer if it is open
    if (page != _Page.grid && page != _Page.settings) {
      widget.controller.resetForm();
      _settingsForm = null;
    }
    setState(() => _page = page);
  }

  // Load a sheet first, then switch to its table when data is ready.
  Future<void> _openSheet(AttendanceForm form) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.controller.loadFormDetails(form);
      if (mounted) setState(() => _page = _Page.grid);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  // Remember the originating page so Back can return there.
  void _openSettings(AttendanceForm form) {
    _settingsForm = form;
    _returnFromSettings = _page == _Page.grid ? _Page.grid : _Page.sheets;
    setState(() => _page = _Page.settings);
  }

  void _backFromSettings() {
    final previous = _returnFromSettings;
    setState(() {
      _settingsForm = null;
      _page = previous == _Page.grid && widget.controller.currentForm == null
          ? _Page.sheets : previous;
    });
  }

  void _afterDelete() {
    widget.controller.resetForm();
    setState(() { _settingsForm = null; _page = _Page.sheets; });
  }

  Future<void> _logout() async {
    try {
      await widget.authController.signOut();
    } catch (error) {
      _showError(error);
    }
  }

  // Builds the selected page.
  Widget _content() {
    switch (_page) {
      case _Page.dashboard:
        return DashboardScreen(controller: widget.controller);
      case _Page.sheets:
        return SheetListScreen(
          controller: widget.controller,
          onOpen: _openSheet,
          onSettings: _openSettings,
          onCreate: () => _navigate(_Page.create),
          onRefresh: _refreshSheets,
        );
      case _Page.create:
        return FormCreationScreen(
          attendanceController: widget.controller,
          authController: widget.authController,
          onCreated: () => setState(() => _page = _Page.grid),
        );
      case _Page.profile:
        return ProfileScreen(authController: widget.authController);
      case _Page.appSettings:
        return AppSettingsScreen(
          authController: widget.authController,
          onOpenSheets: () => _navigate(_Page.sheets));
      case _Page.settings:
        if (_settingsForm == null) return const Center(child: Text('Select a folder.'));
        return FolderSettingsScreen(
          key: ValueKey(_settingsForm!.id),
          form: _settingsForm!,
          controller: widget.controller,
          onFinished: _backFromSettings,
          onDeleted: _afterDelete,
        );
      case _Page.grid:
        if (widget.controller.currentForm == null) {
          return const Center(child: Text('Open a sheet from My Sheets.'));
        }
        return SheetGridScreen(
          controller: widget.controller,
          authController: widget.authController,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
          onOpenSettings: () => _openSettings(widget.controller.currentForm!),
          onBackToSheets: () => _navigate(_Page.sheets),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.authController;
    final isGrid = _page == _Page.grid;
    const names = {
      _Page.dashboard: 'Dashboard',
      _Page.sheets: 'My Attendance Sheets',
      _Page.create: 'Create Sheet',
      _Page.profile: 'My Profile',
      _Page.appSettings: 'Settings',
      _Page.settings: 'Folder Settings',
    };
    return Scaffold(
      key: _scaffoldKey,
      appBar: isGrid ? null : AppBar(
        title: Text(names[_page] ?? 'Attendance'),
        actions: [
          if (_page == _Page.settings)
            IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back), onPressed: _backFromSettings),
          if (_opening) const Padding(padding: EdgeInsets.all(14), child: SizedBox(
            width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(child: Column(children: [
          Padding(padding: const EdgeInsets.all(20), child: Row(children: [
            CircleAvatar(radius: 25, child: Text(auth.username.isEmpty ? '?' : auth.username[0].toUpperCase())),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(auth.username, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              Text(maskEmailAddress(auth.email),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ])),
          ])),
          const Divider(),
          _drawerTile(Icons.dashboard_outlined, 'Dashboard', _Page.dashboard),
          _drawerTile(Icons.folder_copy_outlined, 'My Attendance Sheets', _Page.sheets),
          _drawerTile(Icons.note_add_outlined, 'Create New Sheet', _Page.create),
          _drawerTile(Icons.person_outline, 'My Profile', _Page.profile),
          _drawerTile(Icons.settings_outlined, 'Settings', _Page.appSettings),
          const Spacer(),
          const Divider(),
          ListTile(leading: const Icon(Icons.logout), title: const Text('Log out'),
            onTap: _logout),
          const SizedBox(height: 12),
        ])),
      ),
      body: _content(),
    );
  }

  Widget _drawerTile(IconData icon, String title, _Page page) =>
    ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _page == page,
      onTap: () => _navigate(page),
    );
}

