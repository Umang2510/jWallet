# jWallet Lite

Flutter 3.50.0 / Dart 3.14 mobile wallet. This increment implements the login screen and authentication foundation using the supplied backend API.

## Run

Use Flutter 3.50 or newer. The project imports the standalone `material_ui` package, following the [Flutter migration guide](https://docs.flutter.dev/release/breaking-changes/material-ui-and-cupertino-ui).

```sh
flutter pub get
flutter run --dart-define-from-file=env/local.json
```

Debug and release both use `https://jwallet-backend.onrender.com`. No local server is required. The default `AppConfig`, `env/local.json` (debug) and `env/prod.json` (release) all point to this hosted service.

Demo login: `demo@jstack.co` / `Demo@123`.

Both environment files contain public app settings only:

- `API_BASE_URL`: `https://jwallet-backend.onrender.com` for emulators, physical devices, debug and release.
- `ENC_KEY_ID` and `ENC_PUBLIC_KEY`: the backend's key ID and base64 uncompressed P-256 **public** key. These must match the server; never include its private key.
- Both configurations use the hosted server's `prod-1` public encryption key. Device testing is handled by the user.

## Structure and conventions

`view → LoginCubit → AuthRepository → ApiClient / SecureStore`

- `app/`: GetIt dependency registration, session Cubit, GoRouter access rules.
- `core/`: encrypted Dio requests, secure storage, theme, validators, reusable fields/buttons, spacing helpers.
- `features/auth/`: login presentation, BLoC state, and API repository.
- Use small `_build...()` methods for screen sections and separate widget files for reusable controls.
- Use `flutter_screenutil_plus`: `.h` for height, `.w` for width, `.r` for radius and `.sp` for text. Phone scaling is bounded for text; wide layouts retain normal control sizes and a centered form.
- Import `core/extensions/spacing_extension.dart` for `25.sizedBoxHeight()` and `25.sizedBoxWidth()`.
- Keep validation in `Validators`. Login validation matches the server's email and password limits; password whitespace is preserved.
- `AppTextField` supports controllers, validators, autofill, focus, input actions, custom decoration and password visibility. `AppButton` supports primary, secondary and outlined variants, loading, icons and custom styles.
- Remove a folder's `.gitkeep` when adding real files to that folder.

The dark theme follows the supplied warm charcoal reference: `#F4F2EF`, `#FA8246`, `#1B2A2D`, `#1D1D1D`. Space Grotesk and Geist are loaded through Google Fonts from bundled assets, with runtime fetching disabled and licenses registered.

## Authentication behavior

- Calls the actual `POST /api/v1/auth/login` endpoint, using the backend's `{meta, body}` envelope rather than the assignment's illustrative response format.
- Each request uses ephemeral P-256 ECDH, HKDF-SHA256 and AES-256-GCM with method/path-bound request authentication and status-bound response authentication.
- Stores access/refresh tokens together in platform secure storage. Passwords are never persisted. A persistent device UUID is supplied at login.
- Restores an unexpired session by checking `/users/profile`; invalid/revoked tokens are removed. Connection failures preserve saved credentials and show the login screen.
- Submissions disable controls, prevent duplicate requests, and display API/connection/timeout errors inline.
- Routes successful login to Set PIN when `security.pinSet` is false, otherwise Dashboard. Both destinations are currently placeholders with logout available.
- Logout attempts server revocation and clears local session storage.

## Checks

Node is also required for the independent encryption interoperability test.

```sh
flutter analyze
flutter test
flutter test test/auth/login_screen_test.dart --dart-define=CAPTURE_LOGIN=true
dart run tool/auth_smoke.dart
```

The preview test writes `build/previews/login.png`. The optional smoke check uses the configured hosted backend; it signs in with the demo account, fetches the profile, and revokes its test session. Tests cover login validation, duplicate submissions, failures/retry, secure persistence, restoration, logout, password visibility, phone/tablet/landscape layouts with large text and keyboard insets, and Dart/Node encryption compatibility and tamper rejection.

## Remaining app work

PIN setup, dashboard, transfer and transaction screens remain placeholders. Automatic token refresh and the native device signing key are not implemented; after the access token expires (15 minutes by default), sign in again. Biometric enrollment is not implemented. The current login increment does not complete the full assignment.

The login UI, theme, shared components, authentication foundation and accompanying tests were developed with AI assistance and should be reviewed as part of the assignment submission.
