Write-Host "Generating SHA-1 Fingerprint for Firebase Configuration..." -ForegroundColor Green
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

Write-Host ""
Write-Host "Generating SHA-1 fingerprint for your keystore..." -ForegroundColor Yellow
Write-Host ""

# Check if keystore exists
$keystorePath = "android\app\login.jks"
if (-not (Test-Path $keystorePath)) {
    Write-Host "✗ ERROR: Keystore not found at $keystorePath" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

try {
    Write-Host "🔐 Extracting SHA-1 fingerprint from your keystore..." -ForegroundColor Cyan
    Write-Host ""
    
    # Generate SHA-1 fingerprint
    $output = & keytool -list -v -keystore $keystorePath -alias test -storepass loginhanapp -keypass loginhanapp
    
    # Extract SHA-1 line
    $sha1Line = $output | Select-String "SHA1:"
    
    if ($sha1Line) {
        $sha1 = ($sha1Line -split "SHA1:")[1].Trim()
        
        Write-Host "🎯 Your SHA-1 Fingerprint for Firebase:" -ForegroundColor Green
        Write-Host $sha1 -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📋 Steps to add this to Firebase:" -ForegroundColor Yellow
        Write-Host "1. Go to Firebase Console: https://console.firebase.google.com/" -ForegroundColor White
        Write-Host "2. Select your project: hanapp-15bf7-38147" -ForegroundColor White
        Write-Host "3. Go to Project Settings (gear icon)" -ForegroundColor White
        Write-Host "4. Scroll down to 'Your apps' section" -ForegroundColor White
        Write-Host "5. Find your Android app (com.example.hanapp)" -ForegroundColor White
        Write-Host "6. Click 'Add fingerprint' button" -ForegroundColor White
        Write-Host "7. Paste the SHA-1 fingerprint above" -ForegroundColor White
        Write-Host "8. Click 'Save'" -ForegroundColor White
        Write-Host ""
        Write-Host "📝 Note: This SHA-1 is for your debug/development keystore." -ForegroundColor Gray
        Write-Host "    For production, you'll need to generate SHA-1 from your release keystore." -ForegroundColor Gray
        
    } else {
        Write-Host "✗ Could not extract SHA-1 fingerprint from keystore output" -ForegroundColor Red
        Write-Host ""
        Write-Host "Full keytool output:" -ForegroundColor Yellow
        Write-Host $output
    }
    
} catch {
    Write-Host "✗ ERROR: Failed to generate SHA-1 fingerprint: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Read-Host "Press Enter to exit"
