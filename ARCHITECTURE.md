# Attendance Monitoring — Code Architecture (v10)

This guide describes the organized Flutter application. The original attendance tables and RLS policies remain intact; v10 adds a read-only dashboard trend function. If you are presenting the project, start with **Where to look**, then **Follow a request**, then the **Dart/Flutter glossary**.

## 1. The big picture

```text
main.dart                              Starts Flutter and configures Supabase
   └── app/attendance_app.dart         Owns shared AuthController and AttendanceController
        ├── app/home_router.dart       Rebuilds the visible page when state changes
        └── app/app_workspace.dart     Sidebar, page selection, sheet navigation
             └── screens/             Receives input and displays results
                  ├── controllers/     Validates actions and holds shared state
                  │    └── services/   Uses Supabase to read/write the database
                  └── widgets/         Reusable small UI pieces and dialogs
models/                                Data models used across all layers
utils/                                 Pure, reusable formatting helpers
config/                                Supabase URL, publishable key, OAuth redirect
supabase/                              SQL schema/migrations (not Flutter code)
```

**Rule of thumb:** Screens decide **what the user sees**; controllers decide **what the app does**; services decide **how it contacts Supabase**; models decide **what a record looks like**. `utils/` holds small shared conversions that do not themselves save data.

## 2. Where to look

| Path | Responsibilities |
|---|---|
| `lib/main.dart` | Initializes Flutter, Supabase, and the required fresh-login startup behavior. |
| `lib/app/attendance_app.dart` | Creates/disposes the two shared controllers. Clears previous-user state when auth changes. |
| `lib/app/home_router.dart` | `AnimatedBuilder` rebuilds the visible route body when controllers call `notifyListeners()`. Keeps the Navigator stable. |
| `lib/app/app_workspace.dart` | Drawer header, masked email, page selection, navigation between dashboard/sheets/settings. |
| `lib/app/supabase_setup_required_app.dart` | Screen shown when Supabase is not configured. |
| `lib/controllers/auth_controller.dart` | Authentication session, account username/profile, login/signup/OAuth, sign-out. |
| `lib/controllers/attendance_controller.dart` | Current sheet, people, records, search, attendance saving, summaries, and loading/error state. |
| `lib/services/api_services.dart` | Supabase queries for sheets, members, records, and dashboard RPC. Implements pagination, timeouts, and request logs. |
| `lib/screens/sheet_grid_screen.dart` | Grid's toolbar, search/filter, 14-date pagination, edit/delete actions. |
| `lib/widgets/attendance_data_source.dart` | Converts people/records to `PaginatedDataTable` rows; no direct database queries. |
| `lib/widgets/attendance_time_dialog.dart` | Owns temporary time-picker state and sends completed values to a callback. |
| `lib/widgets/add_person_dialog.dart`, `edit_person_dialog.dart` | Own text-field state and dialogs. They do not perform Supabase queries themselves. |
| `lib/widgets/attendance_table_viewport.dart` | Constrains the table width to avoid Flutter's infinite-width layout exception. |
| `lib/widgets/attendance_cell.dart` | Color-coded status cell; calls handlers when users select P/A/L/No Class. |
| `lib/utils/email_utils.dart` | Masks the sidebar email without changing the user's email address. |
| `lib/utils/date_utils.dart` | Weekday abbreviations and calendar-date normalization. |
| `lib/utils/time_utils.dart` | Converts between Flutter `TimeOfDay` and SQL `HH:mm:ss` strings. |
| `lib/models/` | Data objects and JSON parsing for `attendance_forms`, `persons`, and `attendance_records`. |

Other screens (`dashboard_screen`, `sheet_list_screen`, `form_creation_screen`, `folder_settings_screen`, `login_screen`, `profile_screen`, `app_settings_screen`) are left in `screens/` because they are complete pages rather than general-purpose business logic.

## 3. Follow a real action: Add Student

1. The Add button in `sheet_grid_screen.dart` opens `AddPersonDialog`.
2. The dialog reads the **temporary text fields** (name, ID, group).
3. The dialog calls the `onSave` callback provided by the screen.
4. That callback is `AttendanceController.addPerson(...)`. It validates the name and current sheet, and requests a save through `ApiService`.
5. `ApiService.addPerson(...)` inserts into the Supabase **persons** table and parses the returned row into a `Person` model.
6. The controller appends the new person to the in-memory list and calls `notifyListeners()`.
7. `AttendanceHomeRouter` / listening widgets rebuild and display the new row.

**Why UI text controllers stay inside widgets:** A `TextEditingController` manages one text field's selection, caret, and typed text. The dialog creates and disposes it with the widget lifecycle. It is *not* the same thing as an `AttendanceController` (a `ChangeNotifier` for shared application state). Moving text-field controllers to a global business controller can recreate the “used after being disposed” bug.

## 4. Follow another action: Change attendance

