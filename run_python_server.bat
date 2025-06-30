@echo off
chcp 65001 >nul
echo ========================================
echo    Python HTTP服务器启动脚本
echo ========================================
echo.

echo 检查Python环境...
python --version >nul 2>&1
if errorlevel 1 (
    echo Python未安装或不在PATH中！
    echo 请安装Python 3.6或更高版本
    echo.
    pause
    exit /b 1
)

echo Python环境检查通过
echo 正在启动服务器...
echo.
echo 服务器将在以下地址启动：
echo   http://localhost:8080
echo   http://127.0.0.1:8080
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

python http_server_python.py

echo.
echo 服务器已停止
pause