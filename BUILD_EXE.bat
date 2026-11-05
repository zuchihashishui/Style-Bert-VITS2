@echo off
setlocal EnableExtensions
chcp 65001 > nul
title Build Style-Bert-VITS2 EXE
cd /d "%~dp0"

echo.
echo ==========================================================
echo   TAO BAN DONG GOI STYLE-BERT-VITS2 (Windows 64-bit)
echo ==========================================================
echo.
echo   Khong can cai Python tren may dich.
echo   Ket qua: dist\StyleBertVITS2-Portable\StyleBertVITS2.exe
echo.

rem ---- tham so ----
rem   BUILD_EXE.bat            build binh thuong (giu file cu, nhanh)
rem   BUILD_EXE.bat clean      xoa sach roi build lai tu dau
rem   BUILD_EXE.bat fullbert   kem ca BERT tieng Trung / Anh
set "ARGS="
if /i "%~1"=="clean"    set "ARGS=-Clean"
if /i "%~1"=="fullbert" set "ARGS=-IncludeAllBert"
if /i "%~1"=="all"      set "ARGS=-Clean -IncludeAllBert"

where powershell > nul 2>&1
if errorlevel 1 (
    echo [LOI] Khong tim thay PowerShell. Windows 10/11 bat buoc phai co.
    goto end_fail
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0packaging\build_portable.ps1" %ARGS%
if errorlevel 1 goto end_fail

echo.
echo ==========================================================
echo   XONG. Bam dup vao file duoi day de chay thu:
echo   dist\StyleBertVITS2-Portable\StyleBertVITS2.exe
echo ==========================================================
if exist "dist\StyleBertVITS2-Portable" start "" explorer "dist\StyleBertVITS2-Portable"
echo.
pause
exit /b 0

:end_fail
echo.
echo ==========================================================
echo   BUILD THAT BAI - xem thong bao loi phia tren.
echo ==========================================================
echo.
pause
exit /b 1
