# AIMS Attendance Backend

Production-grade backend API for the AIMS attendance tracking system. This backend replaces direct Firebase/Firestore access with a secure, scalable PostgreSQL-based system with proper authentication and authorization.

## 🏗️ Architecture

### System Overview

```
Flutter App (Frontend)
    ↓ (Google OAuth + API calls with JWT)
FastAPI Backend (Python)
    ↓ (SQL queries)
PostgreSQL Database
```

### Key Features

- ✅ **Secure Authentication**: Google OAuth → Internal JWT tokens
- ✅ **Role-Based Access Control (RBAC)**: Teacher and Admin roles with enforced permissions
- ✅ **RESTful API**: Clean, well-documented endpoints
- ✅ **Database Migrations**: Alembic for schema versioning
- ✅ **Attendance Tracking**: Sessions, statuses, and analytics
- ✅ **Student Management**: Roster management per class
- ✅ **Statistics**: Attendance summaries and percentages

---

## 📋 Prerequisites

- Python 3.11+
- PostgreSQL 16+
- Docker & Docker Compose (optional but recommended)
- Google Cloud Project with OAuth 2.0 credentials

---

## 🚀 Quick Start with Docker

### 1. Clone and Navigate

```bash
cd backend/
```

### 2. Configure Environment

**For Team Members (Recommended):**
```bash
# Use the .secrets file which contains all production credentials
./setup_env.sh
# OR manually: cp .secrets .env
```

**For New Setup:**
```bash
cp .env.example .env
```

Edit `.env` and set:

```env
# .env
DATABASE_URL=postgresql://aims:aims_pass@localhost:5433/attendance
JWT_SECRET=your-super-secret-key-min-32-chars
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
JWT_EXPIRATION_HOURS=1
DEBUG=true
```

**⚠️ IMPORTANT**: 
- Team members can use `.secrets` file (already committed) which has all credentials
- For new setup, generate a strong JWT secret:

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 3. Start Services

```bash
docker-compose up -d
```

This will start:
- **Backend API** on `http://localhost:8000`
- **PostgreSQL** on `localhost:5433`
- **pgAdmin** on `http://localhost:8080`

### 4. Run Migrations

```bash
docker-compose exec backend alembic upgrade head
```

### 5. Seed Allowed Emails

Edit `scripts/seed_allowed_emails.py` to add your faculty emails, then run:

```bash
docker-compose exec backend python scripts/seed_allowed_emails.py
```

### 6. Access the API

- **API Docs (Swagger)**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health
- **pgAdmin**: http://localhost:8080 (admin@local.com / admin123)

---

## 🛠️ Local Development (Without Docker)

### 1. Install Dependencies

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install packages
pip install -r requirements.txt
```

### 2. Setup PostgreSQL

Install PostgreSQL and create database:

```bash
createdb attendance
psql attendance < ../initdb/01_extensions.sql
```

### 3. Configure Environment

Create `.env` file (see Docker section above).

### 4. Run Migrations

```bash
alembic upgrade head
```

### 5. Seed Database

```bash
python scripts/seed_allowed_emails.py
```

### 6. Start Server

```bash
# Development with auto-reload
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Production with Gunicorn
gunicorn app.main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8000
```

---

## 📚 API Documentation

### Authentication Flow

#### 1. Google Sign-In (Frontend)

```dart
// Flutter obtains Google ID token
GoogleSignInAccount account = await _googleSignIn.signIn();
GoogleSignInAuthentication auth = await account.authentication;
String idToken = auth.idToken;
```

#### 2. Exchange for Backend JWT

```bash
curl -X POST http://localhost:8000/auth/google \
  -H "Content-Type: application/json" \
  -d '{
    "idToken": "<google-id-token>"
  }'
```

**Response:**

```json
{
  "token": "<backend-jwt-token>",
  "user": {
    "id": "uuid",
    "email": "teacher@dtu.ac.in",
    "name": "Dr. Teacher",
    "role": "teacher"
  }
}
```

#### 3. Use JWT for Subsequent Requests

```bash
curl -X GET http://localhost:8000/users/me \
  -H "Authorization: Bearer <backend-jwt-token>"
```

### Core Endpoints

#### Authentication

- `POST /auth/google` - Exchange Google ID token for backend JWT

#### User Management

- `GET /users/me` - Get current user profile

#### Classes

- `GET /classes` - List classes (filtered by role)
- `PUT /classes/{id}/students` - Update class roster

#### Attendance

- `POST /attendance/sessions` - Create attendance session
- `PUT /attendance/sessions/{id}/statuses` - Update student statuses
- `GET /attendance/sessions?classId=<uuid>&from=<date>&to=<date>` - Get sessions

#### Statistics

- `GET /stats/classes/{id}/students` - Get attendance summary

### Example: Taking Attendance

```bash
# 1. Create session
curl -X POST http://localhost:8000/attendance/sessions \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "classId": "<class-uuid>",
    "sessionDate": "2025-10-26",
    "processedImageUrl": "https://storage.example.com/evidence.jpg"
  }'

# Response: {"sessionId": "<session-uuid>", ...}

