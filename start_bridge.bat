@echo off
setlocal
cd /d "%~dp0"
if "%OPENAI_API_KEY%"=="" (
  echo.
  echo OPENAI_API_KEY is not set.
  echo For this window only, run:
  echo   set OPENAI_API_KEY=your_key_here
  echo then run start_bridge.bat again.
  echo.
  pause
  exit /b 1
)
python bridge.py
pause
