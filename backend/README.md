# Local Backend Server

This backend provides centralized auth storage so browser users can sign up and log in from any browser on the same machine.

## Run

1. Open a terminal in `backend/`
2. Run `dart pub get`
3. Start the server with `dart run bin/server.dart`

The server listens on `http://localhost:8080`.

## Notes

- The Flutter web app uses this server for auth when available.
- Use the same server across browsers to share credentials.
- If the server is not running, the app falls back to local auth storage on the current device/browser only.
