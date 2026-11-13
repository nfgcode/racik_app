<#
  Tes endpoint API Supabase yang dipakai Racik.

  Pemakaian (dari folder proyek):
    powershell -ExecutionPolicy Bypass -File tool\test_supabase_api.ps1
    powershell -ExecutionPolicy Bypass -File tool\test_supabase_api.ps1 -Login   # + tes login

  URL dan publishable key dibaca dari env.json, jadi tidak perlu ditulis di sini.
  Semua tes hanya MEMBACA data. Tidak ada insert/update/delete.
#>
param([switch]$Login)

$ErrorActionPreference = 'Stop'
# Windows PowerShell 5.1 bawaannya masih TLS lama; Supabase butuh TLS 1.2.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$envFile = Join-Path $PSScriptRoot '..\env.json'
if (-not (Test-Path $envFile)) { Write-Host 'env.json tidak ditemukan. Salin env.example.json lalu isi.' -ForegroundColor Red; exit 1 }
$cfg = Get-Content $envFile -Raw | ConvertFrom-Json
$base = $cfg.SUPABASE_URL.TrimEnd('/')
$key = $cfg.SUPABASE_KEY

# Header wajib untuk setiap request ke Supabase:
#   apikey        -> menandai proyek mana yang dipanggil
#   Authorization -> siapa yang memanggil (anon = publishable key, atau token login)
$anon = @{ apikey = $key; Authorization = "Bearer $key" }

$script:lulus = 0
$script:gagal = 0

function Invoke-Api {
  param([string]$Method = 'GET', [string]$Path, [hashtable]$Headers = $anon, $Body = $null)
  $req = @{ Uri = "$base$Path"; Method = $Method; Headers = $Headers; UseBasicParsing = $true }
  if ($null -ne $Body) { $req.Body = ($Body | ConvertTo-Json -Compress); $req.ContentType = 'application/json' }
  try {
    $r = Invoke-WebRequest @req
    $json = $null
    if ($r.Content) { $json = $r.Content | ConvertFrom-Json }
    return [pscustomobject]@{ Status = [int]$r.StatusCode; Json = $json; Raw = $r.Content }
  } catch [System.Net.WebException] {
    if ($null -eq $_.Exception.Response) {
      # Tidak ada balasan sama sekali: DNS/jaringan, bukan error dari Supabase.
      if ($_.Exception.Message -match 'could not be resolved') {
        Write-Host ''
        Write-Host "Host $(([uri]$base).Host) tidak ditemukan." -ForegroundColor Red
        Write-Host 'Kemungkinan proyek Supabase sedang di-pause. Buka dashboard Supabase lalu klik Restore project.' -ForegroundColor Yellow
        exit 2
      }
      throw
    }
    $raw = $_.ErrorDetails.Message
    $json = $null
    try { $json = $raw | ConvertFrom-Json } catch {}
    return [pscustomobject]@{ Status = [int]$_.Exception.Response.StatusCode; Json = $json; Raw = $raw }
  }
}

function Test-Api {
  param([string]$Name, [scriptblock]$Request, [scriptblock]$Check, [string]$Expect)
  $res = & $Request
  $ok = & $Check $res
  $preview = "$($res.Raw)"
  if ($preview.Length -gt 110) { $preview = $preview.Substring(0, 110) + '...' }
  if ($ok) { $script:lulus++; Write-Host ("[LULUS] {0}  (HTTP {1})" -f $Name, $res.Status) -ForegroundColor Green }
  else { $script:gagal++; Write-Host ("[GAGAL] {0}  (HTTP {1}, harusnya {2})" -f $Name, $res.Status, $Expect) -ForegroundColor Red }
  Write-Host "        $preview" -ForegroundColor DarkGray
}

Write-Host "Menguji $base" -ForegroundColor Cyan
Write-Host ''

# -- REST (PostgREST): /rest/v1/<tabel>?<filter> -----------------------------
Test-Api '1. Daftar resep terverifikasi' `
  { Invoke-Api -Path '/rest/v1/foods?select=id,name,category&is_verified=eq.true&order=name' } `
  { param($r) $r.Status -eq 200 -and @($r.Json).Count -gt 0 } '200 + minimal 1 resep'

