@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo.
echo ========================================
echo   Style-Bert-VITS2 - Quick Start
echo ========================================
echo.
echo Đang khởi động Editor UI (TTS Inference)...
echo URL: http://localhost:7860
echo.
echo Nhấn Ctrl+C để dừng server
echo ========================================
echo.

call venv\Scripts\activate.bat
python server_editor.py --inbrowser

pause
