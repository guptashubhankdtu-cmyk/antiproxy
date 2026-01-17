# DTU AIMS - iOS Development Information
**Date:** January 14, 2026  
**Project:** DTU AIMS Attendance System  
**GCP Project:** antiproxy-dtu (Project ID: 612272896050)

---

## 🌐 Deployed Services URLs

### Backend API
```
https://dtu-aims-backend-612272896050.asia-south1.run.app
```

### Bluetooth Check-in Sidecar
```
https://dtu-aims-bt-sidecar-612272896050.asia-south1.run.app
```
**API Key:** `dtuAimsBTSidecar2026SecureKey`

### Health Check Endpoints
- Backend Health: `GET https://dtu-aims-backend-612272896050.asia-south1.run.app/health`
- Expected Response: `{"status":"healthy","service":"AIMS Attendance Backend"}`

---

## 🔐 OAuth 2.0 Configuration

### Google Cloud Project
- **Project:** antiproxy-dtu
- **Project ID:** 612272896050
- **Region:** asia-south1

### Web Client ID (for Backend)
```
612272896050-gu0k89o9jrhleseadphcceg4jlbvmsp3.apps.googleusercontent.com
```
**IMPORTANT:** Use this Client ID in your GoogleSignIn configuration!

### iOS OAuth Credentials
You need to create iOS OAuth Client IDs in the Google Cloud Console:

1. Go to: https://console.cloud.google.com/apis/credentials?project=antiproxy-dtu
2. Click "Create Credentials" → "OAuth client ID"
3. Select "iOS" as application type
4. For **Teacher App:**
   - Name: `DTU AIMS Teacher App (iOS)`
   - Bundle ID: `com.dtuaims.antiproxy.teacher` (use this for consistency with Android)
5. For **Student App:**
   - Name: `DTU AIMS Student App (iOS)`
   - Bundle ID: `com.dtuaims.antiproxy.student`

### OAuth Consent Screen Status
- **User Type:** External
- **Publishing Status:** Testing
- **App Name:** DTU Attendance
- **Scopes:** `userinfo.email`, `openid`
- **Test Users:** Currently only `shubhankgupta165@gmail.com`
  - **Action Required:** Add your test email at: https://console.cloud.google.com/apis/credentials/consent?project=antiproxy-dtu

---

## 📱 Application Configuration

### Bundle IDs (Use These!)
- **Teacher App:** `com.dtuaims.antiproxy.teacher`
- **Student App:** `com.dtuaims.antiproxy.student`

### Code Changes Required in iOS

#### 1. Update Backend URLs
In your data service files (wherever you make API calls):

**Teacher App:**
```swift
let baseURL = "https://dtu-aims-backend-612272896050.asia-south1.run.app"
let sidecarURL = "https://dtu-aims-bt-sidecar-612272896050.asia-south1.run.app"
let sidecarApiKey = "dtuAimsBTSidecar2026SecureKey"
```

**Student App:**
```swift
let baseURL = "https://dtu-aims-backend-612272896050.asia-south1.run.app"
let sidecarURL = "https://dtu-aims-bt-sidecar-612272896050.asia-south1.run.app"
let sidecarApiKey = "dtuAimsBTSidecar2026SecureKey"
```

#### 2. Update GoogleSignIn Configuration
```swift
// In your GoogleSignIn setup
GIDSignIn.sharedInstance.configuration = GIDConfiguration(
    clientID: "612272896050-gu0k89o9jrhleseadphcceg4jlbvmsp3.apps.googleusercontent.com"
)

// Scopes to request
let scopes = ["email", "profile"]
```

#### 3. Info.plist Configuration
Add your iOS OAuth Client ID to Info.plist:
```xml
<key>GIDClientID</key>
<string>612272896050-gu0k89o9jrhleseadphcceg4jlbvmsp3.apps.googleusercontent.com</string>

<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <!-- This will be your iOS client ID reversed -->
            <string>com.googleusercontent.apps.612272896050-YOUR_IOS_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

---

## 🗄️ Database Information

### Cloud SQL Instance
- **Instance:** dtu-aims-attendance-db
- **Public IP:** 34.180.39.58
- **Database:** dtu_aims_attendance
- **Status:** ✅ Running with all tables initialized

### Allowed Emails (for login)
Currently only:
- `shubhankgupta165@gmail.com` (Teacher role)

To add your email for testing, contact us or add directly to `allowed_emails` table.

---

## 🔑 API Authentication Flow

### 1. Google Sign-In
```
Client → Google OAuth → Get ID Token
```

### 2. Backend Authentication
```
POST https://dtu-aims-backend-612272896050.asia-south1.run.app/auth/google
Content-Type: application/json

