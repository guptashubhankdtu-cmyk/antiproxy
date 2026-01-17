#!/bin/bash
# Setup script to create .env file from .secrets for team members

echo "=========================================="
echo "  AIMS Backend - Environment Setup"
echo "=========================================="
echo ""

# Check if .secrets exists
if [ ! -f ".secrets" ]; then
    echo "❌ Error: .secrets file not found!"
    echo "   Make sure you're in the backend/ directory"
    exit 1
fi

# Check if .env already exists
if [ -f ".env" ]; then
    echo "⚠️  Warning: .env file already exists"
    read -p "   Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "   Keeping existing .env file"
        exit 0
    fi
fi

# Copy .secrets to .env
cp .secrets .env

echo "✅ Created .env file from .secrets"
echo ""
echo "📝 Next steps:"
echo "   1. Review .env file (it contains production credentials)"
echo "   2. For local development, you may want to modify DATABASE_URL"
echo "   3. Run: source venv/bin/activate"
echo "   4. Run: pip install -r requirements.txt"
echo "   5. Run: uvicorn app.main:app --reload"
echo ""

