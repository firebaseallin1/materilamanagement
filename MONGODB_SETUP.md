# MongoDB Integration - Quick Start Guide

## What Has Been Set Up

Your Material Management project now has:

### ✅ Backend (Node.js + Express + MongoDB)

- User authentication with JWT tokens
- Admin login with role-based access
- User management (CRUD operations)
- MongoDB integration
- Secure password hashing with bcryptjs
- CORS enabled for Flutter communication

### ✅ Flutter (Frontend)

- API service for HTTP communication
- Authentication provider with MongoDB backend
- Token-based authentication
- Local storage (SharedPreferences) for tokens
- User provider for user management

---

## Getting Started (5 Minutes)

### Step 1: Install MongoDB

**Choose One:**

**Option A: MongoDB Local (Recommended for Learning)**

- Download from: https://www.mongodb.com/try/download/community
- Install and run
- Default: `mongodb://localhost:27017/material_management`

**Option B: MongoDB Atlas (Cloud - Recommended for Production)**

- Sign up: https://www.mongodb.com/cloud/atlas
- Create free cluster
- Get connection string

### Step 2: Create Admin User

Open MongoDB CLI or MongoDB Compass and run:

```javascript
use material_management

db.users.insertOne({
  email: "admin@example.com",
  password: "$2a$10$dXJ3SW6G7P50SOK8ZHj0i.MYID8Rkpfj3Q3qF5FllOV4f3O0wWlJC",
  name: "System Admin",
  role: "admin",
  status: "active",
  createdAt: new Date(),
  updatedAt: new Date()
})
```

**Password for admin:** `adminpass123`

### Step 3: Start Backend Server

```bash
cd backend
npm install          # First time only
npm run dev          # Runs with auto-reload
```

**Expected output:**

```
Server running on port 5000
MongoDB connected: localhost
API Health Check: http://localhost:5000/api/health
```

### Step 4: Test Backend

Open browser or terminal:

```bash
curl http://localhost:5000/api/health
```

Should return: `{"success":true,"message":"Server is running",...}`

### Step 5: Update Flutter Configuration

Edit `lib/services/api_service.dart` and update API URL:

**For Android Emulator:**

```dart
static const String baseUrl = 'http://10.0.2.2:5000/api';
```

**For Physical Device (change IP to your computer):**

```dart
static const String baseUrl = 'http://192.168.1.100:5000/api';
```

### Step 6: Run Flutter App

```bash
flutter pub get
flutter run
```

### Step 7: Login

Use credentials:

- **Email:** `admin@example.com`
- **Password:** `adminpass123`

---

## API Endpoints Reference

### Authentication

```
POST /api/auth/admin-login
- Admin login only
- Returns JWT token

POST /api/auth/login
- Regular user login
- Returns JWT token
```

### User Management (Admin Only)

```
POST /api/users/create
- Create new user
- Requires: Authorization header with token

GET /api/users
- List all users

GET /api/users/profile
- Get current user profile

PUT /api/users/{userId}
- Update user

DELETE /api/users/{userId}
- Delete user
```

---

## Project Structure

```
material_management/
├── backend/                          # Node.js Backend
│   ├── server.js                    # Main server file
│   ├── package.json                 # Dependencies
│   ├── .env                         # Configuration
│   ├── models/
│   │   └── User.js                 # MongoDB User schema
│   ├── controllers/
│   │   ├── authController.js       # Auth logic
│   │   └── userController.js       # User management
│   ├── routes/
│   │   ├── authRoutes.js           # Auth endpoints
│   │   └── userRoutes.js           # User endpoints
│   ├── middleware/
│   │   └── auth.js                 # JWT verification
│   └── config/
│       └── database.js             # MongoDB connection
│
├── lib/                             # Flutter Frontend
│   ├── main.dart                    # App entry
│   ├── services/
│   │   └── api_service.dart        # API client
│   ├── providers/
│   │   ├── auth_provider.dart      # Auth state
│   │   ├── user_provider.dart      # User management
│   │   └── dashboard_provider.dart
│   └── screens/
│       ├── mobile/
│       └── web/
│
├── MONGODB_SETUP.md                # This file
├── FLUTTER_SETUP.md                # Flutter configuration
└── backend/README.md               # Backend detailed guide
```

---

## Key Features

### Authentication

- ✅ Admin login with MongoDB verification
- ✅ User login (mobile/web users)
- ✅ JWT token generation and validation
- ✅ Secure password hashing (bcryptjs)
- ✅ Token stored in SharedPreferences

