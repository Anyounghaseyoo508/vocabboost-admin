# Admin Web Notes

This directory is a standalone Flutter Web app for the admin role.

Scope:
- Keep this app focused on admin workflows only.
- Do not add end-user mobile flows here.
- Reuse the same Supabase project as the main app.

Structure:
- `lib/main.dart` is the admin web entry point.
- `lib/admin_login_screen.dart` handles admin sign-in.
- `lib/admin_guard.dart` blocks non-admin access.
- `lib/admin_splash_screen.dart` restores admin sessions.
- `lib/screens/admin/` contains all admin features.

Rules:
- Treat the root app in `../lib/` as user-only.
- New admin features should be added in `admin_web/lib/screens/admin/`.
- If a shared model is needed, duplicate only the minimal file into `admin_web/lib/` or extract a shared package intentionally.
- Keep web routing under `/admin*` and `/login`.
- Do not reintroduce admin routes into the root Flutter app.

Environment:
- `admin_web/.env` must define `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- Admin authorization is enforced by checking `users.role = 'admin'`.

Verification:
- Run `flutter pub get` inside `admin_web/`.
- Run `flutter analyze lib` inside `admin_web/`.
- Run `flutter run -d chrome` for manual verification.
