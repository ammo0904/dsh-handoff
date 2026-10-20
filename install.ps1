# DSH 交接安裝腳本（2026-10-20）
# 用法： powershell -ExecutionPolicy Bypass -File .\install.ps1
#   可選： -Root <擴充套件解壓位置>  -ProfileName <profile，預設 web>
[CmdletBinding()]
param(
  [string]$Root = (Join-Path $env:USERPROFILE 'dsh-extensions'),
  [string]$ProfileName = 'web',
  [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$QuoteZipUrl = 'https://github.com/ammo0904/dsh-quote-helper/releases/download/v2.7.0/dsh-quote-helper-V2.7.zip'
$BrowserExtUrl = 'https://github.com/caob23/dsh-browser-control/releases/download/v1.0.17/DSH-Browser-Control-v1.0.17.zip'
$PluginName = '@caob23/dsh-browser-control'
$QuoteDir = Join-Path $Root 'DSH引用助手-V2'
$BrowserDir = Join-Path $Root 'DSH-Browser-Control'

function Write-Step($text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }
function Write-Ok($text) { Write-Host "  [OK] $text" -ForegroundColor Green }
function Write-Warn2($text) { Write-Host "  [!] $text" -ForegroundColor Yellow }
function Write-Info($text) { Write-Host "  $text" }

# PowerShell 5.1 的 Get-Content 會把 UTF-8 中文讀成 ANSI，JSON 會壞掉 → 一律用 .NET 讀
function Read-TextUtf8($path) {
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  return $text.TrimStart([char]0xFEFF)
}

function Get-ManifestVersion($path) {
  try { return ((Read-TextUtf8 $path) | ConvertFrom-Json).version } catch { return '?' }
}

Write-Host "DSH 交接安裝（2026-10-20）" -ForegroundColor Magenta

# ---------------------------------------------------------------- 1. 環境檢查
Write-Step '1/4 檢查環境'
$missing = @()
foreach ($tool in @('node', 'pnpm', 'dsh')) {
  $cmd = Get-Command $tool -ErrorAction SilentlyContinue
  if ($cmd) { Write-Ok ("{0}  {1}" -f $tool, $cmd.Source) } else { Write-Warn2 "$tool 找不到"; $missing += $tool }
}
if ($missing -contains 'pnpm') { Write-Warn2 '補救：npm i -g pnpm' }
if ($missing -contains 'dsh') { Write-Warn2 '補救：npm i -g @deepseek-ai/dsh' }
if ($missing.Count -gt 0) {
  Write-Host "`n缺少必要工具，補齊後重跑本腳本。" -ForegroundColor Red
  exit 2
}

# ---------------------------------------------------------- 2. 安裝 DSH 插件
Write-Step '2/4 安裝 DSH 插件（browser control）'
$profilePkg = Join-Path $env:USERPROFILE (".dsh\profiles\$ProfileName\package.json")
$already = $false
if (Test-Path $profilePkg) {
  try {
    $pkg = (Read-TextUtf8 $profilePkg) | ConvertFrom-Json
    $already = [bool]($pkg.dependencies.PSObject.Properties.Name -contains $PluginName)
  } catch { $already = $false }
}
if ($already) {
  Write-Ok "$PluginName 已在 $ProfileName profile 中，跳過安裝"
} else {
  Write-Info "執行：dsh plugin --profile $ProfileName add $PluginName"
  dsh plugin --profile $ProfileName add $PluginName
  if ($LASTEXITCODE -ne 0) {
    Write-Warn2 '安裝失敗，改用官方 registry 重試一次…'
    dsh plugin --profile $ProfileName add $PluginName --registry=https://registry.npmjs.org/
    if ($LASTEXITCODE -ne 0) { Write-Host '  插件安裝失敗，請看上面的錯誤訊息。' -ForegroundColor Red; exit 4 }
  }
  Write-Ok '插件安裝完成'
}

# ------------------------------------------------------------ 3. 下載擴充套件
Write-Step '3/4 下載並解壓擴充套件'
New-Item -ItemType Directory -Force -Path $Root | Out-Null
$tmp = Join-Path $env:TEMP ('dsh-handoff-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Get-Zip($url, $dest) {
  try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    return $true
  } catch {
    Write-Warn2 ("下載失敗：{0} → {1}" -f $url, $_.Exception.Message)
    return $false
  }
}

$quoteZip = "$tmp\quote.zip"
$browserZip = "$tmp\browser.zip"
$ok1 = Get-Zip $QuoteZipUrl $quoteZip
$ok2 = Get-Zip $BrowserExtUrl $browserZip
if (-not ($ok1 -and $ok2)) {
  Write-Host "`n有檔案下載失敗（通常是網路或代理問題），可手動下載後解壓到 $Root" -ForegroundColor Red
  Write-Info '引用助手：https://github.com/ammo0904/dsh-quote-helper/releases'
  Write-Info 'Browser Control：https://github.com/caob23/dsh-browser-control/releases'
  exit 3
}

if (Test-Path $QuoteDir) { Remove-Item $QuoteDir -Recurse -Force }
Expand-Archive -Path $quoteZip -DestinationPath $Root -Force
if (Test-Path $BrowserDir) { Remove-Item $BrowserDir -Recurse -Force }
New-Item -ItemType Directory -Force -Path $BrowserDir | Out-Null
Expand-Archive -Path $browserZip -DestinationPath $BrowserDir -Force
Remove-Item $quoteZip, $browserZip -Force -ErrorAction SilentlyContinue

$quoteVer = '?'
$qv = Join-Path $QuoteDir 'manifest.json'
if (Test-Path $qv) { $quoteVer = Get-ManifestVersion $qv }
$browserVer = '?'
$bv = Join-Path $BrowserDir 'manifest.json'
if (Test-Path $bv) { $browserVer = Get-ManifestVersion $bv }

Write-Ok "DSH 引用助手 v$quoteVer → $QuoteDir"
Write-Ok "DSH Browser Control v$browserVer → $BrowserDir"

# ------------------------------------------------------------------ 4. 收尾
Write-Step '4/4 收尾：剩下這幾步要人手按'
Write-Host @"
  1) 開瀏覽器的擴充套件頁（brave://extensions 或 chrome://extensions）
  2) 打開「開發人員模式」
  3) 「載入未解壓縮的擴展」→ 選 $QuoteDir
  4) 再一次 → 選 $BrowserDir
  5) 確認：引用助手版本 $quoteVer；Browser Control 圖示綠點呼吸
  6) 關掉 dsh web 視窗後重新啟動（外掛要重啟才載入）

  驗證： powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\verify.ps1"
"@ -ForegroundColor White

if (-not $NoOpen) { Start-Process explorer.exe $Root }
Write-Host "`n完成（exit 0）。" -ForegroundColor Green
exit 0