{
  "id_token": "<GOOGLE_ID_TOKEN>"
}
```

**Response (Success):**
```json
{
  "access_token": "<JWT_TOKEN>",
  "user": {
    "id": "<UUID>",
    "email": "user@example.com",
    "name": "User Name",
    "role": "teacher"
  }
}
```

### 3. Authenticated Requests
Include JWT in header:
```
Authorization: Bearer <JWT_TOKEN>
```

---

## 📋 Key API Endpoints

### Authentication
- `POST /auth/google` - Google OAuth login
- `GET /auth/me` - Get current user info

### Classes (Teacher)
- `GET /classes/` - List teacher's classes
- `POST /classes/` - Create new class
- `GET /classes/{class_id}` - Get class details
- `PUT /classes/{class_id}` - Update class
- `DELETE /classes/{class_id}` - Delete class

### Students (Teacher)
- `GET /classes/{class_id}/students` - List students in class
- `POST /students/bulk-upload` - Upload students via CSV/XLSX
- `GET /students/{enrollment_no}` - Get student details

### Attendance Sessions (Teacher)
- `POST /attendance/start-session` - Start attendance session
- `GET /attendance/sessions/{session_id}` - Get session details
- `POST /attendance/sessions/{session_id}/end` - End session
- `GET /attendance/sessions/{session_id}/report` - Get attendance report

### Bluetooth Sidecar (Teacher)
- `POST /start-session` - Start BT monitoring
- `GET /session-status/{room_code}` - Check session status
- `POST /stop-session` - Stop BT monitoring

**Note:** All sidecar requests need header:
```
X-API-Key: dtuAimsBTSidecar2026SecureKey
```

### Student Endpoints
- `GET /student/attendance` - Get my attendance records
- `POST /student/mark-attendance` - Mark attendance (with QR/face/BT proof)
- `GET /student/classes` - Get enrolled classes

---

## 🧪 Testing Instructions

### 1. OAuth Setup
1. Add your email as test user in OAuth Consent Screen
2. Create iOS OAuth Client IDs (if not done)
3. Update bundle IDs in Xcode to match: `com.dtuaims.antiproxy.teacher` or `.student`

### 2. Test Google Sign-In
- Should successfully authenticate with Google
- Backend should return JWT token
- If error 10: Check OAuth Client ID and bundle ID match

### 3. Test API Calls
Use the JWT token to test authenticated endpoints:
```bash
curl -H "Authorization: Bearer <JWT_TOKEN>" \
  https://dtu-aims-backend-612272896050.asia-south1.run.app/auth/me
```

---

## 🐛 Common Issues & Solutions

### Issue 1: OAuth Error 10
**Cause:** OAuth Client ID doesn't match project or bundle ID mismatch  
**Solution:** 
- Verify using Web Client ID: `612272896050-gu0k89o9jrhleseadphcceg4jlbvmsp3...`
- Check bundle ID matches iOS OAuth credential
- Add email to test users in OAuth Consent Screen

### Issue 2: Backend 500 Error
**Cause:** Database tables not initialized  
**Solution:** ✅ Already fixed - all tables created

### Issue 3: Backend 401/403 Error
**Cause:** Email not in allowed_emails table  
**Solution:** Contact us to add your email to whitelist

### Issue 4: Bluetooth Sidecar 403
**Cause:** Missing or incorrect API key  
**Solution:** Add header: `X-API-Key: dtuAimsBTSidecar2026SecureKey`

---

## 📞 Contact & Support

- **Android Developer:** shubhankgupta165@gmail.com
- **GCP Console:** https://console.cloud.google.com/?project=antiproxy-dtu
- **OAuth Credentials:** https://console.cloud.google.com/apis/credentials?project=antiproxy-dtu

---

## 🚀 Quick Start Checklist for iOS

- [ ] Create iOS OAuth Client IDs in GCP Console
- [ ] Update bundle IDs to `com.dtuaims.antiproxy.teacher` / `.student`
- [ ] Add your email as test user in OAuth Consent Screen
- [ ] Update backend URL in code to Cloud Run URL
- [ ] Update GoogleSignIn clientID to Web Client ID
- [ ] Configure Info.plist with OAuth settings
- [ ] Test Google Sign-In flow
- [ ] Test API authentication with JWT token
- [ ] Test Bluetooth sidecar integration (if applicable)

---

## 📝 Notes

1. **Database is initialized** with all required tables (users, students, classes, attendance_sessions, etc.)
2. **OAuth Consent Screen is configured** but in Testing mode - only whitelisted emails can sign in
3. **All services are deployed** and running in `asia-south1` region
4. **Android apps are working** - same configuration should work for iOS
5. **No Firebase** - we're using direct Google OAuth, not Firebase Auth

---

**Last Updated:** January 14, 2026  
**Status:** ✅ Backend Operational | ✅ Database Initialized | ✅ Android Apps Working
