# Build a portable, self-contained Style-Bert-VITS2 folder for Windows.
#
# Produced layout:
#   dist\StyleBertVITS2-Portable\
#       StyleBertVITS2.exe        <- launcher, compiled from packaging\launcher.cs
#       README.txt
#       app.py, gradio_tabs\, style_bert_vits2\, configs\, dict_data\, static\
#       bert\, model_assets\, slm\   <- runtime assets
#       Data\                        <- empty folder, required by configs\paths.yml
#       runtime\python\              <- standalone CPython + the venv's site-packages
#
# Usage (double-click is fine):
#   BUILD_EXE.bat                 normal rebuild, keeps already copied files
#   BUILD_EXE.bat clean           wipe dist first
#   BUILD_EXE.bat fullbert        also ship the Chinese / English BERT models
#
# No Python installation is required on the target machine.

[CmdletBinding()]
param(
    [string]$Dest = '',
    [switch]$Clean,
    [switch]$IncludeAllBert,
    [switch]$SkipDependencyCheck
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($Dest)) {
    $Dest = Join-Path $ProjectRoot 'dist\StyleBertVITS2-Portable'
}
$Dest = [System.IO.Path]::GetFullPath($Dest)

$Venv         = Join-Path $ProjectRoot 'venv'
$VenvPython   = Join-Path $Venv 'Scripts\python.exe'
$VenvPackages = Join-Path $Venv 'Lib\site-packages'
$LauncherExe  = Join-Path $Dest 'StyleBertVITS2.exe'

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Note([string]$Message) {
    Write-Host "    $Message" -ForegroundColor DarkGray
}

function Fail([string]$Message) {
    Write-Host ''
    Write-Host "[LOI] $Message" -ForegroundColor Red
    exit 1
}

function Get-FolderSizeMB([string]$Path) {
    if (-not (Test-Path $Path)) { return 0 }
    $sum = (Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Sum Length).Sum
    if ($null -eq $sum) { return 0 }
    return [math]::Round($sum / 1MB, 0)
}

function Copy-Tree {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Target,
        [string[]]$ExcludeDirs = @(),
        [string[]]$ExcludeFiles = @(),
        [switch]$NonFatal
    )
    if (-not (Test-Path $Source)) {
        throw "Missing source folder: $Source"
    }
    $null = New-Item -ItemType Directory -Force -Path $Target

    $roboArgs = @($Source, $Target, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1', '/MT:16')

    # robocopy needs absolute paths for exclusions that are not plain folder names
    $dirs = @($ExcludeDirs | Where-Object { $_ } | ForEach-Object {
        if ([System.IO.Path]::IsPathRooted($_)) { $_ } else { Join-Path $Source $_ }
    })
    if ($dirs.Count -gt 0)         { $roboArgs += '/XD'; $roboArgs += $dirs }
    if ($ExcludeFiles.Count -gt 0) { $roboArgs += '/XF'; $roboArgs += $ExcludeFiles }

    & robocopy @roboArgs | Out-Null
    if ($LASTEXITCODE -ge 8) {
        if ($NonFatal) {
            Write-Host "    [canh bao] mot vai file dang bi khoa, dung ban da co san" -ForegroundColor Yellow
        } else {
            throw "robocopy failed ($LASTEXITCODE) copying $Source -> $Target"
        }
    }
}

function Copy-File {
    param([string]$Source, [string]$Target)
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target)
    Copy-Item -LiteralPath $Source -Destination $Target -Force
}

# --------------------------------------------------------------------- pre-flight
Write-Step "Kiem tra moi truong"

if (-not (Test-Path $VenvPython)) {
    Fail "Khong tim thay $VenvPython`n      Hay tao venv va cai dat thu vien truoc (xem README.md)."
}
if (-not (Test-Path $VenvPackages)) {
    Fail "Khong tim thay $VenvPackages"
}

# The base interpreter is whatever the venv was created from; read it from pyvenv.cfg
# so this script keeps working after a Python upgrade.
$pyvenvCfg = Join-Path $Venv 'pyvenv.cfg'
if (-not (Test-Path $pyvenvCfg)) {
    Fail "Khong tim thay $pyvenvCfg"
}
$homeLine = Get-Content -LiteralPath $pyvenvCfg -Encoding UTF8 |
            Where-Object { $_ -match '^\s*home\s*=' } |
            Select-Object -First 1
if (-not $homeLine) {
    Fail "Khong doc duoc duong dan Python goc trong $pyvenvCfg"
}
$BasePython = ($homeLine -replace '^\s*home\s*=\s*', '').Trim()
if (-not (Test-Path $BasePython)) {
    Fail "Python goc khong ton tai: $BasePython`n      Hay tao lai venv tren may nay."
}

$Csc = @(
    'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe',
    'C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe'
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Csc) {
    Fail "Khong tim thay csc.exe (Windows .NET Framework). Khong bien dich duoc file exe."
}

