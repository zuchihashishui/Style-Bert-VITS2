@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 > nul
title Tao / cap nhat StyleBertVITS2.exe

cd /d "%~dp0"

rem ============================================================
rem  TAO_EXE.bat - tao lai ban dong goi portable + StyleBertVITS2.exe
rem
rem  Cach dung (bam dup vao file la chay, hoac mo cmd roi go):
rem    TAO_EXE.bat               cap nhat binh thuong, giu 1 checkpoint moi nhat
rem                              cua moi giong trong goi (goi nhe hon)
rem    TAO_EXE.bat all           giu TAT CA checkpoint trong goi
rem    TAO_EXE.bat clean         xoa sach dist roi build lai tu dau (co hoi xac nhan)
rem    TAO_EXE.bat fullbert      kem ca BERT tieng Trung / Anh
rem    TAO_EXE.bat all clean     co the ghep nhieu tham so voi nhau
rem
rem  Sau khi xong: dist\StyleBertVITS2-Portable\StyleBertVITS2.exe
rem ============================================================

echo.
echo ==========================================================
echo   TAO BAN DONG GOI STYLE-BERT-VITS2
echo ==========================================================
echo.

where powershell > nul 2>&1
if errorlevel 1 (
    echo [LOI] Khong tim thay PowerShell. Windows 10/11 bat buoc phai co.
    goto end_fail
)

if not exist "venv\Scripts\python.exe" (
    echo [LOI] Khong tim thay venv\Scripts\python.exe
    echo        Hay tao venv va cai thu vien truoc, xem README.md.
    goto end_fail
)

rem ---------------------------------------------------------- doc tham so
set "KEEP=1"
set "PSARGS="
set "DO_CLEAN=0"

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="all"      set "KEEP=0"
if /i "%~1"=="clean"    set "DO_CLEAN=1"
if /i "%~1"=="fullbert" set "PSARGS=!PSARGS! -IncludeAllBert"
shift
goto parse_args

:args_done
if "%DO_CLEAN%"=="1" goto ask_clean
goto run_build

:ask_clean
echo [CANH BAO] Ban chon "clean": toan bo thu muc dist se bi xoa va tao lai.
echo             Nhung giong chi co trong dist ma KHONG co trong model_assets
echo             cua du an se bi mat.
echo.
set "ANSWER="
set /p "ANSWER=Xac nhan xoa? (Y/N): "
if /i not "!ANSWER!"=="Y" (
    echo.
    echo Da huy. Khong co gi bi thay doi.
    goto end_ok
)
set "PSARGS=!PSARGS! -Clean"
echo.

rem ---------------------------------------------------------- build
:run_build
echo ==> Dang build, qua trinh nay mat vai phut. Dung tat cua so nay.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0packaging\build_portable.ps1" !PSARGS!
if errorlevel 1 goto end_fail

set "DIST=%~dp0dist\StyleBertVITS2-Portable"
if not exist "%DIST%\StyleBertVITS2.exe" (
    echo.
    echo [LOI] Build bao xong nhung khong thay StyleBertVITS2.exe trong dist.
    goto end_fail
)

rem ---------------------------------------------------------- don checkpoint
if "%KEEP%"=="0" (
    echo.
    echo ==> Giu tat ca checkpoint ^(tham so "all"^).
    goto report
)

echo.
echo ==> Don checkpoint: moi giong chi giu %KEEP% file .safetensors moi nhat
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='SilentlyContinue';" ^
 "Get-ChildItem '%DIST%\model_assets' -Directory | Where-Object { $_.Name -ne '.cache' } | ForEach-Object { $model = $_.Name; $files = @(Get-ChildItem $_.FullName -File -Filter *.safetensors | Sort-Object LastWriteTime -Descending); if ($files.Count -gt %KEEP%) { $files | Select-Object -Skip %KEEP% | ForEach-Object { Write-Host ('    bo: ' + $model + '\' + $_.Name); Remove-Item -LiteralPath $_.FullName -Force } } }"

rem ---------------------------------------------------------- bao cao
:report
echo.
echo ==========================================================
echo   XONG
echo ==========================================================
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
 "$d='%DIST%';" ^
 "$s=(Get-ChildItem $d -Recurse -File | Measure-Object -Sum Length).Sum;" ^
 "$c=(Get-ChildItem $d -Recurse -File | Measure-Object).Count;" ^
 "Write-Host ('    Thu muc   : ' + $d);" ^
 "Write-Host ('    Kich thuoc: {0:N2} GB ({1:N0} file)' -f ($s/1GB), $c);" ^
 "Write-Host ('    File chay : ' + (Join-Path $d 'StyleBertVITS2.exe'));" ^
 "$m=Get-ChildItem (Join-Path $d 'model_assets') -Directory | Where-Object { $_.Name -ne '.cache' } | ForEach-Object { $_.Name };" ^
 "Write-Host ('    Giong co  : ' + ($m -join ', '))"
echo.
echo   Chep NGUYEN thu muc tren sang may khac roi bam dup vao file .exe.
echo   Khong can cai Python tren may dich.
echo.
if exist "%DIST%" start "" explorer "%DIST%"
pause
endlocal
exit /b 0

:end_ok
echo.
pause
endlocal
exit /b 0

:end_fail
echo.
echo ==========================================================
echo   BUILD THAT BAI - xem thong bao loi phia tren.
echo ==========================================================
echo.
pause
endlocal
exit /b 1
