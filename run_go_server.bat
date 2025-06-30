@echo off
chcp 65001 >nul
echo ========================================
echo    Go HTTP服务器启动脚本
echo ========================================
echo.

echo 检查Go环境...
go version >nul 2>&1
if errorlevel 1 (
    echo Go未安装或不在PATH中！
    echo 请安装Go 1.16或更高版本
    echo.
    pause
    exit /b 1
)

echo Go环境检查通过
echo 正在启动服务器...
echo.
echo 服务器将在以下地址启动：
echo   http://localhost:8080
echo   http://127.0.0.1:8080
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

go run http_server_go.go

echo.
echo 服务器已停止
pause