@echo off
chcp 65001 >nul
echo ========================================
echo    Node.js HTTP服务器启动脚本
echo ========================================
echo.

echo 检查Node.js环境...
node --version >nul 2>&1
if errorlevel 1 (
    echo Node.js未安装或不在PATH中！
    echo 请安装Node.js 14或更高版本
    echo.
    pause
    exit /b 1
)

echo Node.js环境检查通过
echo 正在启动服务器...
echo.
echo 服务器将在以下地址启动：
echo   http://localhost:8080
echo   http://127.0.0.1:8080
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

node http_server_nodejs.js

echo.
echo 服务器已停止
pause