@echo off
chcp 65001 >nul
echo ========================================
echo    PHP HTTP服务器启动脚本
echo ========================================
echo.

echo 检查PHP环境...
php --version >nul 2>&1
if errorlevel 1 (
    echo PHP未安装或不在PATH中！
    echo 请安装PHP 7.4或更高版本
    echo.
    pause
    exit /b 1
)

echo 检查PHP sockets扩展...
php -m | findstr /i "sockets" >nul 2>&1
if errorlevel 1 (
    echo PHP sockets扩展未启用！
    echo 请在php.ini中启用sockets扩展
    echo 取消注释: extension=sockets
    echo.
    pause
    exit /b 1
)

echo PHP环境检查通过
echo 正在启动服务器...
echo.
echo 服务器将在以下地址启动：
echo   http://localhost:8080
echo   http://127.0.0.1:8080
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

php http_server_php.php

echo.
echo 服务器已停止
pause