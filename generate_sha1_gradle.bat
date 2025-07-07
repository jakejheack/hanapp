@echo off
echo Generating SHA-1 Fingerprints using Gradle...
echo.

echo Checking for gradlew...
if not exist "android\gradlew.bat" (
    echo ERROR: gradlew.bat not found in android directory
    echo Make sure you're running this from the Flutter project root
    pause
    exit /b 1
)

echo.
echo Generating SHA-1 fingerprints for your keystores...
echo.

cd android

echo === Custom Keystore (login.jks) SHA-1 ===
gradlew signingReport

echo.
echo === Instructions ===
echo Look for the SHA1 fingerprint in the output above.
echo Copy the SHA1 value and add it to Firebase Console.
echo.
echo Steps to add to Firebase:
echo 1. Go to https://console.firebase.google.com/
echo 2. Select project: hanapp-15bf7-38147
echo 3. Go to Project Settings (gear icon)
echo 4. Find your Android app: com.example.hanapp
echo 5. Click "Add fingerprint"
echo 6. Paste the SHA1 value
echo 7. Save
echo.

cd ..
pause
