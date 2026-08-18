# Mobile Sales Canvassing Application - Installation Guide

Complete installation guide for **your** Mobile Sales Canvassing Application including backend (Node.js/Express), frontend (Flutter), and PostgreSQL database setup.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Project Structure](#project-structure)
3. [Backend Installation](#backend-installation)
4. [Database Setup](#database-setup)
5. [Frontend Installation](#frontend-installation)
6. [Configuration](#configuration)
7. [Running the Application](#running-the-application)
8. [Default Users](#default-users)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

**For Backend:**
- Node.js (v18 or higher)
- npm (comes with Node.js)
- Git

**For Frontend:**
- Flutter SDK (v3.0.0 or higher)
- Dart SDK (included with Flutter)
- Android Studio / Xcode (for mobile development)
- Visual Studio Code (recommended IDE)

**Cloud Services (Production):**
- Supabase account (for PostgreSQL database)
- Railway account (for backend deployment)

**For Development:**
- Postman or similar API testing tool

### System Requirements

**Minimum:**
- 8GB RAM
- 20GB free disk space
- Windows 10/11, macOS, or Linux

**Recommended:**
- 16GB RAM
- 50GB free disk space
- SSD for better performance

---

## Project Structure

**Your Mobile Sales Canvassing Application Structure:**

```
sales_canvassing/
├── sales_canvassing_backend/    # Node.js/Express backend API
│   ├── server.js               # Main server with RESTful API endpoints
│   ├── db.js                   # PostgreSQL database connection
│   ├── .env                    # Environment configuration
│   ├── package.json            # Backend dependencies
│   └── scripts/                # Database setup scripts
│       ├── migrate-v2.sql      # Database schema & tables
│       └── set-dev-passwords.js # Default user passwords
│
├── sales_canvassing_app/       # Flutter mobile application
│   ├── lib/                    # Dart source code
│   │   ├── main.dart          # App entry point with role-based navigation
│   │   ├── screens/           # 18 feature screens
│   │   │   ├── login_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── admin_dashboard.dart
│   │   │   ├── supervisor_dashboard.dart
│   │   │   ├── visits_screen.dart
│   │   │   ├── route_planning_screen.dart
│   │   │   ├── gps_tracking_screen.dart
│   │   │   ├── order_taking_screen.dart
│   │   │   ├── stock_screen.dart
│   │   │   ├── collections_screen.dart
│   │   │   ├── analytics_screen.dart
│   │   │   ├── outlet_screen.dart
│   │   │   ├── merchandising_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── rep_detail_screen.dart
│   │   │   ├── add_edit_rep_screen.dart
│   │   │   ├── products_admin_screen.dart
│   │   │   ├── promotions_screen.dart
│   │   │   └── stock_upload_screen.dart
│   │   ├── services/          # 15 API service files
│   │   ├── models/            # 10 data models
│   │   └── widgets/           # Custom UI components
│   ├── pubspec.yaml           # Flutter dependencies
│   └── android/               # Android configuration
│
└── docs/                       # Documentation files
```

**Application Features:**
- Multi-role system (Admin, Manager, Supervisor, Sales Representative)
- GPS tracking and location-based visit management
- Order taking and sales management
- Stock management with Excel upload
- Collections and payment tracking
- Outlet management and assignment
- Route planning and optimization
- Analytics and reporting
- Merchandising and planogram management

---

## Backend Installation

### Step 1: Navigate to Backend Directory

```bash
cd sales_canvassing_backend
```

### Step 2: Install Dependencies

```bash
npm install
```

This will install all required packages for **your** backend API:
- express - Web framework for RESTful API
- pg - PostgreSQL database client
- cors - Cross-origin resource sharing middleware
- helmet - Security headers for HTTP protection
- bcrypt - Password hashing for user authentication
- jsonwebtoken - JWT token generation and validation
- multer - File upload handling for Excel imports
- xlsx - Excel file processing for data import/export
- express-rate-limit - Rate limiting to prevent abuse
- dotenv - Environment variable management

### Step 3: Create Environment File

Copy the example environment file:

```bash
copy .env.example .env
```

Edit the `.env` file with your configuration:

```env
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_postgres_password
DB_NAME=sales_canvassing
JWT_SECRET=generate-a-strong-random-secret-key-at-least-32-characters-long
```

**Important:**
- Replace `your_postgres_password` with your actual PostgreSQL password
- Generate a strong JWT_SECRET (minimum 32 characters)
- Keep this file secure and never commit it to version control

---

## Database Setup (Supabase)

### Step 1: Create Supabase Project

1. Go to https://supabase.com and sign up/login
2. Click "New Project"
3. Enter project name: `sales-canvassing`
4. Set database password (save this securely)
5. Choose region closest to your users
6. Click "Create new project"
7. Wait for project to be created (2-3 minutes)

### Step 2: Get Database Connection Details

1. Go to your Supabase project dashboard
2. Navigate to Settings → Database
3. Copy the following information:
   - **Host:** (e.g., db.xxx.supabase.co)
   - **Port:** 5432
   - **Database Name:** postgres
   - **Username:** postgres
   - **Password:** (the password you set during project creation)

### Step 3: Configure Environment Variables

Update your `.env` file with Supabase credentials:

```env
DB_HOST=db.xxx.supabase.co
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_supabase_password
DB_NAME=postgres
JWT_SECRET=generate-a-strong-random-secret-key-at-least-32-characters-long
```

**Important:** Replace the values with your actual Supabase credentials.

### Step 4: Run Database Migration via Supabase SQL Editor

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor (in the left sidebar)
3. Click "New Query"
4. Open the file: `sales_canvassing_backend/scripts/migrate-v2.sql`
5. Copy the entire SQL script content
6. Paste it into the Supabase SQL Editor
7. Click "Run" to execute the script

This will create all required tables for **your** application:
- **User Management:** employee, user_account, team, team_member
- **Outlet Management:** outlet, outlet_assignment, outlet_rep_balance
- **Visit Management:** visit, geofence, route
- **Sales Management:** sales_order, order_detail, product
- **Payment Management:** payment, collection
- **Inventory Management:** stock, stock_history
- **Supporting Tables:** Various indexes and triggers for data integrity

### Step 5: Setup Default Passwords

After running the SQL migration, set up default user passwords:

```bash
cd sales_canvassing_backend
node scripts/set-dev-passwords.js
```

This will set the following default credentials:
- admin / admin
- manager / manager
- repa / repa
- repb / repb
- supervisor / supervisor

**Note:** This script connects to your Supabase database using the credentials in your `.env` file.

---

## Frontend Installation

### Step 1: Install Flutter SDK

1. Download Flutter SDK from https://flutter.dev/docs/get-started/install
2. Extract the zip file to a location of your choice
3. Add Flutter to your PATH:

**Windows:**
```powershell
# Add to System Environment Variables
# Path: C:\flutter\bin
```

**macOS/Linux:**
```bash
export PATH="$PATH:/path/to/flutter/bin"
```

4. Verify installation:
```bash
flutter doctor
```

Follow the instructions to fix any issues reported by `flutter doctor`.

### Step 2: Set Up Development Environment

**For Android Development:**
1. Install Android Studio
2. Install Android SDK (API level 21 or higher)
3. Configure Android SDK in Android Studio
4. Accept Android licenses:
```bash
flutter doctor --android-licenses
```

**For iOS Development (macOS only):**
1. Install Xcode from Mac App Store
2. Install Xcode command line tools:
```bash
xcode-select --install
```
3. Accept Xcode license:
```bash
sudo xcodebuild -license
```

### Step 3: Navigate to Frontend Directory

```bash
cd sales_canvassing_app
```

### Step 4: Install Flutter Dependencies

```bash
flutter pub get
```

This will install all required packages for **your** Flutter app:
- flutter_map - OpenStreetMap integration for outlet mapping
- latlong2 - Latitude/longitude coordinate handling
- geolocator - GPS and location services for tracking
- file_picker - File selection for Excel import/export
- path_provider - File system access for local storage
- permission_handler - Runtime permissions (location, storage)
- http - HTTP client for API communication with backend
- intl - Date/time formatting for visits and orders
- fl_chart - Chart visualization for analytics dashboard
- shared_preferences - Local storage for JWT tokens and user data

### Step 5: Configure API Endpoint

Edit `lib/services/api_client.dart` and update the base URL:

```dart
static const String baseUrl = 'http://localhost:3000/api';
```

For production, replace with your actual server URL.

---

## Configuration

### Backend Configuration

**Server Port:**
Default port is 3000. To change, edit `server.js`:

```javascript
const PORT = 3000; // Change to your preferred port
```

**CORS Settings:**
Update allowed origins in `server.js`:

```javascript
const allowedOrigins = [
  'http://localhost:3000',
  'http://localhost:8080',
  'https://your-production-domain.com' // Add your domain
];
```

**Rate Limiting:**
Adjust rate limits in `server.js`:

```javascript
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Max requests per window
});
```

### Frontend Configuration

**API Configuration:**
Update API base URL in `lib/services/api_client.dart`

**Location Permissions:**
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

For iOS, add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs access to location for visit tracking.</string>
```

---

## Running the Application

### Starting the Backend

```bash
cd sales_canvassing_backend
node server.js
```

You should see:
```
✅ Database module loaded
📥 Server running on port 3000
```

**Your** backend API provides these main endpoints:
- Authentication: `/api/auth/login`, `/api/auth/profile`
- Dashboard: `/api/dashboard`
- Sales Reps: `/api/admin/sales-reps`
- Outlets: `/api/outlets`
- Visits: `/api/visits`
- Orders: `/api/orders`
- Analytics: `/api/analytics/sales`

Test the server:
```bash
curl http://localhost:3000/api/test
```

### Starting the Frontend

**Your** Flutter app will launch with role-based navigation:

**For Android:**
```bash
cd sales_canvassing_app
flutter run
```

**For iOS (macOS only):**
```bash
cd sales_canvassing_app
flutter run -d ios
```

**For Web (development):**
```bash
cd sales_canvassing_app
flutter run -d chrome
```

**App Navigation by Role:**
- **Admin/Manager:** Opens Admin Dashboard with team management
- **Supervisor:** Opens Supervisor Dashboard with monitoring tools
- **Sales Representative:** Opens Main Navigation with 11 feature screens

### Running Both Simultaneously

Open two terminal windows:

**Terminal 1 - Backend:**
```bash
cd sales_canvassing_backend
node server.js
```

**Terminal 2 - Frontend:**
```bash
cd sales_canvassing_app
flutter run
```

---

## Default Users

After completing the installation, you can log in to **your** app with these default credentials:

### Admin
- **Username:** admin
- **Password:** admin
- **Role:** Full system access, manage all users and outlets
- **Access:** Admin Dashboard with full management capabilities

### Manager
- **Username:** manager
- **Password:** manager
- **Role:** Team management and analytics
- **Access:** Admin Dashboard with team oversight

### Supervisor
- **Username:** supervisor
- **Password:** supervisor
- **Role:** Team monitoring and support
- **Access:** Supervisor Dashboard with monitoring tools

### Sales Representatives
- **Username:** repa
- **Password:** repa
- **Role:** Field sales operations
- **Access:** 11 feature screens (Dashboard, Visits, Route Planning, GPS Tracking, Order Taking, Stock, Collections, Analytics, Merchandising, Outlets, Settings)

- **Username:** repb
- **Password:** repb
- **Role:** Field sales operations
- **Access:** Same 11 feature screens as repa

**⚠️ Important:** Change these default passwords in production for **your** application security!

---

## Troubleshooting

### Backend Issues

**Database Connection Error:**
```
Error: connect ECONNREFUSED 127.0.0.1:5432
```
**Solution for **your** app:**
- Ensure PostgreSQL is running
- Check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD in .env
- Verify database name `sales_canvassing` exists
- Ensure db.js connection settings are correct

**JWT_SECRET Error:**
```
ERROR: JWT_SECRET environment variable tidak di-set!
```
**Solution:**
- Create .env file from .env.example in **your** backend directory
- Set a strong JWT_SECRET value (minimum 32 characters)
- Restart the server after updating .env

**Module Not Found:**
```
Error: Cannot find module 'express'
```
**Solution:**
```bash
cd sales_canvassing_backend
npm install
```

### Frontend Issues

**Flutter Doctor Issues:**
```bash
flutter doctor
```
Follow the instructions to fix reported issues for **your** Flutter environment.

**Dependency Resolution:**
```bash
cd sales_canvassing_app
flutter pub get
flutter clean
flutter pub get
```

**API Connection Error:**
- Ensure **your** backend is running on port 3000
- Check API URL in `lib/services/api_client.dart`
- Verify CORS configuration in **your** backend server.js
- Ensure both backend and frontend are running

**Location Permission Denied:**
- Enable location permissions in device settings
- Check permission configuration in AndroidManifest.xml / Info.plist for **your** app
- Ensure geolocator package is properly configured

### Database Issues (Supabase)

**Migration Script Fails in Supabase:**
- Ensure your Supabase project is active and running
- Check that you have the correct database credentials in .env
- Verify the SQL script is copied completely to Supabase SQL Editor
- Check Supabase logs for specific error messages
- Ensure Supabase project has sufficient resources

**Connection Refused to Supabase:**
- Verify DB_HOST is correct (should be db.xxx.supabase.co)
- Check DB_PASSWORD matches your Supabase project password
- Ensure Supabase project is not paused
- Check your internet connection
- Verify Supabase project region is accessible

**Password Setup Fails:**
```bash
# Ensure .env file exists in **your** backend directory with Supabase credentials
cd sales_canvassing_backend
node scripts/set-dev-passwords.js
```

### Port Conflicts

**Port 3000 Already in Use:**
```bash
# Windows
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# macOS/Linux
lsof -ti:3000 | xargs kill -9
```

Or change the port in **your** `server.js` file.

---

## Development Tips

### Backend Development

**Auto-restart during development:**
```bash
npm install -g nodemon
nodemon server.js
```

**View API logs:**
All requests to **your** backend are logged to console with format:
```
📥 GET /api/dashboard
📥 POST /api/auth/login
📥 PUT /api/visits/1/check-in
```

### Frontend Development

**Hot Reload:**
Flutter supports hot reload - press `r` in terminal to reload **your** app without restarting.

**Debug Mode:**
Run in debug mode for detailed logging of **your** Flutter app:
```bash
flutter run --debug
```

**Build for Release:**
```bash
# Android
flutter build apk

# iOS
flutter build ios
```

**Test Specific Screens:**
You can directly test specific screens of **your** app by modifying the initial route in main.dart.

---

## Production Deployment

### Backend Deployment (Railway)

#### Step 1: Prepare Your Backend for Railway

1. Ensure your backend code is in a Git repository (GitHub, GitLab, or Bitbucket)
2. Verify your `.env.example` file exists with all required variables
3. Update your `package.json` to include a start script:

```json
{
  "scripts": {
    "start": "node server.js"
  }
}
```

#### Step 2: Deploy to Railway

1. Go to https://railway.app and sign up/login
2. Click "New Project" → "Deploy from GitHub repo"
3. Select your repository containing the backend code
4. Railway will detect it as a Node.js project automatically
5. Click "Deploy"

#### Step 3: Configure Environment Variables in Railway

1. After deployment, go to your Railway project
2. Navigate to the "Variables" tab
3. Add the following environment variables:

```env
DB_HOST=db.xxx.supabase.co
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_supabase_password
DB_NAME=postgres
JWT_SECRET=your-strong-jwt-secret-minimum-32-characters
```

4. Replace with your actual Supabase credentials
5. Click "Save Changes" to restart the service

#### Step 4: Get Your Railway API URL

1. In Railway, go to your deployed service
2. Copy the "Public URL" (e.g., https://your-app.railway.app)
3. This is your production API base URL

#### Step 5: Run Database Migration on Supabase

Since your database is on Supabase, run the migration:

1. Go to Supabase SQL Editor
2. Run the `migrate-v2.sql` script
3. Run the password setup script locally:
```bash
cd sales_canvassing_backend
node scripts/set-dev-passwords.js
```

### Frontend Deployment

1. Build release version of **your** Flutter app:
```bash
flutter build apk --release
```

2. Update API URL in **your** `lib/services/api_client.dart` to your Railway URL:
```dart
static const String baseUrl = 'https://your-app.railway.app/api';
```

3. Upload to Google Play Store or distribute via other means

4. Configure production environment variables

---

## Cloud Service Configuration

### Supabase Configuration

**Enable Connection Pooling:**
1. Go to your Supabase project dashboard
2. Navigate to Settings → Database
3. Enable "Connection Pooling" for better performance
4. Note the connection pool URL if needed

**Configure Database Backups:**
1. Supabase provides automatic daily backups
2. Enable point-in-time recovery if needed
3. Set up backup retention period in Supabase settings

**Security Settings:**
1. Enable Row Level Security (RLS) if needed for additional data isolation
2. Configure API restrictions in Supabase dashboard
3. Set up database user permissions appropriately

### Railway Configuration

**Automatic Deployments:**
1. Railway automatically deploys when you push to GitHub
2. Configure branch-specific deployments if needed
3. Set up preview deployments for pull requests

**Monitoring:**
1. Railway provides built-in monitoring and logs
2. Set up alerts for service downtime
3. Monitor resource usage and scaling needs

**Domain Configuration:**
1. Add custom domain in Railway settings (optional)
2. Configure SSL certificates (Railway provides automatic SSL)
3. Update CORS settings in your backend to allow your custom domain

**Environment Variables:**
- All sensitive data should be in Railway Variables
- Railway provides encryption for environment variables
- Never hardcode credentials in your code

---

## Security Considerations for Your App

1. **Change Default Passwords:** Immediately change all default passwords in **your** production environment
2. **Secure JWT_SECRET:** Use a strong, randomly generated secret for **your** JWT authentication (set in Railway Variables)
3. **Enable HTTPS:** Railway provides automatic SSL/TLS for your API endpoints
4. **Database Security:** Use strong database passwords for your Supabase project
5. **Supabase Security:** Enable RLS (Row Level Security) if needed for additional data protection
6. **Railway Security:** Keep your Railway project private and secure
7. **Regular Updates:** Keep dependencies updated for **your** Node.js and Flutter packages
8. **Backup:** Supabase provides automatic backups - verify backup retention settings
9. **Rate Limiting:** **Your** app already includes rate limiting - monitor and adjust as needed
10. **CORS Configuration:** Update allowed origins in **your** backend to allow your Railway domain
11. **Environment Variables:** Never commit .env file - use Railway Variables for production secrets
12. **API Security:** Consider implementing API rate limiting per user in production

---

## Support for Your App

For issues or questions with **your** Mobile Sales Canvassing Application:
- Check the troubleshooting section specific to **your** app
- Review Railway logs for error messages from **your** backend
- Check Supabase logs for database-related issues
- Verify all configuration settings in **your** Railway Variables and api_client.dart
- Ensure all prerequisites are properly installed for **your** development environment
- Check that **your** database migration was successful in Supabase SQL Editor
- Verify **your** Flutter dependencies are correctly installed
- Ensure Railway deployment is active and running
- Check Supabase project is not paused

---

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Node.js Documentation](https://nodejs.org/docs)
- [Express.js Documentation](https://expressjs.com)
- [Supabase Documentation](https://supabase.com/docs)
- [Railway Documentation](https://docs.railway.app)

---

## Development Workflow with Cloud Services

### Local Development with Supabase

1. Use your Supabase database for both development and production
2. Keep your `.env` file with Supabase credentials for local development
3. Run backend locally: `node server.js`
4. Test with Flutter app connected to local backend
5. When ready, push to GitHub for Railway deployment

### CI/CD with Railway

1. Railway automatically deploys when you push to main branch
2. Use feature branches for development
3. Pull requests trigger preview deployments
4. Merge to main for production deployment
5. Monitor Railway logs for deployment issues

### Database Management

1. Use Supabase Dashboard for database management
2. SQL Editor for running queries and migrations
3. Table Editor for viewing and editing data
4. Real-time subscriptions for live data updates (if needed)
5. Database backups are automatic in Supabase

---

**Last Updated:** July 2026
**Version:** 1.0.0
**Cloud Services:** Supabase (PostgreSQL), Railway (Backend)