$launcherSource = Join-Path $PSScriptRoot 'launcher.cs'
if (-not (Test-Path $launcherSource)) {
    Fail "Khong tim thay $launcherSource"
}

Write-Note "Du an      : $ProjectRoot"
Write-Note "Python goc : $BasePython"
Write-Note "Thu muc ra : $Dest"
Write-Note "csc        : $Csc"

# A running instance locks files inside dist and makes the copy fail half way.
$running = Get-Process -Name 'StyleBertVITS2' -ErrorAction SilentlyContinue
if ($running) {
    Fail "StyleBertVITS2.exe dang chay. Hay tat cua so do roi build lai."
}

$drive = (Split-Path -Qualifier $Dest)
$freeGB = [math]::Round((Get-PSDrive -Name $drive.TrimEnd(':')).Free / 1GB, 1)
Write-Note "O dia $drive con : $freeGB GB"
if ($freeGB -lt 20) {
    Write-Host "    [canh bao] Nen co it nhat 20 GB trong de build." -ForegroundColor Yellow
}

if (-not $SkipDependencyCheck) {
    Write-Step "Kiem tra thu vien trong venv"
    $check = @'
import sys
import torch, gradio, transformers, pyopenjtalk
import style_bert_vits2
print("python", sys.version.split()[0])
print("torch ", torch.__version__, "cuda", torch.cuda.is_available())
print("gradio", gradio.__version__)
'@
    $checkPath = Join-Path ([System.IO.Path]::GetTempPath()) 'sbv2_build_check.py'
    Set-Content -LiteralPath $checkPath -Value $check -Encoding UTF8
    Push-Location $ProjectRoot
    # The check script lives in %TEMP%, so the project root is not on sys.path by
    # default; without PYTHONPATH "import style_bert_vits2" fails even though the
    # project itself imports fine when run from its own folder.
    $previousPythonPath = $env:PYTHONPATH
    $env:PYTHONPATH = $ProjectRoot
    try {
        & $VenvPython $checkPath
        if ($LASTEXITCODE -ne 0) {
            Fail "venv thieu thu vien. Chay: venv\Scripts\python.exe -m pip install -r requirements.txt"
        }
    } finally {
        $env:PYTHONPATH = $previousPythonPath
        Pop-Location
        Remove-Item -LiteralPath $checkPath -Force -ErrorAction SilentlyContinue
    }
}

if ($Clean -and (Test-Path $Dest)) {
    Write-Step "Xoa ban build cu"
    Remove-Item -LiteralPath $Dest -Recurse -Force
}

$null = New-Item -ItemType Directory -Force -Path $Dest

# ---------------------------------------------------------------- Python runtime
Write-Step "Chep Python runtime"
Copy-Tree -Source $BasePython -Target (Join-Path $Dest 'runtime\python') `
    -ExcludeDirs  @('Lib\site-packages', 'Doc', 'include', '__pycache__') `
    -ExcludeFiles @('*.pdb')
Write-Note ("Python: {0:N0} MB" -f (Get-FolderSizeMB (Join-Path $Dest 'runtime\python')))

Write-Step "Chep thu vien (site-packages)"
# "~orch" / "~umpy" style folders are leftovers of interrupted pip upgrades.
Copy-Tree -Source $VenvPackages -Target (Join-Path $Dest 'runtime\python\Lib\site-packages') `
    -ExcludeDirs  @('~orch', '~umpy', '__pycache__') `
    -ExcludeFiles @('*.pyc')
Write-Note ("site-packages: {0:N0} MB" -f (Get-FolderSizeMB (Join-Path $Dest 'runtime\python\Lib\site-packages')))

# ------------------------------------------------------------------ application
Write-Step "Chep ma nguon va tai nguyen"
# Everything that is not clearly a build/training by-product gets copied, so folders
# added by future versions of the project are picked up automatically.
$rootExcludeDirs = @(
    'venv', 'dist', 'packaging',
    'Data', 'outputs', 'inputs', 'logs',
    'pretrained', 'pretrained_jp_extra',
    'docs', 'tests', '.git', '.github', '.vscode', '.idea',
    'node_modules', '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache'
)
$bertExcludeDirs = @()
if (-not $IncludeAllBert) {
    # Every voice in this package is Japanese, so only the Japanese BERT is needed.
    $bertExcludeDirs = @(
        'bert\chinese-roberta-wwm-ext-large',
        'bert\chinese-roberta-wwm-ext-large-onnx',
        'bert\deberta-v3-large',
        'bert\deberta-v3-large-onnx',
        'bert\deberta-v2-large-japanese-char-wwm-onnx'
    )
}

Copy-Tree -Source $ProjectRoot -Target $Dest `
    -ExcludeDirs  ($rootExcludeDirs + $bertExcludeDirs) `
    -ExcludeFiles @('*.bat', '*.pyc', '*.log')

