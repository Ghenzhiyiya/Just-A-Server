@echo off
echo ========================================
echo HTTP服务器 - Rust版本
echo 纯AI生成，用于学习HTTP协议底层原理
echo ========================================
echo.

echo 检查Rust环境...
rustc --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Rust未安装或不在PATH中！
    echo 请访问 https://rustup.rs/ 安装Rust
    pause
    exit /b 1
)

echo Rust环境检查通过
echo.
echo 正在编译和运行Rust代码...
echo 首次运行可能需要下载依赖包，请耐心等待...
echo.
echo 访问地址: http://localhost:8080
echo 按 Ctrl+C 停止服务器
echo.

cargo run

echo.
echo 服务器已停止
pause