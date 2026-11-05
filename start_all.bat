@echo off
chcp 65001 > nul
echo ========================================
echo    Style-Bert-VITS2 Launcher
echo ========================================
echo.
echo Chọn chế độ khởi động:
echo.
echo 1. Editor UI (Tổng hợp giọng nói)
echo 2. Main WebUI (Tất cả tính năng)
echo 3. API Server (FastAPI)
echo 4. Training UI
echo 5. Style Vectors UI
echo 6. Dataset Creator
echo 7. Model Merge
echo.
set /p choice="Nhập số (1-7): "

if "%choice%"=="1" (
    echo.
    echo Đang khởi động Editor UI...
    call venv\Scripts\activate.bat
    python server_editor.py --inbrowser
) else if "%choice%"=="2" (
    echo.
    echo Đang khởi động Main WebUI...
    call venv\Scripts\activate.bat
    python app.py
) else if "%choice%"=="3" (
    echo.
    echo Đang khởi động API Server...
    call venv\Scripts\activate.bat
    python server_fastapi.py
) else if "%choice%"=="4" (
    echo.
    echo Đang khởi động Training UI...
    call venv\Scripts\activate.bat
    start cmd /k "call venv\Scripts\activate.bat && python app.py"
) else if "%choice%"=="5" (
    echo.
    echo Đang khởi động Style Vectors UI...
    call venv\Scripts\activate.bat
    start cmd /k "call venv\Scripts\activate.bat && python -c \"from app import *; create_style_vectors_app()\""
) else if "%choice%"=="6" (
    echo.
    echo Đang khởi động Dataset Creator...
    call venv\Scripts\activate.bat
    start cmd /k "call venv\Scripts\activate.bat && python -c \"from app import *; create_dataset_app()\""
) else if "%choice%"=="7" (
    echo.
    echo Đang khởi động Model Merge...
    call venv\Scripts\activate.bat
    start cmd /k "call venv\Scripts\activate.bat && python -c \"from app import *; create_merge_app()\""
) else (
    echo.
    echo Lựa chọn không hợp lệ!
    pause
    exit /b
)

pause
