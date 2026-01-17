## Frontend Student App → Backend/DB flow

Platform: Flutter (`frontend_student`). Auth is Google Sign-In; backend is FastAPI.

High-level login flow
1) Google Sign-In obtains ID token on device.
2) App calls backend `POST /auth/google/student` with the Google ID token.
3) Backend verifies token, checks `allowed_student_emails` (or existing `students`), then issues JWT (student role) and may auto-create student record if needed.
4) App stores JWT and uses it in `Authorization: Bearer <token>` for all API calls.

Key API calls used by the student app (typical)
- GET `/students/me` — fetch current student profile (name, roll_no, emails, photo_url).
- POST `/storage/students/me/photo` — upload own photo (currently short-circuited/disabled in code path; teacher upload is `/storage/students/{roll_no}/photo`).
- GET `/classes` (if exposed to students) — classes the student is enrolled in.
- GET `/stats/students/{student_id}` — attendance summary.
- GET `/attendance/sessions` / `/attendance/sessions/{id}` — session info (depending on UI).

How data lands in DB
- Student identity comes from Google email; whitelist is `allowed_student_emails`. On first login, backend may create a `students` row from whitelist info (roll_no/name/email).
- Photos: uploaded via storage endpoint → stored in Azure Blob Storage → URL saved in `students.photo_url`.
- Attendance statuses: written by teacher flows; student reads them via stats/endpoints.

Error cases to watch
- If email not in `allowed_student_emails`, login is rejected.
- If photo upload is disabled (current code short-circuits), `photo_url` will stay empty unless a teacher uploads on behalf.
- Ensure JWT is refreshed on expiry (~1h default).

Environment deps
- Backend URL + GOOGLE_CLIENT_ID must match the backend config.
- DATABASE_URL points to Postgres; photos use `AZURE_STORAGE_CONNECTION_STRING`.