Test-Api '2. Cari nama (ilike *soto*)' `
  { Invoke-Api -Path '/rest/v1/foods?select=name&name=ilike.*soto*' } `
  { param($r) $r.Status -eq 200 } '200'

Test-Api '3. Detail resep + relasi (nutrisi, langkah, bahan)' `
  { Invoke-Api -Path '/rest/v1/foods?select=name,nutritions(*),steps(*),food_ingredients(*,ingredients(*))&is_verified=eq.true&limit=1' } `
  { param($r) $r.Status -eq 200 -and @($r.Json).Count -eq 1 -and $null -ne $r.Json[0].steps } '200 + relasi ikut'

Test-Api '4. Daftar kategori' `
  { Invoke-Api -Path '/rest/v1/foods?select=category&is_verified=eq.true&category=not.is.null' } `
  { param($r) $r.Status -eq 200 } '200'

# -- RPC: fungsi SQL dipanggil lewat POST /rest/v1/rpc/<nama_fungsi> ---------
$acak = 'tes_api_' + (Get-Random -Maximum 999999)
Test-Api '5. RPC username_available (username acak)' `
  { Invoke-Api -Method POST -Path '/rest/v1/rpc/username_available' -Body @{ p_username = $acak } } `
  { param($r) $r.Status -eq 200 -and $r.Raw -eq 'true' } '200 + true'

# -- Row Level Security: tamu tidak boleh membaca tabel users ----------------
Test-Api '6. RLS: tamu membaca tabel users' `
  { Invoke-Api -Path '/rest/v1/users?select=username&limit=5' } `
  { param($r) $r.Status -eq 200 -and @($r.Json).Count -eq 0 } '200 + [] (kosong)'

# -- Auth: /auth/v1/... ------------------------------------------------------
Test-Api '7. Layanan Auth aktif (login email)' `
  { Invoke-Api -Path '/auth/v1/settings' -Headers @{ apikey = $key } } `
  { param($r) $r.Status -eq 200 -and $r.Json.external.email -eq $true } '200 + email aktif'

# -- Contoh error: kolom tidak ada -> 400 dengan pesan dari PostgREST ---------
Test-Api '8. Error 400 bila kolom salah' `
  { Invoke-Api -Path '/rest/v1/foods?select=kolom_tidak_ada' } `
  { param($r) $r.Status -eq 400 } '400'

# -- Opsional: login lalu baca profil sendiri --------------------------------
if ($Login) {
  Write-Host ''
  $email = Read-Host 'Email akun Racik'
  $secure = Read-Host 'Password' -AsSecureString
  $plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
  $tok = Invoke-Api -Method POST -Path '/auth/v1/token?grant_type=password' -Headers @{ apikey = $key } -Body @{ email = $email; password = $plain }
  $plain = $null
  if ($tok.Status -ne 200) {
    $script:gagal++
    Write-Host "[GAGAL] 9. Login  (HTTP $($tok.Status))  $($tok.Raw)" -ForegroundColor Red
  } else {
    $script:lulus++
    Write-Host "[LULUS] 9. Login  (HTTP 200, token berlaku $($tok.Json.expires_in) detik)" -ForegroundColor Green
    # Request berikutnya memakai token login, bukan publishable key.
    $user = @{ apikey = $key; Authorization = "Bearer $($tok.Json.access_token)" }
    $uid = $tok.Json.user.id
    Test-Api '10. Profil sendiri (RLS mengizinkan)' `
      { Invoke-Api -Path "/rest/v1/users?select=username,full_name&id=eq.$uid" -Headers $user } `
      { param($r) $r.Status -eq 200 -and @($r.Json).Count -eq 1 } '200 + 1 baris'
  }
}

Write-Host ''
$warna = 'Green'; if ($script:gagal -gt 0) { $warna = 'Red' }
Write-Host ("Hasil: {0} lulus, {1} gagal" -f $script:lulus, $script:gagal) -ForegroundColor $warna
if ($script:gagal -gt 0) { exit 1 }
