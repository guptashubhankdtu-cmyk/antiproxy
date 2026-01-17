# AIMS Attendance System - Production Architecture

A production-grade distributed attendance tracking system built with Flutter (frontend) and FastAPI + PostgreSQL (backend).

## 🎯 Project Overview

This project transforms the original Firebase-based AIMS attendance app into a **fully distributed, secure, and scalable system** with:

- ✅ **FastAPI Backend** - High-performance Python REST API
- ✅ **PostgreSQL Database** - Relational database with proper schema design
- ✅ **Google OAuth → JWT Authentication** - Secure, stateless authentication
- ✅ **Role-Based Access Control** - Teacher and admin permissions enforced server-side
- ✅ **REST API** - Well-documented endpoints replacing Firestore
- ✅ **Docker Deployment** - Containerized for easy deployment
- ✅ **Database Migrations** - Alembic for version-controlled schema changes

---

## 📁 Project Structure

```
anti-proxy-postresql/
├── backend/                    # FastAPI + PostgreSQL Backend
│   ├── app/
│   │   ├── models/            # SQLAlchemy ORM models
│   │   ├── schemas/           # Pydantic request/response models
│   │   ├── routes/            # API endpoints
│   │   ├── services/          # Business logic
│   │   ├── auth/              # Authentication & authorization
│   │   ├── config.py          # Environment configuration
│   │   ├── db.py              # Database connection
│   │   └── main.py            # FastAPI application
│   ├── alembic/               # Database migrations
│   ├── scripts/               # Utility scripts
│   ├── Dockerfile
│   ├── requirements.txt
│   └── README.md              # Backend documentation
│
├── frontend/                   # Flutter Mobile App
│   ├── lib/
│   │   ├── models/            # Data models (ClassModel, StudentModel, etc.)
│   │   ├── services/          # Data services
│   │   │   ├── i_data_service.dart         # Abstract interface
│   │   │   ├── http_data_service.dart      # HTTP implementation (NEW)
│   │   │   └── firebase_data_service.dart  # Firebase implementation (OLD)
│   │   ├── ui/                # UI screens and widgets
│   │   └── main.dart          # App entry point
│   └── pubspec.yaml
│
├── docker-compose.yml          # Multi-container orchestration
├── MIGRATION_GUIDE.md          # Step-by-step migration instructions
└── README.md                   # This file
```

---

## 🚀 Quick Start

### Prerequisites

- **Docker & Docker Compose** (recommended)
- OR: Python 3.11+, PostgreSQL 16+, Flutter 3.3+

### 1. Start Backend Services

```bash
# Navigate to project root
cd anti-proxy-postresql/

# Start PostgreSQL, pgAdmin, and FastAPI backend
docker-compose up -d
```

Once running, access:
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **PostgreSQL**: localhost:5433
- **pgAdmin**: http://localhost:8080 (admin@admin.com / admin)

### 2. Configure Backend

```bash
cd backend/
cp .env.example .env
```

Edit `.env` and set:
```env
JWT_SECRET=<generate-a-strong-random-secret>
GOOGLE_CLIENT_ID=<your-google-oauth-client-id>
```

Generate JWT secret:
```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 3. Run Migrations

```bash
docker-compose exec backend alembic upgrade head
```

### 4. Seed Allowed Emails

Edit `backend/scripts/seed_allowed_emails.py` to add your faculty emails, then:

```bash
docker-compose exec backend python scripts/seed_allowed_emails.py
```

### 5. Run Flutter App

```bash
cd frontend/
flutter pub get
flutter run
```

---

## 📖 Documentation

- **[Backend README](backend/README.md)** - Complete backend documentation
- **[MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)** - Flutter app migration guide
- **[API Documentation](http://localhost:8000/docs)** - Interactive API docs (when backend is running)

---

## 🔐 Authentication Flow

### Current System (Firebase)

```
Flutter App → Google Sign-In → Firebase Auth → Firestore
```

### New System (PostgreSQL Backend)

```
1. Flutter App → Google Sign-In → Get Google ID Token
2. Flutter App → POST /auth/google (with Google ID Token)
3. Backend → Verify token with Google
4. Backend → Check email in allowed_emails whitelist
5. Backend → Create/update user in database
6. Backend → Generate internal JWT token
7. Backend → Return JWT + user info to app
8. Flutter App → Store JWT securely
9. Flutter App → Use JWT in Authorization header for all API calls
```

**Key Benefits:**
- Backend controls who can access the system (whitelist)
- Short-lived, signed JWT tokens (1 hour expiry)
- All authorization logic on server (zero trust from client)
- Teachers can only access their own data

---

## 🗄️ Database Schema

### Core Tables

1. **allowed_emails** - Whitelist of authorized users
2. **users** - Teachers and admins (system operators)
3. **students** - Student records
4. **classes** - Course sections
5. **class_schedules** - Weekly recurring schedules
6. **class_reschedules** - One-time schedule changes
7. **class_students** - Many-to-many enrollment
8. **attendance_sessions** - Attendance taking events
9. **attendance_statuses** - Per-student attendance records

### View

- **v_student_attendance_summary** - Aggregated attendance percentages

See [backend/README.md](backend/README.md) for detailed schema.

---

## 🔧 Development

### Backend Development

```bash
cd backend/

# Install dependencies
pip install -r requirements.txt

