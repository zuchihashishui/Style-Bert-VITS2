# One-shot setup for Style-Bert-VITS2 on Windows + Python 3.12 + NVIDIA RTX 50 series.
#
# Usage (from the project root):
#   powershell -ExecutionPolicy Bypass -File .\scripts\Setup-Windows-Env.ps1
#
# What it does:
#   1. Creates .\venv (Python 3.12)
#   2. Installs torch/torchaudio with the cu128 build (needed for RTX 50xx / sm_120)
#   3. Builds pyopenjtalk from source (no py3.12 wheel exists)
#   4. Installs the remaining requirements, skipping the py3.12-incompatible ones
#   5. Runs initialize.py to fetch the BERT / SLM / default voice models
#
# Re-running is safe: every step is skipped when it is already done.

[CmdletBinding()]
param(
    [string]$Python = 'python',
    [switch]$SkipModels
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Venv        = Join-Path $ProjectRoot 'venv'
$VenvPython  = Join-Path $Venv 'Scripts\python.exe'

function Write-Step([string]$Message) {
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Write-Note([string]$Message) {
    Write-Host "    $Message" -ForegroundColor DarkGray
}

# --------------------------------------------------------------------- pre-flight
Write-Step 'Kiem tra moi truong'

if (-not (Get-Command $Python -ErrorAction SilentlyContinue)) {
    throw "Khong tim thay '$Python'. Hay cai Python 3.12 va them vao PATH."
}

$ver = & $Python -c "import sys; print('%d.%d' % sys.version_info[:2])"
if ($ver -ne '3.12') {
    Write-Host "    [canh bao] Python dang dung la $ver, du an can 3.12." -ForegroundColor Yellow
}

# The RTX 50 series (Blackwell, sm_120) is not supported by the torch<2.4 / cu118
# wheels the upstream install script pins, so a cu128 build is used instead.
#
# torch must stay at 2.7.1: from 2.8 onwards the official Windows wheels are built
# with GLOO_HAVE_TRANSPORT_TCP=false and GLOO_HAVE_TRANSPORT_UV=false, which makes
# the gloo backend completely unusable on Windows ("makeDeviceForHostname():
# unsupported gloo device", pytorch/pytorch#150381). torch 2.7.1+cu128 is the last
# cu128 build that still ships a working gloo TCP transport, and it does support
# sm_120. torch >= 2.10 is expected to ship the fix, but 2.7.1 is verified here.
$cu = & nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>$null
if ($cu -and [double]$cu -ge 12.0) {
    Write-Note "GPU compute capability $cu -> dung torch cu128"
    $TorchIndex = 'https://download.pytorch.org/whl/cu128'
    $TorchVer   = '2.7.1'
} else {
    Write-Note "Khong phat hien GPU RTX 50 series -> dung torch cu118"
    $TorchIndex = 'https://download.pytorch.org/whl/cu118'
    $TorchVer   = '2.3.1'
}

# ------------------------------------------------------------------- 1. the venv
if (-not (Test-Path $VenvPython)) {
    Write-Step 'Tao moi truong ao (venv)'
    & $Python -m venv $Venv
} else {
    Write-Step 'venv da ton tai, bo qua'
}
& $VenvPython -m pip install --upgrade pip wheel | Out-Null
# setuptools >= 81 removed pkg_resources, which pyopenjtalk and librosa 0.9.2 still need.
& $VenvPython -m pip install 'setuptools<81' | Out-Null

# --------------------------------------------------------------------- 2. torch
Write-Step 'Cai dat PyTorch'
& $VenvPython -m pip install "torch==$TorchVer" "torchaudio==$TorchVer" --index-url $TorchIndex
& $VenvPython -c "import torch; print('    torch', torch.__version__, '| cuda', torch.cuda.is_available())"

# ------------------------------------------------- 3. pyopenjtalk (built from source)
# PyPI only ships an sdist for pyopenjtalk, so a C/C++ toolchain is required.
# The import prints a pkg_resources deprecation warning on stderr, so stderr is
# discarded and only the exit code is trusted.
& $VenvPython -W ignore -c "import pyopenjtalk" 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Step 'pyopenjtalk da co, bo qua'
} else {
    Write-Step 'Bien dich pyopenjtalk tu source (can MSVC + CMake)'
    & $VenvPython -m pip install 'numpy<2' 'setuptools<81' 'cython>=0.29.16' cmake tqdm | Out-Null

    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) {
        throw 'Khong tim thay Visual Studio. Cai "Desktop development with C++" roi chay lai.'
    }
    $vsPath = (& $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath)
    $vcvars = Join-Path $vsPath 'VC\Auxiliary\Build\vcvars64.bat'
    $cmake  = Get-ChildItem (Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin') `
                  -Filter 'cmake.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not (Test-Path $vcvars)) { throw "Khong tim thay $vcvars" }

    $cmd = "call `"$vcvars`" && set PATH=$($cmake.Directory);$($Venv.Replace('\','\'))\Scripts;%PATH% && `"$VenvPython`" -m pip install pyopenjtalk==0.4.1 --no-build-isolation"
    cmd /c $cmd
    if ($LASTEXITCODE -ne 0) { throw 'Bien dich pyopenjtalk that bai.' }
}

# ------------------------------------------------------- 4. the other requirements
Write-Step 'Cai dat cac thu vien con lai'
# pyannote.audio is installed with pinned versions instead of being resolved
# normally: every unpinned 3.x release drags in pytorch-metric-learning (which
# needs torch>=2.14) and numpy>=2, contradicting the numpy<2 pin this project
# relies on. style_gen.py needs it to compute the style vectors, so it cannot
# simply be skipped. The pins below are the newest versions that still work
# with numpy<2 and torch 2.7.1.
$reqFile = Join-Path $env:TEMP 'sbv2_requirements_py312.txt'
Get-Content (Join-Path $ProjectRoot 'requirements.txt') |
    Where-Object { $_ -notmatch '^\s*#' -and
                   $_ -notmatch '^\s*$' -and
                   $_ -notmatch 'pyannote' -and
                   $_ -notmatch '^torch' -and
                   $_ -notmatch '^torchaudio' } |
    Set-Content $reqFile -Encoding UTF8

& $VenvPython -m pip install -r $reqFile -c (Join-Path $ProjectRoot 'constraints.txt')

Write-Step 'Cai dat pyannote.audio (tao style vector)'
& $VenvPython -m pip install `
    'pyannote.audio==3.1.0' `
    'pyannote.core==5.0.0' `
    'pyannote.database==5.1.3' `
    'pyannote.metrics==3.2' `
    'pyannote.pipeline==3.0.1' `
    'pytorch-metric-learning==2.8.1' `
    'torch-audiomentations==0.11.0' `
    'torchmetrics==1.7.3' `
    'lightning==2.5.2' `
    'asteroid-filterbanks==0.4.0' `
    'speechbrain==1.0.2' `
    'tensorboardX==2.6.2' `
    'einops==0.8.0'
# Some of those packages pull setuptools >= 81, which drops pkg_resources and
# breaks the pyopenjtalk / librosa 0.9.2 imports, so the cap is re-applied.
& $VenvPython -m pip install 'setuptools<81' | Out-Null

# ------------------------------------------------- 4b. transcription dependencies
# faster-whisper needs `av`, and av >= 17 removed the `metadata_errors` keyword
# that faster-whisper 1.2.1 still passes to av.open(), so av is capped at 16.1.0.
Write-Step 'Cai dat faster-whisper (chep loi thoai)'
& $VenvPython -m pip install 'faster-whisper==1.2.1' 'av==16.1.0'

# -------------------------------------------------------------------- 5. models
if ($SkipModels) {
    Write-Step 'Bo qua viec tai model (--SkipModels)'
} else {
    Write-Step 'Tai model (BERT / WavLM / giong mac dinh)'
    Push-Location $ProjectRoot
    try {
        & $VenvPython (Join-Path $ProjectRoot 'initialize.py')
    } finally {
        Pop-Location
    }
}

# ------------------------------------------------------------------ 6. verify
# The training script always calls dist.init_process_group(backend="gloo"), so a
# broken gloo build only shows up once the training is started. Check it here
# instead of after the user has already waited for the dataset preprocessing.
Write-Step 'Kiem tra moi truong (gloo / cuda / pyannote)'
$verify = @'
import os, datetime, torch, torch.distributed as dist
os.environ.setdefault("MASTER_ADDR", "localhost")
os.environ.setdefault("MASTER_PORT", "10086")
os.environ.setdefault("WORLD_SIZE", "1")
os.environ.setdefault("RANK", "0")
os.environ.setdefault("LOCAL_RANK", "0")
print("    torch", torch.__version__, "| numpy", __import__("numpy").__version__)
print("    cuda :", torch.cuda.is_available(),
      torch.cuda.get_device_name(0) if torch.cuda.is_available() else "")
dist.init_process_group(backend="gloo", init_method="env://",
                        timeout=datetime.timedelta(seconds=30))
print("    gloo : OK")
dist.destroy_process_group()
import pyannote.audio
print("    pyannote.audio", pyannote.audio.__version__, ": OK")
'@
$verify | & $VenvPython -
if ($LASTEXITCODE -ne 0) {
    throw 'Kiem tra moi truong that bai (xem loi ben tren).'
}

Write-Step 'Hoan tat'
Write-Host "    WebUI      : venv\Scripts\python app.py" -ForegroundColor Green
Write-Host "    Editor     : venv\Scripts\python server_editor.py --inbrowser" -ForegroundColor Green
Write-Host "    API server : venv\Scripts\python server_fastapi.py" -ForegroundColor Green
Write-Host "    Train      : venv\Scripts\python train_ms_jp_extra.py --config Data\<model>\config.json --model Data\<model>" -ForegroundColor Green
Write-Host ''