```text
attendance_cell.dart (user selects Present)
  -> sheet_grid_screen.dart (_updateStatus)
  -> attendance_controller.dart (updateStatus, _saveCell)
  -> api_services.dart (saveOrUpdateRecord)
  -> Supabase attendance_records row
  -> controller state + notifyListeners()
  -> table redraws
```

`_saveCell` temporarily updates the in-memory row (optimistic UI), tracks `_savingCells` so you cannot write to the same cell twice simultaneously, then rolls back if saving fails. `_stateEpoch` is a generation counter; late HTTP responses from a previous sheet or user cannot overwrite the currently visible data.

**Unmarked** means *no record exists*. **No Class** is a saved attendance status. This difference is important when computing reports.

## 5. Flutter/Dart special functions explained

| Term | Plain-language meaning and where it appears |
|---|---|
| `StatefulWidget` | UI that remembers temporary state, e.g. dialog fields or the currently visible date page. |
| `initState()` | Runs once when widget state is created. Use it to create controllers and initial values. |
| `dispose()` | Releases text controllers, subscriptions, etc. when a widget is removed. Do not use them afterward. |
| `setState(() { ... })` | Updates *local widget* state, then requests a rebuild. Example: date page or spinner. |
| `ChangeNotifier` | A class that other widgets listen to; `AuthController` and `AttendanceController` use it for shared state. |
| `notifyListeners()` | Announces that shared controller data changed; listeners rebuild their widgets. |
| `AnimatedBuilder` | Listens to a `Listenable` and rebuilds its child when notified. Here it keeps `MaterialApp` stable. |
| `Future<T>` | A value arriving later (e.g. a Supabase HTTP result). |
| `async` / `await` | Writes asynchronous operations sequentially without blocking the Flutter UI thread. |
| `Future.wait([...])` | Runs independent requests together, like loading people and attendance records for a sheet. |
| `try` / `catch` / `finally` | Try the operation; handle errors; always stop the loading indicator in `finally`. |
| `mounted` / `context.mounted` | Check whether a widget still exists after an `await` before updating its screen. |
| `Navigator.pop(context)` | Dismisses the top route/dialog. |
| `showDialog()` | Opens a modal route for editing or confirming a delete. |
| `DataTableSource.getRow()` | Supplies a table row when `PaginatedDataTable` requests it. |
| `LayoutBuilder` / `BoxConstraints` | Reads available layout space; the table viewport sets a **finite width** to prevent a layout exception. |
| `factory ...fromSupabase` | Parses Supabase's JSON/Map fields into a Dart model. |
| `toSupabase()` | Converts a Dart model to a Map with database column names. |
| `upsert()` | Inserts a record or updates one when its conflict key already exists (attendance uses person + date). |
| `String.fromEnvironment()` | Reads a named value passed at **build/run time**, e.g. `SUPABASE_URL`, rather than a literal URL. |
| `SignOutScope.local` | Signs out this device/session on process launch without revoking sessions on other devices. |

## 6. How Supabase security works

`lib/config/supabase_config.dart` contains the project URL and a **publishable** client key. This is not an administrator key. Database access is protected by the SQL Row Level Security policies in `supabase/schema.sql` and the v8 migration. Never place a Supabase `service_role`/secret key in a mobile application.

The provided source package retains the **same configuration as the uploaded v8 ZIP**, so you can continue using the same database; move the publishable configuration to `--dart-define` later if you prefer separate development/production environments. See the setup guide for that method. **Do not re-run the schema/migrations just to refactor code.**

## 7. How to add features without making the project messy

- New page: add one screen in `screens/`; connect it in `app/app_workspace.dart`.
- Reusable visual element: put it in `widgets/`, such as a dialog or small card.
- Data changes: add a method in `controllers/` (state + validation) and a matching Supabase call in `services/`.
- New saved field: update SQL migration **and** matching model serialization, then the controller and UI.
- Shared pure formatting: use `utils/`. Do not put network calls in `utils/`.
- Add a widget/unit test under `test/` whenever possible.

## 8. Run and verify

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

The project was reorganized in an environment **without a Flutter SDK**, so `flutter analyze`, `flutter test`, and emulator operation still need to be run on your Windows machine. Compare v8 behavior: sign in, dashboard, open 3A, add and edit a person, mark attendance, edit times, folder settings, reopen the app and sign in again. The SQL schema is unchanged.

## 6. Dashboard trends (v10)

```text
DashboardScreen (scope + period filters)
  -> AttendanceController.loadDashboardTrend
  -> ApiService.fetchDashboardTrend
  -> Supabase attendance_dashboard_trend RPC (read-only)
  -> DashboardTrendReport (date counts + scope totals)
  -> DashboardCalendar.group (7 weekdays / month weeks / 12 months)
  -> AttendanceTrendChart (line graph and tap details)
```

`dashboard_sheet_picker.dart` owns the sheet-search text controller and disposes it with the picker widget. `dashboard_trend.dart` owns date math and attendance aggregation; it does not contact Supabase. The dashboard neither edits nor lists individual student records.
