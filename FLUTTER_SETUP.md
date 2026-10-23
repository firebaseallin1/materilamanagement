# Flutter App - MongoDB Integration Setup

## Prerequisites

- Flutter 3.0.0 or higher
- Dart 3.0.0 or higher
- Your backend server running (see `backend/README.md`)

## Configuration Steps

### 1. Update API URL

Open `lib/services/api_service.dart` and update the `baseUrl` based on your setup:

**For Development (different platforms):**

- **Android Emulator**: `http://10.0.2.2:5000/api`
- **iOS Simulator**: `http://localhost:5000/api`
- **Physical Device**: `http://YOUR_COMPUTER_IP:5000/api`
- **Web**: `http://localhost:5000/api`

Example: If you're testing on Android emulator with backend running on your Windows PC at IP 192.168.1.100:

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

### 2. Get Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

## Flutter Architecture

### File Structure

```
lib/
├── main.dart                 # App entry point
├── services/
│   └── api_service.dart     # API communication with backend
├── providers/
│   ├── auth_provider.dart   # Authentication state management
│   └── user_provider.dart   # User management (create new file)
├── screens/
│   ├── mobile/
│   │   ├── login_mobile.dart
│   │   └── dashboard_mobile.dart
│   └── web/
│       ├── login_web.dart
│       └── dashboard_web.dart
└── responsive/
    ├── login_responsive.dart
    └── dashboard_responsive.dart
```

## Testing the Connection

### 1. Verify Backend is Running

```bash
curl http://localhost:5000/api/health
```

Should return:

```json
{
  "success": true,
  "message": "Server is running"
}
```

### 2. Create First Admin User

Using curl (Windows - use PowerShell or WSL):

```bash
curl -X POST http://localhost:5000/api/auth/admin-login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"adminpass123"}'
```

**Note:** No admin exists yet. Use MongoDB CLI to create first admin:

```bash
mongosh  # or mongo for older versions
use material_management

# Create admin user with bcrypted password
db.users.insertOne({
  email: "admin@example.com",
  password: "$2a$10$dXJ3SW6G7P50SOK8ZHj0i.MYID8Rkpfj3Q3qF5FllOV4f3O0wWlJC", // password: adminpass123
  name: "System Admin",
  role: "admin",
  status: "active",
  createdAt: new Date(),
  updatedAt: new Date()
})
```

### 3. Test Admin Login in Flutter

Create a simple test:

```dart
void testAdminLogin() async {
  final apiService = ApiService();
  try {
    final response = await apiService.adminLogin(
      'admin@example.com',
      'adminpass123'
    );
    print('Login successful: $response');
  } catch (e) {
    print('Login failed: $e');
  }
}
```

## Network Configuration

### Android

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

### iOS

Edit `ios/Runner/Info.plist`:

```xml
<key>NSBonjourServices</key>
<array>
  <string>_http._tcp</string>
</array>
```

### Allow HTTP for Development

For Android 9+, HTTP is blocked by default. Edit `android/app/src/main/res/values/strings.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <string name="app_name">material_management</string>
</resources>
```

Create `android/app/src/main/res/xml/network_security_config.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">10.0.2.2</domain>
        <domain includeSubdomains="true">localhost</domain>
        <domain includeSubdomains="true">192.168.1.0</domain>
    </domain-config>
</network-security-config>
```

Add to `AndroidManifest.xml`:

```xml
android:networkSecurityConfig="@xml/network_security_config"
```

## Common Issues & Solutions

### "Connection refused" Error

- Ensure backend is running: `npm run dev` in backend folder
- Check if PORT 5000 is correct
- Verify firewall isn't blocking port 5000

### "Network is unreachable"

- Check API URL in `api_service.dart`
- For emulator: Use `10.0.2.2` instead of `localhost`
- For physical device: Use your computer's local IP (e.g., 192.168.1.100)

### "CORS Error"

- Ensure backend has CORS middleware enabled (it does by default)
- Check Content-Type headers are correct

### "Invalid Token" Error

- Token might have expired (default: 7 days)
- Clear app data and login again
- Check if token is being saved to SharedPreferences

## Authentication Flow

```
User enters email/password
          ↓
Flutter validates input
          ↓
Sends to Backend API
          ↓
Backend validates with MongoDB
          ↓
If valid: Returns JWT token
          ↓
Flutter stores token in SharedPreferences
          ↓
Token included in all future API requests
```

## Next Steps

1. ✅ Backend setup completed
2. ✅ Flutter API service created
3. ✅ Auth provider updated
4. Next: Create User Management Provider
5. Next: Create Admin User Management Screen

## Files Modified

- `pubspec.yaml` - Added dio and shared_preferences
- `lib/providers/auth_provider.dart` - Updated with API calls
- `lib/services/api_service.dart` - Created (NEW)

## Dependencies Added

- **dio**: HTTP client for making API requests
- **shared_preferences**: Local storage for tokens and user data

## Database Connection String Examples

**Local MongoDB:**

```
mongodb://localhost:27017/material_management
```

**MongoDB Atlas (Cloud):**

```
mongodb+srv://username:password@cluster-name.mongodb.net/material_management?retryWrites=true&w=majority
```

## Additional Resources

- [Dio Documentation](https://pub.dev/packages/dio)
- [SharedPreferences Documentation](https://pub.dev/packages/shared_preferences)
- [Flutter HTTP Best Practices](https://flutter.dev/docs/cookbook/networking)
