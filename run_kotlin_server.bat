@echo off
chcp 65001 >nul
echo ========================================
echo    Kotlin HTTP服务器启动脚本
echo ========================================
echo.

echo 检查Java环境...
java -version >nul 2>&1
if errorlevel 1 (
    echo Java未安装或不在PATH中！
    echo 请安装Java 8或更高版本
    echo.
    pause
    exit /b 1
)

echo 检查Kotlin编译器...
kotlinc -version >nul 2>&1
if errorlevel 1 (
    echo Kotlin编译器未安装或不在PATH中！
    echo 请安装Kotlin编译器
    echo.
    pause
    exit /b 1
)

echo 正在编译Kotlin服务器...
kotlinc HttpServerKotlin.kt -include-runtime -d HttpServerKotlin.jar
if errorlevel 1 (
    echo.
    echo 编译失败！请检查代码是否有语法错误
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

java -jar HttpServerKotlin.jar

echo.
echo 服务器已停止
pause