# Run locally (without Docker)
uvicorn app.main:app --reload

# Create a new migration
alembic revision --autogenerate -m "Description"

# Apply migrations
alembic upgrade head
```

### Frontend Development

```bash
cd frontend/

# Install dependencies
flutter pub get

# Run on Android emulator
flutter run

# Build APK
flutter build apk

# Run with custom backend URL
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

---

## 🎬 Migration from Firebase to PostgreSQL

**Step-by-step guide:** [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)

### Summary

1. Ensure backend is running and seeded
2. In `frontend/lib/main.dart`, change:
   ```dart
   create: (context) => HttpDataService(),  // was: FirebaseDataService()
   ```
3. Run `flutter pub get`
4. Test authentication and data loading

**No UI changes required!** The abstract `IDataService` interface keeps UI code unchanged.

---

## 🌐 API Endpoints

### Authentication
- `POST /auth/google` - Exchange Google token for JWT

### Users
- `GET /users/me` - Get current user profile

### Classes
- `GET /classes` - List classes (filtered by role)
- `PUT /classes/{id}/students` - Update class roster

### Attendance
- `POST /attendance/sessions` - Create attendance session
- `PUT /attendance/sessions/{id}/statuses` - Update student statuses
- `GET /attendance/sessions?classId=...&from=...&to=...` - Get sessions

### Statistics
- `GET /stats/classes/{id}/students` - Get attendance summary

**Full API documentation:** http://localhost:8000/docs (interactive Swagger UI)

---

## 🔒 Security Features

1. **Whitelist-Based Access** - Only emails in `allowed_emails` can sign in
2. **Role-Based Permissions** - Teachers see only their classes, admins see all
3. **JWT Expiration** - Tokens expire after 1 hour (configurable)
4. **Secure Storage** - Flutter uses Keychain (iOS) / EncryptedSharedPreferences (Android)
5. **Server-Side Authorization** - All permission checks in backend, never trusted from client
6. **Foreign Key Constraints** - Database enforces referential integrity
7. **Input Validation** - Pydantic schemas validate all API inputs

---

## 🚢 Production Deployment

### Backend

1. Set production environment variables in `.env`:
   ```env
   DEBUG=false
   DATABASE_URL=postgresql://user:pass@prod-db:5432/db
   JWT_SECRET=<strong-secret>
   GOOGLE_CLIENT_ID=<prod-client-id>
   CORS_ORIGINS=["https://your-app-domain.com"]
   ```

2. Deploy with Docker:
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

3. Use reverse proxy (nginx/Traefik) for HTTPS

4. Set up database backups

### Frontend

1. Update `baseUrl` in `http_data_service.dart`:
   ```dart
   defaultValue: 'https://your-backend-api.com'
   ```

2. Build release APK:
   ```bash
   flutter build apk --release --dart-define=API_BASE_URL=https://your-backend-api.com
   ```

3. Distribute via Google Play or internal deployment

---

## 📊 Monitoring & Logging

### Backend Logs

```bash
# View backend logs
docker-compose logs -f backend

# View database logs
docker-compose logs -f db
```

### Recommended Production Monitoring

- **Application Monitoring**: Sentry, Datadog
- **Database Monitoring**: pg_stat_statements, pgBadger
- **API Monitoring**: Prometheus + Grafana
- **Uptime Monitoring**: UptimeRobot, Pingdom

---

## 🧪 Testing

### Backend API Tests

```bash
# Example: Test authentication
curl -X POST http://localhost:8000/auth/google \
  -H "Content-Type: application/json" \
  -d '{"idToken": "<google-id-token>"}'

# Test with JWT
curl -X GET http://localhost:8000/users/me \
  -H "Authorization: Bearer <jwt-token>"
```

### Flutter Tests

```bash
cd frontend/
flutter test
```

---

## 🐛 Troubleshooting

### Backend won't start

- Check Docker is running: `docker ps`
- Check logs: `docker-compose logs backend`
- Verify `.env` file exists and is valid

### Database connection failed

- Ensure PostgreSQL is running: `docker-compose ps db`
- Check credentials in `.env` match `docker-compose.yml`

### Google auth fails

- Verify `GOOGLE_CLIENT_ID` is correct
- Ensure user email is in `allowed_emails` table
- Check backend logs for detailed error

### Flutter can't connect to backend

- Android Emulator: Use `http://10.0.2.2:8000` (not localhost)
- Physical device: Use your computer's LAN IP
- Check firewall allows port 8000

---

## 📝 TODO / Future Enhancements

- [ ] Offline support in Flutter with local SQLite cache
- [ ] WebSocket for real-time updates
- [ ] Admin dashboard web app
- [ ] Face recognition integration with detection confidence
- [ ] Audit logging for all data modifications
- [ ] Excel/CSV export of attendance reports
- [ ] Email notifications for low attendance
- [ ] Row-Level Security (RLS) in PostgreSQL
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Automated tests (pytest for backend, widget tests for Flutter)

---

## 👥 Contributors

- [Your Name/Team]

## 📄 License

[Your License]

---

## 🆘 Support

For issues:
1. Check the documentation: [backend/README.md](backend/README.md)
2. Review [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
3. Check logs: `docker-compose logs -f backend`
4. Open an issue on GitHub

---

**Built with ❤️ for AIMS DTU**
