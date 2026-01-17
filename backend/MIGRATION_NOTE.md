"""
Database Migration Note for Student App
========================================

The student app implementation does NOT require any database schema changes.
The existing schema already supports all student functionality.

However, you may want to create an Alembic migration to document the UserRole enum change
if you're using strict database migrations.

To create a migration (optional):

```bash
cd backend
alembic revision -m "add_student_role"
```

Then edit the generated migration file to add:

```python
from alembic import op
import sqlalchemy as sa

def upgrade():
    # Add STUDENT role to UserRole enum (if your DB enforces enum types)
    # For PostgreSQL:
    op.execute("ALTER TYPE userrole ADD VALUE IF NOT EXISTS 'student'")

def downgrade():
    # Note: PostgreSQL does not support removing enum values
    # You would need to recreate the enum type
    pass
```

Then run:

```bash
alembic upgrade head
```

⚠️ Note: If you're using SQLite for development, enum changes are not enforced
    at the database level, so no migration is needed.

⚠️ Note: For production PostgreSQL, if the enum constraint doesn't exist yet,
    this migration will ensure the 'student' value is available.
"""
