## Database Schema (PostgreSQL, backend)

Source: `backend/scripts/create_all_tables.sql` (mirrors Alembic `001_initial`). Core storage is PostgreSQL (Cloud SQL in prod, local Postgres in dev).

Enums
- `userrole`: teacher | admin | student
- `attendancestatus`: present | absent | late | excused

Tables
- `allowed_emails` — whitelist for teacher/admin login; unique email, role, name, timestamps.
- `users` — teachers/admins; email unique, name, role, department/employee_id, last_login_at.
- `students` — roll_no unique, name, photo_url, program, sp_code, semester, status, duration, email, dtu_email, phone, created_at.
- `allowed_student_emails` — whitelist for student login; email, dtu_email, roll_no, name, batch, department, program, timestamps.
- `classes` — class code/name/section, teacher_id (FK users), ltp_pattern, teacher_type, practical_group; unique per (teacher_id, code, section); created_at/updated_at.
- `class_schedules` — recurring weekly slots per class; day_of_week (1-7), start_time, end_time; unique per (class_id, day_of_week).
- `class_reschedules` — one-off reschedules with original/rescheduled date/time and reason.
- `class_students` — many-to-many join; (class_id, student_id) PK; added_at.
- `attendance_sessions` — per-class per-date session; class_id, teacher_id, session_date unique per class, processed_image_url, created_at.
- `attendance_statuses` — per session per student; status enum, recognized_by_ai flag, similarity_score; PK (session_id, student_id).
- `notifications` — for students; title, message, notification_type (attendance|manual|system), attendance_threshold, is_read, created_at/read_at.
- `alembic_version` — migration version tracking.

View
- `v_student_attendance_summary` — aggregates attendance percentage per class/student from class_students + attendance_sessions + attendance_statuses.

Indexes/constraints (high level)
- Unique: `allowed_emails.email`, `users.email`, `students.roll_no`, `classes (teacher_id, code, section)`, `class_schedules (class_id, day_of_week)`, `attendance_sessions (class_id, session_date)`.
- FK: classes→users, class_schedules/class_reschedules/class_students→classes, class_students→students, attendance_sessions→classes/users, attendance_statuses→attendance_sessions/students, notifications→students.

Storage split
- Relational data: PostgreSQL.
- Blobs (student photos): Azure Blob Storage; URLs stored in `students.photo_url`.

