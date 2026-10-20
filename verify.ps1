# DSH 交接驗證腳本（2026-10-20）
# 用法： powershell -ExecutionPolicy Bypass -File .\verify.ps1
[CmdletBinding()]
param(
  [string]$Root = (Join-Path $env:USERPROFILE 'dsh-extensions'),
  [string]$ProfileName = 'web'
)

$ErrorActionPreference = 'Continue'
$fail = 0

function Check($name, $pass, $detail) {
  if ($pass) {
    Write-Host ("  [PASS] {0}  {1}" -f $name, $detail) -ForegroundColor Green
  } else {
    Write-Host ("  [FAIL] {0}  {1}" -f $name, $detail) -ForegroundColor Red
    $script:fail += 1
  }
}

# 一定要用 UTF8 讀（PowerShell 5.1 的 Get-Content 會把 UTF-8 中文讀成 ANSI 而讓 JSON 壞掉）
function Read-TextUtf8($path) {
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  return $text.TrimStart([char]0xFEFF)
}

function Get-ManifestVersion($path) {
  try { return ((Read-TextUtf8 $path) | ConvertFrom-Json).version } catch { return '?' }
}

Write-Host "DSH 交接驗證" -ForegroundColor Magenta

Write-Host "`n-- 擴充套件檔案 --" -ForegroundColor Cyan
$quoteManifest = Join-Path $Root 'DSH引用助手-V2\manifest.json'
$browserManifest = Join-Path $Root 'DSH-Browser-Control\manifest.json'
Check '引用助手資料夾' (Test-Path $quoteManifest) $quoteManifest
Check 'Browser Control 資料夾' (Test-Path $browserManifest) $browserManifest

if (Test-Path $quoteManifest) {
  $v = Get-ManifestVersion $quoteManifest
  Check '引用助手版本 = 2.7.0' ($v -eq '2.7.0') "實際 v$v"
}
if (Test-Path $browserManifest) {
  $v2 = Get-ManifestVersion $browserManifest
  Check 'Browser Control 版本 = 1.0.17' ($v2 -eq '1.0.17') "實際 v$v2"
}

Write-Host "`n-- DSH 插件 --" -ForegroundColor Cyan
$profilePkg = Join-Path $env:USERPROFILE (".dsh\profiles\$ProfileName\package.json")
if (Test-Path $profilePkg) {
  $raw = Get-Content $profilePkg -Raw
  Check 'browser-control 已列入依賴' ($raw -match 'dsh-browser-control') $profilePkg
  Check 'browser-control 已列入 bundles' ($raw -match '"@caob23/dsh-browser-control"') 'dsh.profile.bundles'
} else {
  Check 'profile package.json 存在' $false $profilePkg
}

Write-Host "`n-- 執行中服務 --" -ForegroundColor Cyan
$bridge = Get-NetTCPConnection -LocalPort 9777 -State Listen -ErrorAction SilentlyContinue
Check 'bridge 監聽 9777' ([bool]$bridge) $(if ($bridge) { 'listening' } else { '沒有在聽：DSH 還沒重啟或插件沒載入' })

$web = Get-NetTCPConnection -LocalPort 3080 -State Listen -ErrorAction SilentlyContinue
Check 'DSH web 監聽 3080' ([bool]$web) $(if ($web) { 'listening' } else { 'DSH web 沒在跑' })

Write-Host "`n-- 需要人在瀏覽器確認的項目 --" -ForegroundColor Cyan
Write-Host '  1. 擴充套件頁裡「DSH 引用助手」是不是 2.7.0（popup 標題旁 v2.7.0）'
Write-Host '  2. 「DSH Browser Control」圖示是不是綠點呼吸（已連線）'
Write-Host '  3. 對 DSH 說「用 browser_info 看有沒有連上」→ 應回 dsh-browser-extension 1.0.17'
Write-Host '  4. DSH 頁面框選文字 → 按「引用」→ 應出現 “…” 且游標在下一行，右下跳「已引用（雙引號 · v2.7.0）」'

Write-Host ''
if ($fail -eq 0) {
  Write-Host '自動檢查全數通過（人工項目請照上面確認）。' -ForegroundColor Green
  exit 0
} else {
  Write-Host ("有 {0} 項未通過，請看上面紅字。" -f $fail) -ForegroundColor Red
  exit 1
}
