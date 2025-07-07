@echo off
echo Generating Facebook Key Hash for HANAPP...
echo.

REM Check if keytool exists
where keytool >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: keytool not found. Please ensure Java JDK is installed and in PATH.
    echo You can download it from: https://www.oracle.com/java/technologies/downloads/
    pause
    exit /b 1
)

REM Check if openssl exists
where openssl >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: openssl not found. Please install OpenSSL.
    echo You can download it from: https://slproweb.com/products/Win32OpenSSL.html
    echo Or install Git for Windows which includes OpenSSL.
    pause
    exit /b 1
)

echo Generating key hash for debug keystore...
echo.

REM Generate key hash for debug keystore
keytool -exportcert -alias test -keystore android\app\login.jks -storepass loginhanapp -keypass loginhanapp | openssl sha1 -binary | openssl base64

echo.
echo Copy the generated hash above and paste it in Facebook Developer Console.
echo.
echo If you need the release key hash later, use your release keystore instead.
echo.
pause