### User Management

- ✅ Create users (admin only)
- ✅ View all users (admin only)
- ✅ Update user details (admin only)
- ✅ Delete users (admin only)
- ✅ User roles: admin, mobile_user, web_user
- ✅ User status: active, inactive

### Database

- ✅ MongoDB support (local or Atlas)
- ✅ Mongoose ORM
- ✅ Indexed fields for performance
- ✅ Created/Updated timestamps

---

## Troubleshooting

### Backend Won't Start

**Error: MongoDB connection failed**

- Is MongoDB running? `sudo systemctl status mongod`
- Check `.env` file has correct MONGODB_URI
- Try local connection: `mongodb://localhost:27017/material_management`

**Error: Port 5000 already in use**

```bash
# Kill process on port 5000
# Windows:
netstat -ano | findstr :5000
taskkill /PID {PID} /F

# Mac/Linux:
lsof -ti:5000 | xargs kill -9
```

### Flutter Can't Connect to Backend

**Error: Connection refused**

1. Verify backend is running: `http://localhost:5000/api/health`
2. Check API URL in `api_service.dart`
3. For emulator: Use `10.0.2.2` instead of `localhost`
4. For physical device: Use computer's local IP

**Error: CORS error**

- Backend has CORS enabled by default
- Check if different port is being used

### Login Fails

**"Invalid email or password"**

- Verify admin user exists in MongoDB
- Try creating user via API instead

**"No token provided"**

- Token might not be saved
- Clear app data and login again
- Check SharedPreferences permissions

---

## Testing with cURL

### Create Admin User (via API - Development Only)

```bash
# This endpoint is typically protected, use MongoDB directly instead
# See MongoDB CLI example above
```

### Admin Login

```bash
curl -X POST http://localhost:5000/api/auth/admin-login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"adminpass123"}'
```

### Create Mobile User (requires token from login)

```bash
curl -X POST http://localhost:5000/api/users/create \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "email":"mobile@example.com",
    "password":"pass123",
    "name":"Mobile User",
    "role":"mobile_user",
    "status":"active"
  }'
```

### Get All Users

```bash
curl -X GET http://localhost:5000/api/users \
  -H "Authorization: Bearer YOUR_TOKEN_HERE"
```

---

## Environment Variables

### Backend (.env file)

```env
# MongoDB Connection
MONGODB_URI=mongodb://localhost:27017/material_management

# For MongoDB Atlas
# MONGODB_URI=mongodb+srv://username:password@cluster.mongodb.net/material_management

# JWT Configuration
JWT_SECRET=your_secure_secret_key_here
JWT_EXPIRE=7d

# Server
PORT=5000
NODE_ENV=development
```

---

## Security Checklist

- [ ] Change `JWT_SECRET` in production
- [ ] Use HTTPS in production
- [ ] Add rate limiting for APIs
- [ ] Validate all inputs
- [ ] Use strong admin password
- [ ] Never commit `.env` with real credentials
- [ ] Use environment variables for sensitive data
- [ ] Implement API logging
- [ ] Add request validation

---

## Next Steps

1. ✅ Setup MongoDB
2. ✅ Create admin user
3. ✅ Start backend server
4. ✅ Configure Flutter API URL
5. ✅ Run Flutter app and login
6. **TODO:** Create user management screen
7. **TODO:** Add data models for materials/inventory
8. **TODO:** Create dashboard with real data
9. **TODO:** Add more features as needed

---

## Useful Commands

```bash
# Backend
npm install              # Install dependencies
npm run dev             # Start with auto-reload
npm start               # Production start

# Flutter
flutter pub get         # Get dependencies
flutter run             # Run app
flutter clean           # Clean build
flutter pub upgrade     # Update packages

# MongoDB (CLI)
mongosh                 # Start MongoDB shell
use material_management # Switch database
db.users.find()        # View all users
db.users.deleteMany({}) # Clear all users
```

---

## Resources

- [Express.js Documentation](https://expressjs.com/)
- [MongoDB Documentation](https://docs.mongodb.com/)
- [Flutter HTTP Guide](https://flutter.dev/docs/cookbook/networking)
- [JWT Documentation](https://jwt.io/)
- [Mongoose ORM](https://mongoosejs.com/)

---

## Support

For detailed backend setup: See `backend/README.md`
For detailed Flutter setup: See `FLUTTER_SETUP.md`

---

**You're all set! 🎉 Your MongoDB integration is complete. Happy coding!**
