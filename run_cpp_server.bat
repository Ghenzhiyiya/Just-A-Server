@echo off
echo ========================================
echo HTTP服务器 - C++版本
echo 纯AI生成，用于学习HTTP协议底层原理
echo ========================================
echo.

echo 正在编译C++代码...
echo 需要支持C++17的编译器（如MinGW-w64或Visual Studio）
echo.

REM 尝试使用g++编译
g++ -std=c++17 -O2 HttpServerCpp.cpp -lws2_32 -o HttpServerCpp.exe

if %errorlevel% neq 0 (
    echo.
    echo g++编译失败，尝试使用cl（Visual Studio编译器）...
    cl /EHsc /std:c++17 HttpServerCpp.cpp ws2_32.lib
    
    if %errorlevel% neq 0 (
        echo.
        echo 编译失败！请确保：
        echo 1. 已安装MinGW-w64或Visual Studio
        echo 2. 编译器在PATH环境变量中
        echo 3. 支持C++17标准
        pause
        exit /b 1
    )
    
    ren HttpServerCpp.exe HttpServerCpp_vs.exe
    set EXECUTABLE=HttpServerCpp_vs.exe
) else (
    set EXECUTABLE=HttpServerCpp.exe
)

echo 编译成功！
echo.
echo 启动HTTP服务器...
echo 访问地址: http://localhost:8080
echo 按 Ctrl+C 停止服务器
echo.

%EXECUTABLE%

echo.
echo 服务器已停止
pause