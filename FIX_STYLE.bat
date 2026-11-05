@echo off
setlocal EnableExtensions
chcp 65001 > nul
title Sinh bu config.json + style_vectors.npy cho model
cd /d "%~dp0"

rem ---------------------------------------------------------------
rem  Dung khi train bang --skip_default_style (vd: resume) nen
rem  model_assets\{ten_model} thieu config.json -> WebUI bo qua model.
rem
rem  Cach dung:
rem    FIX_STYLE.bat            -> hoi ten model
rem    FIX_STYLE.bat Nao        -> lam luon cho model Nao
rem ---------------------------------------------------------------

set "MODEL=%~1"
if "%MODEL%"=="" set /p MODEL=Nhap ten model (vi du Nao): 
if "%MODEL%"=="" (
    echo [LOI] Chua nhap ten model.
    pause
    exit /b 1
)

if not exist "venv\Scripts\python.exe" (
    echo [LOI] Khong tim thay venv\Scripts\python.exe
    pause
    exit /b 1
)
if not exist "Data\%MODEL%\config.json" (
    echo [LOI] Khong tim thay Data\%MODEL%\config.json
    echo       Hay chay buoc "Initialize" cho model nay truoc.
    pause
    exit /b 1
)
if not exist "Data\%MODEL%\wavs" (
    echo [LOI] Khong tim thay Data\%MODEL%\wavs
    echo       Hay chay buoc "Step 5: style_gen" truoc.
    pause
    exit /b 1
)

echo.
echo === Dang sinh config.json + style_vectors.npy cho "%MODEL%" ===
venv\Scripts\python.exe -c "import sys; sys.path.insert(0, '.'); from default_style import save_styles_by_dirs; save_styles_by_dirs(r'Data/%MODEL%/wavs', r'model_assets/%MODEL%', r'Data/%MODEL%/config.json', r'model_assets/%MODEL%/config.json')"
if errorlevel 1 (
    echo.
    echo [LOI] Sinh that bai - xem thong bao phia tren.
    pause
    exit /b 1
)

echo.
echo === Xong. Kiem tra: ===
if exist "model_assets\%MODEL%\config.json"       echo   [OK] model_assets\%MODEL%\config.json
if exist "model_assets\%MODEL%\style_vectors.npy" echo   [OK] model_assets\%MODEL%\style_vectors.npy
echo.
echo Khoi dong lai WebUI de no quet lai danh sach model.
pause
exit /b 0
