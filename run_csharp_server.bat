@echo off
chcp 65001 >nul
echo ========================================
echo    C# HTTP服务器启动脚本
echo ========================================
echo.

echo 正在编译C#服务器...
csc HttpServerCSharp.cs
if errorlevel 1 (
    echo.
    echo 编译失败！请检查：
    echo 1. 是否安装了.NET Framework SDK
    echo 2. csc命令是否在PATH中
    echo 3. 代码是否有语法错误
    echo.
    pause
    exit /b 1
)

echo 编译成功！正在启动服务器...
echo.
echo 服务器将在以下地址启动：
echo   http://localhost:8080
echo   http://127.0.0.1:8080
echo.
echo 按 Ctrl+C 停止服务器
echo ========================================
echo.

HttpServerCSharp.exe

echo.
echo 服务器已停止
pause