# data_utils / training tools read configs\paths.yml, which points at Data\
$null = New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'Data')

Write-Step "Chep tu dien nguoi dung (co the dang bi khoa boi WebUI)"
Copy-Tree -Source (Join-Path $ProjectRoot 'dict_data') -Target (Join-Path $Dest 'dict_data') -NonFatal

# The Miku theme is otherwise downloaded from the Hugging Face Hub on first use.
# Ship it locally so the packaged UI looks identical without network access.
$themeInProject = Join-Path $ProjectRoot 'static\gradio_theme.json'
if (-not (Test-Path $themeInProject)) {
    $cached = Get-ChildItem -Path (Join-Path $env:USERPROFILE '.cache\huggingface\hub') `
        -Recurse -File -Filter 'theme_schema@*.json' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cached) {
        Copy-Item -LiteralPath $cached.FullName -Destination $themeInProject -Force
        Copy-File $themeInProject (Join-Path $Dest 'static\gradio_theme.json')
        Write-Note "Da nhung theme tu cache: $($cached.FullName)"
    } else {
        Write-Host "    [canh bao] Khong tim thay theme Miku, giao dien se dung theme mac dinh." -ForegroundColor Yellow
    }
}

foreach ($required in @('app.py', 'style_bert_vits2\constants.py', 'gradio_tabs\inference.py',
                        'configs\paths.yml', 'model_assets', 'slm\wavlm-base-plus')) {
    if (-not (Test-Path (Join-Path $Dest $required))) {
        Fail "Thieu $required trong ban build."
    }
}

# ---------------------------------------------------------------------- launcher
Write-Step "Bien dich StyleBertVITS2.exe"
& $Csc /nologo /codepage:65001 /target:exe /platform:anycpu /optimize+ `
    "/out:$LauncherExe" $launcherSource
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $LauncherExe)) {
    Fail "csc.exe khong bien dich duoc launcher."
}
Write-Note ("StyleBertVITS2.exe: {0:N0} KB" -f ((Get-Item $LauncherExe).Length / 1KB))

# -------------------------------------------------------------------------- docs
Write-Step "Ghi README.txt"
$readme = @'
Style-Bert-VITS2 - Ban dong goi san sang chay
=============================================

CACH DUNG
---------
1. Chep nguyen ca thu muc nay sang may khac (USB, o cung ngoai...).
   Khong chep le file .exe, phai chep ca thu muc "runtime".
2. Bam dup vao StyleBertVITS2.exe.
3. Trinh duyet tu mo o dia chi http://127.0.0.1:7860
4. De tat: dong cua so den, hoac nhan Ctrl+C trong do.

MAY DICH CAN GI
---------------
- Windows 10/11 64-bit
- Khoang 20 GB dung luong trong
- RAM toi thieu 8 GB (khuyen nghi 16 GB)
- KHONG can cai Python
- Neu co card do hoa NVIDIA: tu dung GPU, nhanh hon nhieu.
  Neu khong co, chuong trinh tu chay bang CPU (cham hon kha nhieu
  nhung van tao duoc audio).

CO GI TRONG DAY
---------------
- model_assets\  : cac giong da train (ren, jvnv, amitaro, koharune-ami...)
- bert\          : mo hinh BERT tieng Nhat bat buoc cho inference
- slm\           : WavLM bat buoc cho model kieu JP-Extra (vi du "ren")
- runtime\       : Python + toan bo thu vien, khong can cai dat
- dict_data\     : tu dien doc tieng Nhat cua ban

CAC TAB SU DUNG DUOC
--------------------
- Tao audio tu text, Style Vectors, Merge, ONNX Convert
- Dataset / Train: chi co giao dien, khong kem du lieu train.

NEU GAP LOI
-----------
- Cua so den hien loi: doc dong cuoi cung trong cua so do.
- "Address already in use": da co mot cua so Style-Bert-VITS2 khac dang chay,
  hay tat cua so cu truoc.
- Khong di chuyen rieng file .exe ra khoi thu muc nay.

GIAY PHEP
---------
Du an goc: Style-Bert-VITS2 (litagin02). Xem LICENSE va LGPL_LICENSE.
pyopenjtalk su dung OpenJTalk theo giay phep LGPL.
'@
Set-Content -LiteralPath (Join-Path $Dest 'README.txt') -Value $readme -Encoding UTF8

# ------------------------------------------------------------------------ report
Write-Step "Hoan tat"
$totalMB = Get-FolderSizeMB $Dest
$fileCount = (Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Host ("    Ket qua : {0}" -f $Dest)
Write-Host ("    Kich thuoc: {0:N1} GB ({1:N0} file)" -f ($totalMB / 1024), $fileCount)
Write-Host ("    Chay thu  : {0}" -f $LauncherExe)
Write-Host ''
