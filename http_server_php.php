#!/usr/bin/env php
<?php

/**
 * 从底层实现的HTTP服务器 - PHP版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

class HttpRequest {
    public $method = '';
    public $path = '';
    public $version = '';
    public $headers = [];
    public $body = '';
}

class HttpServer {
    private $port;
    private $documentRoot;
    private $socket;
    private $running = false;
    private $mimeTypes;
    
    public function __construct($port = 8080, $documentRoot = './Pub') {
        $this->port = $port;
        $this->documentRoot = realpath($documentRoot);
        
        // MIME类型映射
        $this->mimeTypes = [
            '.html' => 'text/html; charset=utf-8',
            '.htm' => 'text/html; charset=utf-8',
            '.css' => 'text/css',
            '.js' => 'application/javascript',
            '.json' => 'application/json',
            '.xml' => 'application/xml',
            '.png' => 'image/png',
            '.jpg' => 'image/jpeg',
            '.jpeg' => 'image/jpeg',
            '.gif' => 'image/gif',
            '.svg' => 'image/svg+xml',
            '.ico' => 'image/x-icon',
            '.pdf' => 'application/pdf',
            '.txt' => 'text/plain; charset=utf-8',
            '.zip' => 'application/zip',
            '.mp4' => 'video/mp4',
            '.mp3' => 'audio/mpeg',
            '.wav' => 'audio/wav'
        ];
    }
    
    /**
     * 启动HTTP服务器
     */
    public function start() {
        // 创建socket
        $this->socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
        if ($this->socket === false) {
            throw new Exception('无法创建socket: ' . socket_strerror(socket_last_error()));
        }
        
        // 设置socket选项
        socket_set_option($this->socket, SOL_SOCKET, SO_REUSEADDR, 1);
        
        // 绑定端口
        if (!socket_bind($this->socket, '0.0.0.0', $this->port)) {
            throw new Exception('无法绑定端口 ' . $this->port . ': ' . socket_strerror(socket_last_error($this->socket)));
        }
        
        // 开始监听
        if (!socket_listen($this->socket, 5)) {
            throw new Exception('无法监听端口: ' . socket_strerror(socket_last_error($this->socket)));
        }
        
        $this->running = true;
        echo "HTTP服务器启动在端口: {$this->port}\n";
        echo "文档根目录: {$this->documentRoot}\n";
        echo "按 Ctrl+C 停止服务器\n";
        
        // 设置信号处理
        if (function_exists('pcntl_signal')) {
            pcntl_signal(SIGINT, [$this, 'handleSignal']);
            pcntl_signal(SIGTERM, [$this, 'handleSignal']);
        }
        
        // 主循环
        while ($this->running) {
            // 处理信号
            if (function_exists('pcntl_signal_dispatch')) {
                pcntl_signal_dispatch();
            }
            
            // 接受连接
            $clientSocket = @socket_accept($this->socket);
            if ($clientSocket === false) {
                if ($this->running) {
                    echo "接受连接失败: " . socket_strerror(socket_last_error($this->socket)) . "\n";
                }
                continue;
            }
            
            // 处理客户端请求
            $this->handleClient($clientSocket);
        }
    }
    
    /**
     * 停止HTTP服务器
     */
    public function stop() {
        $this->running = false;
        if ($this->socket) {
            socket_close($this->socket);
        }
        echo "\n服务器已停止\n";
    }
    
    /**
     * 信号处理函数
     */
    public function handleSignal($signal) {
        switch ($signal) {
            case SIGINT:
            case SIGTERM:
                echo "\n收到停止信号，正在停止服务器...\n";
                $this->stop();
                exit(0);
                break;
        }
    }
    
    /**
     * 处理客户端连接
     */
    private function handleClient($clientSocket) {
        try {
            // 设置超时
            socket_set_option($clientSocket, SOL_SOCKET, SO_RCVTIMEO, ['sec' => 30, 'usec' => 0]);
            
            // 获取客户端地址
            socket_getpeername($clientSocket, $clientAddress);
            
            // 读取请求数据
            $requestData = '';
            while (true) {
                $chunk = socket_read($clientSocket, 8192);
                if ($chunk === false || $chunk === '') {
                    break;
                }
                
                $requestData .= $chunk;
                
                // 检查是否接收完整的HTTP头部
                if (strpos($requestData, "\r\n\r\n") !== false) {
                    break;
                }
            }
            
            if (empty($requestData)) {
                return;
            }
            
            // 解析请求
            $request = $this->parseRequest($requestData);
            if (!$request) {
                $this->sendErrorResponse($clientSocket, 400, 'Bad Request');
                return;
            }
            
            echo "收到请求: {$request->method} {$request->path} - {$clientAddress}\n";
            
            // 处理请求
            $this->handleRequest($request, $clientSocket);
            
        } catch (Exception $e) {
            echo "处理客户端时出错: {$e->getMessage()}\n";
        } finally {
            socket_close($clientSocket);
        }
    }
    
    /**
     * 解析HTTP请求
     */
    private function parseRequest($requestData) {
        try {
            $lines = explode("\r\n", $requestData);
            
            if (count($lines) === 0) {
                return null;
            }
            
            // 解析请求行
            $requestLine = $lines[0];
            $parts = explode(' ', $requestLine);
            
            if (count($parts) !== 3) {
                return null;
            }
            
            $request = new HttpRequest();
            $request->method = $parts[0];
            $request->path = urldecode($parts[1]); // URL解码
            $request->version = $parts[2];
            
            // 解析请求头
            for ($i = 1; $i < count($lines); $i++) {
                $line = trim($lines[$i]);
                
                if ($line === '') {
                    break; // 空行表示头部结束
                }
                
                $colonPos = strpos($line, ':');
                if ($colonPos > 0) {
                    $headerName = strtolower(trim(substr($line, 0, $colonPos)));
                    $headerValue = trim(substr($line, $colonPos + 1));
                    $request->headers[$headerName] = $headerValue;
                }
            }
            
            return $request;
            
        } catch (Exception $e) {
            echo "解析请求时出错: {$e->getMessage()}\n";
            return null;
        }
    }
    
    /**
     * 处理HTTP请求
     */
    private function handleRequest($request, $clientSocket) {
        try {
            // 只支持GET方法
            if ($request->method !== 'GET') {
                $this->sendErrorResponse($clientSocket, 405, 'Method Not Allowed');
                return;
            }
            
            // 处理路径
            $filePath = $request->path;
            
            // 移除查询参数
            $queryPos = strpos($filePath, '?');
            if ($queryPos !== false) {
                $filePath = substr($filePath, 0, $queryPos);
            }
            
            if ($filePath === '/') {
                $filePath = '/index.html';
            }
            
            // 构建完整文件路径
            $fullPath = $this->documentRoot . $filePath;
            $realPath = realpath($fullPath);
            
            // 安全检查：防止目录遍历攻击
            if (!$realPath || !str_starts_with($realPath, $this->documentRoot)) {
                $this->sendErrorResponse($clientSocket, 403, 'Forbidden');
                return;
            }
            
            // 检查文件是否存在
            if (!file_exists($realPath)) {
                $this->sendErrorResponse($clientSocket, 404, 'Not Found');
                return;
            }
            
            if (is_dir($realPath)) {
                $this->sendErrorResponse($clientSocket, 404, 'Not Found');
                return;
            }
            
            // 读取文件内容
            $content = file_get_contents($realPath);
            if ($content === false) {
                $this->sendErrorResponse($clientSocket, 500, 'Internal Server Error');
                return;
            }
            
            // 获取MIME类型
            $contentType = $this->getContentType($realPath);
            
            // 发送响应
            $this->sendResponse($clientSocket, 200, 'OK', $contentType, $content);
            
        } catch (Exception $e) {
            echo "处理请求时出错: {$e->getMessage()}\n";
            $this->sendErrorResponse($clientSocket, 500, 'Internal Server Error');
        }
    }
    
    /**
     * 发送HTTP响应
     */
    private function sendResponse($clientSocket, $statusCode, $statusText, $contentType, $content) {
        try {
            $contentLength = strlen($content);
            
            $responseHeaders = [
                "HTTP/1.1 {$statusCode} {$statusText}",
                "Content-Type: {$contentType}",
                "Content-Length: {$contentLength}",
                "Connection: close",
                "Server: HttpServerPHP/1.0",
                "Date: " . gmdate('D, d M Y H:i:s T'),
                "" // 空行分隔头部和正文
            ];
            
            $responseHeader = implode("\r\n", $responseHeaders) . "\r\n";
            
            // 发送响应头
            socket_write($clientSocket, $responseHeader);
            
            // 发送响应正文
            if ($contentLength > 0) {
                socket_write($clientSocket, $content);
            }
            
        } catch (Exception $e) {
            echo "发送响应时出错: {$e->getMessage()}\n";
        }
    }
    
    /**
     * 发送错误响应
     */
    private function sendErrorResponse($clientSocket, $statusCode, $statusText) {
        $errorHtml = "
<html>
<head><title>{$statusCode} {$statusText}</title></head>
<body>
    <h1>{$statusCode} {$statusText}</h1>
    <p>HttpServerPHP/1.0</p>
    <hr>
    <p><em>纯AI生成的HTTP服务器</em></p>
</body>
</html>
";
        
        $this->sendResponse($clientSocket, $statusCode, $statusText, 'text/html; charset=utf-8', $errorHtml);
    }
    
    /**
     * 根据文件扩展名获取MIME类型
     */
    private function getContentType($filePath) {
        $ext = strtolower(pathinfo($filePath, PATHINFO_EXTENSION));
        $extWithDot = '.' . $ext;
        return $this->mimeTypes[$extWithDot] ?? 'application/octet-stream';
    }
}

// 主函数
function main() {
    global $argv;
    
    $port = 8080;
    $documentRoot = './Pub';
    
    // 解析命令行参数
    if (isset($argv[1])) {
        $port = intval($argv[1]);
        if ($port <= 0) {
            echo "无效的端口号: {$argv[1]}\n";
            exit(1);
        }
    }
    
    if (isset($argv[2])) {
        $documentRoot = $argv[2];
    }
    
    // 检查文档根目录
    if (!is_dir($documentRoot)) {
        echo "文档根目录不存在: {$documentRoot}\n";
        exit(1);
    }
    
    // 检查socket扩展
    if (!extension_loaded('sockets')) {
        echo "错误: 需要PHP sockets扩展\n";
        exit(1);
    }
    
    try {
        // 创建并启动服务器
        $server = new HttpServer($port, $documentRoot);
        $server->start();
    } catch (Exception $e) {
        echo "启动服务器失败: {$e->getMessage()}\n";
        exit(1);
    }
}

// 如果直接运行此文件
if (basename(__FILE__) === basename($_SERVER['SCRIPT_NAME'])) {
    main();
}

?>