<#
  Membuat upload key untuk Play Store + android/key.properties.

  Pemakaian (dari folder proyek):
    powershell -ExecutionPolicy Bypass -File tool\buat_upload_key.ps1

  PENTING:
  - Simpan file .jks dan password-nya di tempat aman (mis. Google Drive pribadi).
    Kalau hilang, kamu tidak bisa memperbarui aplikasi tanpa meminta reset ke Google.
  - android/key.properties dan *.jks sudah ada di .gitignore. Jangan di-commit.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$jks = Join-Path $root 'android\upload-keystore.jks'
$props = Join-Path $root 'android\key.properties'

if (Test-Path $jks) { Write-Host "Sudah ada: $jks (hapus dulu kalau benar-benar ingin membuat ulang)" -ForegroundColor Yellow; exit 1 }

# keytool ikut terpasang bersama JDK (Android Studio / Eclipse Adoptium).
$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool -and $env:JAVA_HOME) { $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe' }
if (-not $keytool -or -not (Test-Path $keytool)) { Write-Host 'keytool tidak ditemukan. Pasang JDK 17 atau set JAVA_HOME.' -ForegroundColor Red; exit 1 }

Write-Host 'Password minimal 6 karakter. Password yang sama dipakai untuk keystore dan key.'
$secure = Read-Host 'Password upload key' -AsSecureString
$secure2 = Read-Host 'Ulangi password' -AsSecureString
$p1 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
$p2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure2))
if ($p1 -ne $p2) { Write-Host 'Password tidak sama.' -ForegroundColor Red; exit 1 }
if ($p1.Length -lt 6) { Write-Host 'Password terlalu pendek.' -ForegroundColor Red; exit 1 }

$nama = Read-Host 'Nama lengkap (untuk sertifikat)'
& $keytool -genkeypair -v -keystore $jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 `
  -alias upload -storepass $p1 -keypass $p1 -dname "CN=$nama, OU=PAPB, O=Racik, C=ID"
if ($LASTEXITCODE -ne 0) { exit 1 }

@"
storePassword=$p1
keyPassword=$p1
keyAlias=upload
storeFile=upload-keystore.jks
"@ | Set-Content -Path $props -Encoding ASCII
$p1 = $null; $p2 = $null

Write-Host ''
Write-Host "Selesai: $jks" -ForegroundColor Green
Write-Host "         $props" -ForegroundColor Green
Write-Host 'Cadangkan kedua file itu sekarang. Lalu build: flutter build appbundle --release --dart-define-from-file=env.json'
