@echo off
chcp 65001 > nul
cd /d "%~dp0"

echo.
echo ========================================
echo   Style-Bert-VITS2 - Full WebUI
echo ========================================
echo.
echo Đang khởi động Full WebUI (All Features)...
echo URL: http://localhost:7860
echo.
echo Bao gồm:
echo  - TTS Inference
echo  - Dataset Management
echo  - Training
echo  - Style Vectors
echo  - Model Merging
echo.
echo Nhấn Ctrl+C để dừng server
echo ========================================
echo.

call venv\Scripts\activate.bat
python app.py

pause
