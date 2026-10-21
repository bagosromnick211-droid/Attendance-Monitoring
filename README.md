<<<<<<< HEAD
# Attendance Monitoring v10

Flutter + Supabase attendance monitoring application.

Start with **[`V10_DASHBOARD_SETUP.md`](V10_DASHBOARD_SETUP.md)** to install the dashboard migration and test its filters. The previous **[`V9_SETUP.md`](V9_SETUP.md)** still explains email verification and the account-deletion Edge Function.

- Flutter project/package directory: `attendance_monitoring/`
- Existing Supabase v7/v8 database remains intact
- The time-in/out display and quick editor respect each sheet's settings
- Permanent account deletion requires deployment of `supabase/functions/delete-account`
- The dashboard now supports searchable sheet selection and daily/weekly/monthly attendance trends
- The new dashboard uses a read-only v10 Supabase migration; other v9 features are preserved
- The previous source architecture is explained in `ARCHITECTURE.md`

**Security:** use only the publishable API key inside Flutter, never the service-role/secret key. The deletion function verifies the signed-in user server-side.
=======
# Attendance-Monitoring
>>>>>>> 792f82d28133ee72652718d8a451bcaf3705d5bc
