@echo off
chcp 65001 >nul
color 0A
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║                    HTTP服务器选择器                          ║
echo ║                  纯AI生成，学习HTTP协议原理                   ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
echo 请选择要运行的HTTP服务器版本：
echo.
echo [1] Java版本   - 面向对象，线程池，跨平台
echo [2] C++版本    - 高性能，底层控制，跨平台Socket
echo [3] C#版本     - .NET框架，企业级开发
echo [4] Kotlin版本 - 现代JVM语言，简洁语法
echo [5] Rust版本   - 内存安全，现代语言，并发处理
echo [6] Python版本 - 简单易用，快速开发
echo [7] Go版本     - 高并发，云原生
echo [8] Node.js版本 - JavaScript运行时，事件驱动
echo [9] PHP版本    - Web开发经典语言
echo [10] Ruby版本  - 优雅语法，快速开发
echo [11] 查看项目说明
echo [0] 退出
echo.
set /p choice=请输入选择 (0-11): 

if "%choice%"=="1" (
    echo.
    echo 启动Java版本HTTP服务器...
    call run_java_server.bat
) else if "%choice%"=="2" (
    echo.
    echo 启动C++版本HTTP服务器...
    call run_cpp_server.bat
) else if "%choice%"=="3" (
    echo.
    echo 启动C#版本HTTP服务器...
    call run_csharp_server.bat
) else if "%choice%"=="4" (
    echo.
    echo 启动Kotlin版本HTTP服务器...
    call run_kotlin_server.bat
) else if "%choice%"=="5" (
    echo.
    echo 启动Rust版本HTTP服务器...
    call run_rust_server.bat
) else if "%choice%"=="6" (
    echo.
    echo 启动Python版本HTTP服务器...
    call run_python_server.bat
) else if "%choice%"=="7" (
    echo.
    echo 启动Go版本HTTP服务器...
    call run_go_server.bat
) else if "%choice%"=="8" (
    echo.
    echo 启动Node.js版本HTTP服务器...
    call run_nodejs_server.bat
) else if "%choice%"=="9" (
    echo.
    echo 启动PHP版本HTTP服务器...
    call run_php_server.bat
) else if "%choice%"=="10" (
    echo.
    echo 启动Ruby版本HTTP服务器...
    call run_ruby_server.bat
) else if "%choice%"=="11" (
    echo.
    echo 正在打开README.md文档...
    start README.md
    echo.
    echo 文档已在默认程序中打开
    echo 按任意键返回主菜单...
    pause >nul
    goto :start
) else if "%choice%"=="0" (
    echo 再见！
    exit /b 0
) else (
    echo.
    echo 无效选择，请重新输入！
    echo.
    pause
    goto :start
)

echo.
echo 按任意键返回主菜单...
pause >nul
goto :start

:start
cls
goto :eof