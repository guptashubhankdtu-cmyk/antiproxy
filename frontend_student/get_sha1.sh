#!/bin/bash

echo "🔑 Getting SHA-1 and SHA-256 fingerprints for Google Sign-In setup"
echo ""
echo "================================================"
echo "DEBUG KEYSTORE (for development)"
echo "================================================"
echo ""

# Debug keystore location
DEBUG_KEYSTORE="$HOME/.android/debug.keystore"

if [ -f "$DEBUG_KEYSTORE" ]; then
    keytool -list -v -keystore "$DEBUG_KEYSTORE" -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep -E "SHA1:|SHA256:"
    echo ""
    echo "✅ Debug keystore found"
else
    echo "❌ Debug keystore not found at: $DEBUG_KEYSTORE"
    echo "   Run your app once to generate it automatically"
fi

echo ""
echo "================================================"
echo "INSTRUCTIONS:"
echo "================================================"
echo ""
echo "1. Copy the SHA-1 fingerprint shown above"
echo "2. Go to: https://console.cloud.google.com/"
echo "3. Select your project (or create one)"
echo "4. Go to 'APIs & Services' > 'Credentials'"
echo "5. Create/Edit OAuth 2.0 Client ID for Android"
echo "6. Add the SHA-1 fingerprint"
echo "7. Package name: com.dtu.aims.aims_student_app"
echo ""
echo "Then update the serverClientId in lib/services/student_data_service.dart"
echo "with the Web Client ID (ending in .apps.googleusercontent.com)"
echo ""
