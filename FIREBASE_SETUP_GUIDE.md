# Firebase Setup Guide for HanApp

## Step 1: Create Firebase Project

1. **Go to Firebase Console:**
   - Visit: https://console.firebase.google.com/
   - Click **"Create a project"** or **"Add project"**

2. **Project Setup:**
   - Enter project name: `hanapp` (or your preferred name)
   - Enable Google Analytics (recommended)
   - Click **"Create project"**

## Step 2: Add Android App

1. **In Firebase Console:**
   - Click **"Add app"** (Android icon)
   - Enter package name: `com.example.hanapp`
   - Enter app nickname: "HanApp"
   - Click **"Register app"**

2. **Download google-services.json:**
   - Firebase will generate `google-services.json`
   - Download and place in: `android/app/google-services.json`
   - **Note:** This file should already exist from your previous setup

## Step 3: Configure Authentication

1. **Enable Google Sign-In:**
   - Go to **Authentication** in left sidebar
   - Click **"Get started"**
   - Click **"Sign-in method"** tab
   - Click **"Google"** in the list
   - Click **"Enable"**
   - Enter your support email
   - Click **"Save"**

## Step 4: Get Firebase Project ID

1. **In Firebase Console:**
   - Go to **Project Settings** (gear icon)
   - Copy your **Project ID** (e.g., `hanapp-12345`)

2. **Update Backend Configuration:**
   - Open `hanapp_backend/api/auth/google_auth.php`
   - Replace `'your-firebase-project-id'` with your actual project ID

## Step 5: Update Database Schema

You need to add a `firebase_uid` column to your users table:

```sql
ALTER TABLE users ADD COLUMN firebase_uid VARCHAR(128) UNIQUE;
ALTER TABLE users ADD COLUMN auth_provider VARCHAR(20) DEFAULT 'email';
```

Also create a sessions table:

```sql
CREATE TABLE user_sessions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    token VARCHAR(64) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);
```

## Step 6: Update Backend URL

1. **In GoogleAuthService:**
   - Open `lib/services/google_auth_service.dart`
   - Replace `'https://your-backend-url.com/api/auth/google_auth.php'` with your actual backend URL

## Step 7: Test the Setup

1. **Clean and rebuild:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Test Google Sign-In:**
   - Run the app
   - Try signing in with Google
   - Check console logs for any errors

## Troubleshooting

### Common Issues:

1. **"Invalid Firebase token" error:**
   - Make sure you've updated the Firebase project ID in the backend
   - Verify the `google-services.json` file is in the correct location

2. **"ApiException: 10" error:**
   - Add your SHA-1 fingerprint to Google Cloud Console
   - Use: `09:3C:25:E6:92:B5:F7:25:5E:D7:83:16:53:B9:A0:C0:6C:DB:D8:E7`

3. **Backend connection errors:**
   - Verify your backend URL is correct
   - Check that your backend server is running
   - Ensure CORS is properly configured

### Debug Information:

The app will print debug information on startup showing:
- Google Sign-In configuration status
- SHA-1 fingerprints
- Troubleshooting steps

## Benefits of Firebase Integration:

1. **Better Security:** Firebase handles token verification
2. **Automatic User Management:** Firebase manages user sessions
3. **Cross-Platform:** Works on Android, iOS, and Web
4. **Analytics:** Built-in user analytics
5. **Scalability:** Firebase scales automatically

## Next Steps:

After successful setup, you can:
1. Add more authentication providers (Facebook, Apple)
2. Implement user profile management
3. Add push notifications
4. Set up Firebase Analytics
5. Configure Firebase Cloud Messaging

## Support:

If you encounter issues:
1. Check the debug output in the console
2. Verify all configuration steps
3. Test with a clean build
4. Check Firebase Console for any error messages 