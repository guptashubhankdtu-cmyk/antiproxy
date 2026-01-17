## Frontend Teacher App → Backend/DB flow

Platform: Flutter (`frontend_teacher`). Auth is Google Sign-In; backend is FastAPI.

High-level login flow
1) Google Sign-In obtains ID token on device.
2) App calls backend `POST /auth/google` (teacher/admin) with the Google ID token.
3) Backend verifies token, checks `allowed_emails`, then issues JWT (role from whitelist) and ensures a `users` row exists/updates.
4) App stores JWT and uses it in `Authorization: Bearer <token>` for all API calls.

Key API calls used by the teacher app (typical)
- Classes:
  - GET `/classes` — list teacher’s classes.
  - POST `/classes` — create class.
  - GET `/classes/{class_id}/students` — roster.
  - POST `/classes/{class_id}/students` — add students (also can auto-add to `allowed_student_emails`).
- Attendance:
  - POST `/attendance/sessions` — create session (per class/date; may include processed image URL).
  - GET `/attendance/sessions/{id}` — session detail.
  - POST `/attendance/sessions/{id}/mark` — mark attendance for a student/device.
  - GET `/attendance/sessions` — list sessions for teacher.
- Stats:
  - GET `/stats/classes/{class_id}` — attendance summary per class.
  - GET `/stats/students/{student_id}` — attendance summary per student.
- Storage (photos):
  - POST `/storage/students/{roll_no}/photo` — upload student photo on behalf of student; stores in Azure Blob Storage, URL saved to `students.photo_url`. (Student self-upload endpoint exists but is disabled in code.)

How data lands in DB
- Teachers/admins are whitelisted in `allowed_emails`; their accounts live in `users`.
- Classes and schedules populate `classes`, `class_schedules`, `class_reschedules`.
+- Rosters populate `class_students`; student identities come from `students` (or are auto-created from `allowed_student_emails` when adding).
- Attendance sessions go to `attendance_sessions`; per-student marks go to `attendance_statuses` (status, similarity_score, recognized_by_ai).
- Notifications to students are stored in `notifications` (type: attendance/manual/system).
- Photo uploads: blobs go to Azure Storage; URLs stored in `students.photo_url`.

Data sources and storage
- Relational data: PostgreSQL (`DATABASE_URL`).
- Blobs: Azure Blob Storage (`AZURE_STORAGE_CONNECTION_STRING`), triggered via storage routes.

Common pitfalls
- If email not in `allowed_emails`, teacher login fails.
- If `AZURE_STORAGE_CONNECTION_STRING` is missing, photo uploads fail with 503.
- If classes/schedules are missing, attendance session creation will fail FK/validation.
- JWT expires (~1h); app must refresh via re-auth if needed.

