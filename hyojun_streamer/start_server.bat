@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo ============================================================
echo  SmartAI 로컬 스트리머 서버
echo  - 영상 : http://192.168.0.116:8080/stream
echo  - 이벤트: ws://192.168.0.116:8765
echo  (같은 와이파이에서 앱이 이 주소로 접속합니다)
echo ============================================================
echo.

REM --- 최초 1회만 의존성 설치 (이미 깔려 있으면 자동으로 건너뜀) ---
REM --- Supabase write key (needed for dashboard charts/cards) ---
if exist "%~dp0..\SUPAKEY.txt" (
    set /p SUPABASE_KEY=<"%~dp0..\SUPAKEY.txt"
) else if exist "%~dp0SUPAKEY.txt" (
    set /p SUPABASE_KEY=<"%~dp0SUPAKEY.txt"
)

python -m pip install -r requirements.txt
echo.

REM --- 서버 실행 ---
REM 신호등(ESP32)이 같은 망에 있고 IP를 detect_stream.py 47번 줄에 맞춰 넣었다면
REM 아래 줄에서 --no-signal 을 지우세요.
python detect_stream.py --no-signal

echo.
echo [서버가 종료되었습니다] 창을 닫으려면 아무 키나 누르세요.
pause >nul
