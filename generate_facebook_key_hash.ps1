Write-Host "Generating Facebook Key Hash for HANAPP..." -ForegroundColor Green
Write-Host ""

# Check if keytool exists
try {
    $null = Get-Command keytool -ErrorAction Stop
    Write-Host "✓ keytool found" -ForegroundColor Green
} catch {
    Write-Host "✗ ERROR: keytool not found. Please ensure Java JDK is installed and in PATH." -ForegroundColor Red
    Write-Host "You can download it from: https://www.oracle.com/java/technologies/downloads/" -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

# Check if openssl exists
try {
    $null = Get-Command openssl -ErrorAction Stop
    Write-Host "✓ openssl found" -ForegroundColor Green
} catch {
    Write-Host "✗ ERROR: openssl not found. Please install OpenSSL." -ForegroundColor Red
    Write-Host "You can download it from: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    Write-Host "Or install Git for Windows which includes OpenSSL." -ForegroundColor Yellow
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host ""
Write-Host "Generating key hash for debug keystore..." -ForegroundColor Yellow
Write-Host ""

# Check if keystore exists
$keystorePath = "android\app\login.jks"
if (-not (Test-Path $keystorePath)) {
    Write-Host "✗ ERROR: Keystore not found at $keystorePath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    # Generate key hash for debug keystore
    $keyHash = & keytool -exportcert -alias test -keystore $keystorePath -storepass loginhanapp -keypass loginhanapp | & openssl sha1 -binary | & openssl base64

    Write-Host "🔑 Your Facebook Key Hash:" -ForegroundColor Green
    Write-Host $keyHash -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Copy the hash above and paste it in Facebook Developer Console under Key Hashes" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Note: This is for your debug keystore. For release, you'll need to generate" -ForegroundColor Gray
    Write-Host "    a separate hash using your release keystore." -ForegroundColor Gray

} catch {
    Write-Host "✗ ERROR: Failed to generate key hash: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
