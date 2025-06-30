@echo off
chcp 65001 >nul
echo ========================================
echo    Ruby HTTP服务器启动脚本
echo ========================================
echo.

echo 检查Ruby环境...
ruby --version >nul 2>&1
if errorlevel 1 (
    echo Ruby未安装或不在PATH中！
    echo 请安装Ruby 2.7或更高版本
    echo.
    pause
    exit /b 1
)

echo Ruby环境检查通过
echo 正在启动服务器...
echo.
echo 服务器将在以下地址启动：
echo   http://localhost:8080
echo   http://127.0.0.1:8080
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

ruby http_server_ruby.rb

echo.
echo 服务器已停止
pause