#!/usr/bin/env python3
"""Test database and backend services"""
import psycopg2
import sys

# Test database connection
print("="*80)
print("TESTING POSTGRESQL DATABASE CONNECTION")
print("="*80)

db_url = "postgresql://aims:aims_pass@localhost:5433/attendance"

try:
    conn = psycopg2.connect(db_url)
    print("✅ Database connection successful!")
    
    cur = conn.cursor()
    
    # Check version
    cur.execute("SELECT version()")
    version = cur.fetchone()[0]
    print(f"📊 PostgreSQL version: {version[:80]}...")
    
    # Check tables
    cur.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public'")
    table_count = cur.fetchone()[0]
    print(f"📋 Number of tables: {table_count}")
    
    # List tables
    cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' ORDER BY table_name")
    tables = cur.fetchall()
    print(f"\n📁 Tables:")
    for table in tables:
        print(f"   - {table[0]}")
    
    conn.close()
    print("\n✅ Database is ready!")
    sys.exit(0)
    
except Exception as e:
    print(f"❌ Database connection failed: {e}")
    sys.exit(1)
