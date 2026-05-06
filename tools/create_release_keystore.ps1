$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$androidDir = Join-Path $projectRoot "android"
$keyPath = Join-Path $androidDir "app\veloce-express-release-key.jks"
$propertiesPath = Join-Path $androidDir "key.properties"
$keyAlias = "veloce"

if (Test-Path -LiteralPath $keyPath) {
    throw "Keystore already exists: $keyPath"
}

$keytool = "keytool"
$keytoolCandidates = @(
    "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe",
    "C:\Program Files\Java\jdk-17\bin\keytool.exe",
    "C:\Program Files\Java\jdk-21.0.10\bin\keytool.exe"
)

foreach ($candidate in $keytoolCandidates) {
    if (Test-Path -LiteralPath $candidate) {
        $keytool = $candidate
        break
    }
}

if ($keytool -eq "keytool" -and -not (Get-Command keytool -ErrorAction SilentlyContinue)) {
    throw "keytool was not found. Install JDK 17 or add keytool.exe to PATH."
}

function Convert-ToPlainText([securestring]$value) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

Write-Host "Creating Veloce Express Android release keystore..."
Write-Host "Save the passwords and the .jks file. Losing them means you cannot update installed APKs."

$storePassword = Convert-ToPlainText (Read-Host "Keystore password" -AsSecureString)
$keyPassword = Convert-ToPlainText (Read-Host "Key password" -AsSecureString)

& $keytool `
    -genkeypair `
    -v `
    -keystore $keyPath `
    -storepass $storePassword `
    -keypass $keyPassword `
    -alias $keyAlias `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -dname "CN=zakarya haimed, OU=veloce, O=veloce, L=ain el hadjel, ST=msila, C=DZ"

@"
storePassword=$storePassword
keyPassword=$keyPassword
keyAlias=$keyAlias
storeFile=app/veloce-express-release-key.jks
"@ | Set-Content -LiteralPath $propertiesPath -Encoding UTF8

Write-Host "Created:"
Write-Host "  $keyPath"
Write-Host "  $propertiesPath"
Write-Host ""
Write-Host "Next build command:"
Write-Host "  C:\flutter\bin\flutter.bat build apk --release --split-per-abi --tree-shake-icons"
