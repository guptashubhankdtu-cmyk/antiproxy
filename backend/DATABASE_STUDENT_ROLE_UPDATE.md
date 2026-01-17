# Database Update for Student Role

## Changes Made

### 1. Added 'student' to UserRole Enum in Database

The PostgreSQL `userrole` enum has been updated to include the 'student' value.

**Command executed:**
```sql
ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'student';
```

**Verification:**
```sql
SELECT enumlabel FROM pg_enum WHERE enumtypid = 'userrole'::regtype ORDER BY enumsortorder;
```

Result:
```
 enumlabel 
-----------
 teacher
 admin
 student
```

### 2. Updated Alembic Migration File

**File:** `backend/alembic/versions/001_initial.py`

The migration now creates the enum with all three values ('teacher', 'admin', 'student') from the start.
Additionally, if the enum already exists, it will add the 'student' value.

**Before:**
```python
user_role_enum = postgresql.ENUM('teacher', 'admin', name='userrole', create_type=False)
```

**After:**
```python
user_role_enum = postgresql.ENUM('teacher', 'admin', 'student', name='userrole', create_type=False)
user_role_enum.create(connection)
else:
    # If enum exists, ensure 'student' value is added
    connection.execute(sa.text(
        "ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'student'"
    ))
```

## For Fresh Database Installations

When running migrations on a fresh database, the enum will be created with all three values from the start:

```bash
cd backend
alembic upgrade head
```

## For Existing Databases

The enum value has already been added manually. Future migrations will also handle this automatically.

## Testing

Verify the enum has all values:
```bash
docker compose exec -T db psql -U aims -d attendance -c "SELECT enumlabel FROM pg_enum WHERE enumtypid = 'userrole'::regtype ORDER BY enumsortorder;"
```

Expected output:
```
 enumlabel 
-----------
 teacher
 admin
 student
(3 rows)
```

## Note

PostgreSQL does not support removing enum values once added, so the downgrade operation for this change is not possible. If you need to remove the 'student' value, you would need to:
1. Drop all tables using the enum
2. Drop the enum type
3. Recreate the enum without 'student'
4. Recreate all tables

This is generally not recommended in production.