# 2. Mark attendance
curl -X PUT http://localhost:8000/attendance/sessions/<session-uuid>/statuses \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "updates": [
      {"rollNo": "23/CS/107", "status": "present", "recognizedByAi": true, "similarityScore": 92.5},
      {"rollNo": "23/CS/108", "status": "absent"}
    ]
  }'
```

---

## 🗄️ Database Schema

### Key Tables

1. **allowed_emails** - Whitelist of authorized users
2. **users** - Teachers and admins (app operators)
3. **students** - Student records
4. **classes** - Course sections taught by teachers
5. **class_schedules** - Weekly recurring schedules
6. **class_reschedules** - One-time schedule changes
7. **class_students** - Many-to-many enrollment
8. **attendance_sessions** - Attendance taking events
9. **attendance_statuses** - Per-student attendance records

### View

- **v_student_attendance_summary** - Aggregated attendance percentages

---

## 🔐 Security & RBAC

### Authorization Rules

#### Teachers Can:
- View/edit ONLY their own classes
- Create attendance sessions for their classes
- Update attendance statuses for their sessions
- View attendance stats for their classes

#### Admins Can:
- View/edit ANY class
- Create/update attendance for any class
- View stats for any class

### Implementation

All endpoints enforce ownership checks:

```python
# Example from class_service.py
if role != UserRole.ADMIN and cls.teacher_id != user_id:
    raise HTTPException(status_code=403, detail="Access denied")
```

### JWT Expiration

- Default: 1 hour
- On expiry, frontend must re-authenticate with Google

---

## 🔄 Database Migrations

### Create New Migration

```bash
alembic revision --autogenerate -m "Description of changes"
```

### Apply Migrations

```bash
alembic upgrade head
```

### Rollback Migration

```bash
alembic downgrade -1
```

### View Migration History

```bash
alembic history
alembic current
```

---

## 🧪 Testing

### Manual API Testing

Use the Swagger UI at http://localhost:8000/docs

### Testing Auth Flow

1. Get a Google ID token from: https://developers.google.com/oauthplayground/
2. Use the `/auth/google` endpoint
3. Use returned JWT for other endpoints

---

## 🐛 Troubleshooting

### Database Connection Issues

```bash
# Check if PostgreSQL is running
docker-compose ps

# View logs
docker-compose logs db
docker-compose logs backend
```

### Migration Errors

```bash
# Reset database (⚠️ DELETES ALL DATA)
docker-compose down -v
docker-compose up -d
docker-compose exec backend alembic upgrade head
```

### JWT Verification Errors

- Ensure `JWT_SECRET` in `.env` is set correctly
- Check that token hasn't expired (default 1 hour)
- Verify `Authorization: Bearer <token>` header format

### Google Auth Errors

- Verify `GOOGLE_CLIENT_ID` matches your OAuth 2.0 credentials
- Ensure email is in `allowed_emails` table
- Check Google token hasn't expired

---

## 📦 Project Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application
│   ├── config.py            # Environment configuration
│   ├── db.py                # Database session management
│   ├── models/              # SQLAlchemy ORM models
│   │   ├── user.py
│   │   ├── student.py
│   │   ├── class_model.py
│   │   └── attendance.py
│   ├── schemas/             # Pydantic request/response models
│   │   ├── auth.py
│   │   ├── users.py
│   │   ├── classes.py
│   │   ├── attendance.py
│   │   └── stats.py
│   ├── auth/                # Authentication utilities
│   │   ├── google_verify.py
│   │   ├── jwt.py
│   │   └── dependencies.py
│   ├── routes/              # API route handlers
│   │   ├── auth_routes.py
│   │   ├── user_routes.py
│   │   ├── class_routes.py
│   │   ├── attendance_routes.py
│   │   └── stats_routes.py
│   └── services/            # Business logic layer
│       ├── class_service.py
│       └── attendance_service.py
├── alembic/                 # Database migrations
│   ├── versions/
│   └── env.py
├── scripts/                 # Utility scripts
│   └── seed_allowed_emails.py
├── requirements.txt
├── Dockerfile
├── .env.example
└── README.md
```

---

## 🚢 Production Deployment

### Environment Variables for Production

```env
DEBUG=false
JWT_SECRET=<strong-secret-minimum-32-characters>
GOOGLE_CLIENT_ID=<production-google-client-id>
DATABASE_URL=postgresql://user:pass@prod-host:5432/db
CORS_ORIGINS=["https://your-frontend-domain.com"]
```

### Recommendations

1. **Use HTTPS**: Deploy behind a reverse proxy (nginx/Traefik) with SSL
2. **Database Security**: Use strong passwords, enable SSL connections
3. **JWT Secret**: Use a cryptographically secure random string (32+ chars)
4. **Rate Limiting**: Add rate limiting middleware for API endpoints
5. **Monitoring**: Set up logging and monitoring (Sentry, Datadog, etc.)
6. **Backups**: Regular PostgreSQL backups
7. **Audit Logging**: Log all attendance modifications (future enhancement)

---

## 📄 License

[Your License Here]

## 👥 Contributors

[Your Team Here]

---

## 🆘 Support

For issues or questions:
- Check the [API Documentation](http://localhost:8000/docs)
- Review logs: `docker-compose logs backend`
- Open an issue on GitHub
