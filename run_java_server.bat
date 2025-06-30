@echo off
echo ========================================
echo HTTP服务器 - Java版本
echo 纯AI生成，用于学习HTTP协议底层原理
echo ========================================
echo.

echo 正在编译Java代码...
javac HttpServerJava.java

if %errorlevel% neq 0 (
    echo 编译失败！请检查Java环境是否正确安装。
    pause
    exit /b 1
)

echo 编译成功！
echo.
echo 启动HTTP服务器...
echo 访问地址: http://localhost:8080
echo 按 Ctrl+C 停止服务器
echo.

java HttpServerJava

echo.
echo 服务器已停止
pause