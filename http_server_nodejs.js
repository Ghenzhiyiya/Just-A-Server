#!/usr/bin/env node

/**
 * 从底层实现的HTTP服务器 - Node.js版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

const net = require('net');
const fs = require('fs');
const path = require('path');
const url = require('url');
const { promisify } = require('util');

// 异步文件操作
const readFile = promisify(fs.readFile);
const stat = promisify(fs.stat);

class HttpRequest {
    constructor() {
        this.method = '';
        this.path = '';
        this.version = '';
        this.headers = {};
        this.body = Buffer.alloc(0);
    }
}

class HttpServer {
    constructor(port = 8080, documentRoot = './Pub') {
        this.port = port;
        this.documentRoot = path.resolve(documentRoot);
        this.server = null;
        this.running = false;
        
        // MIME类型映射
        this.mimeTypes = {
            '.html': 'text/html; charset=utf-8',
            '.htm': 'text/html; charset=utf-8',
            '.css': 'text/css',
            '.js': 'application/javascript',
            '.json': 'application/json',
            '.xml': 'application/xml',
            '.png': 'image/png',
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.gif': 'image/gif',
            '.svg': 'image/svg+xml',
            '.ico': 'image/x-icon',
            '.pdf': 'application/pdf',
            '.txt': 'text/plain; charset=utf-8',
            '.zip': 'application/zip',
            '.mp4': 'video/mp4',
            '.mp3': 'audio/mpeg',
            '.wav': 'audio/wav'
        };
    }

    /**
     * 启动HTTP服务器
     */
    start() {
        return new Promise((resolve, reject) => {
            this.server = net.createServer();
            
            this.server.on('connection', (socket) => {
                this.handleConnection(socket);
            });
            
            this.server.on('error', (err) => {
                console.error(`服务器错误: ${err.message}`);
                reject(err);
            });
            
            this.server.listen(this.port, () => {
                this.running = true;
                console.log(`HTTP服务器启动在端口: ${this.port}`);
                console.log(`文档根目录: ${this.documentRoot}`);
                console.log('按 Ctrl+C 停止服务器');
                
                // 设置信号处理
                process.on('SIGINT', () => {
                    console.log('\n收到中断信号，正在停止服务器...');
                    this.stop();
                    process.exit(0);
                });
                
                process.on('SIGTERM', () => {
                    console.log('\n收到终止信号，正在停止服务器...');
                    this.stop();
                    process.exit(0);
                });
                
                resolve();
            });
        });
    }

    /**
     * 停止HTTP服务器
     */
    stop() {
        this.running = false;
        if (this.server) {
            this.server.close(() => {
                console.log('服务器已停止');
            });
        }
    }

    /**
     * 处理客户端连接
     */
    handleConnection(socket) {
        // 设置超时
        socket.setTimeout(30000);
        
        let requestData = Buffer.alloc(0);
        let headersParsed = false;
        
        socket.on('data', async (chunk) => {
            try {
                requestData = Buffer.concat([requestData, chunk]);
                
                // 检查是否接收完整的HTTP头部
                if (!headersParsed) {
                    const headerEndIndex = requestData.indexOf('\r\n\r\n');
                    if (headerEndIndex !== -1) {
                        headersParsed = true;
                        
                        // 解析请求
                        const request = this.parseRequest(requestData.toString('utf8', 0, headerEndIndex + 4));
                        
                        if (!request) {
                            await this.sendErrorResponse(socket, 400, 'Bad Request');
                            socket.end();
                            return;
                        }
                        
                        console.log(`收到请求: ${request.method} ${request.path} - ${socket.remoteAddress}`);
                        
                        // 处理请求
                        await this.handleRequest(request, socket);
                        socket.end();
                    }
                }
            } catch (error) {
                console.error(`处理数据时出错: ${error.message}`);
                socket.end();
            }
        });
        
        socket.on('timeout', () => {
            console.log(`连接超时: ${socket.remoteAddress}`);
            socket.end();
        });
        
        socket.on('error', (err) => {
            console.error(`Socket错误: ${err.message}`);
        });
    }

    /**
     * 解析HTTP请求
     */
    parseRequest(requestData) {
        try {
            const lines = requestData.split('\r\n');
            
            if (lines.length === 0) {
                return null;
            }
            
            // 解析请求行
            const requestLine = lines[0];
            const parts = requestLine.split(' ');
            
            if (parts.length !== 3) {
                return null;
            }
            
            const request = new HttpRequest();
            request.method = parts[0];
            request.path = decodeURIComponent(parts[1]); // URL解码
            request.version = parts[2];
            
            // 解析请求头
            for (let i = 1; i < lines.length; i++) {
                const line = lines[i].trim();
                
                if (line === '') {
                    break; // 空行表示头部结束
                }
                
                const colonIndex = line.indexOf(':');
                if (colonIndex > 0) {
                    const headerName = line.substring(0, colonIndex).trim().toLowerCase();
                    const headerValue = line.substring(colonIndex + 1).trim();
                    request.headers[headerName] = headerValue;
                }
            }
            
            return request;
            
        } catch (error) {
            console.error(`解析请求时出错: ${error.message}`);
            return null;
        }
    }

    /**
     * 处理HTTP请求
     */
    async handleRequest(request, socket) {
        try {
            // 只支持GET方法
            if (request.method !== 'GET') {
                await this.sendErrorResponse(socket, 405, 'Method Not Allowed');
                return;
            }
            
            // 处理路径
            let filePath = request.path;
            
            // 移除查询参数
            const parsedUrl = url.parse(filePath);
            filePath = parsedUrl.pathname;
            
            if (filePath === '/') {
                filePath = '/index.html';
            }
            
            // 构建完整文件路径
            const fullPath = path.join(this.documentRoot, filePath);
            const resolvedPath = path.resolve(fullPath);
            
            // 安全检查：防止目录遍历攻击
            if (!resolvedPath.startsWith(this.documentRoot)) {
                await this.sendErrorResponse(socket, 403, 'Forbidden');
                return;
            }
            
            // 检查文件是否存在
            try {
                const stats = await stat(resolvedPath);
                
                if (stats.isDirectory()) {
                    await this.sendErrorResponse(socket, 404, 'Not Found');
                    return;
                }
                
                // 读取文件内容
                const content = await readFile(resolvedPath);
                
                // 获取MIME类型
                const contentType = this.getContentType(resolvedPath);
                
                // 发送响应
                await this.sendResponse(socket, 200, 'OK', contentType, content);
                
            } catch (fileError) {
                if (fileError.code === 'ENOENT') {
                    await this.sendErrorResponse(socket, 404, 'Not Found');
                } else {
                    console.error(`文件操作错误: ${fileError.message}`);
                    await this.sendErrorResponse(socket, 500, 'Internal Server Error');
                }
            }
            
        } catch (error) {
            console.error(`处理请求时出错: ${error.message}`);
            await this.sendErrorResponse(socket, 500, 'Internal Server Error');
        }
    }

    /**
     * 发送HTTP响应
     */
    async sendResponse(socket, statusCode, statusText, contentType, content) {
        try {
            const responseHeaders = [
                `HTTP/1.1 ${statusCode} ${statusText}`,
                `Content-Type: ${contentType}`,
                `Content-Length: ${content.length}`,
                'Connection: close',
                'Server: HttpServerNodeJS/1.0',
                `Date: ${new Date().toUTCString()}`,
                '' // 空行分隔头部和正文
            ];
            
            const responseHeader = responseHeaders.join('\r\n') + '\r\n';
            
            // 发送响应头
            socket.write(responseHeader, 'utf8');
            
            // 发送响应正文
            if (content.length > 0) {
                socket.write(content);
            }
            
        } catch (error) {
            console.error(`发送响应时出错: ${error.message}`);
        }
    }

    /**
     * 发送错误响应
     */
    async sendErrorResponse(socket, statusCode, statusText) {
        const errorHtml = `
<html>
<head><title>${statusCode} ${statusText}</title></head>
<body>
    <h1>${statusCode} ${statusText}</h1>
    <p>HttpServerNodeJS/1.0</p>
    <hr>
    <p><em>纯AI生成的HTTP服务器</em></p>
</body>
</html>
`;
        
        const content = Buffer.from(errorHtml, 'utf8');
        await this.sendResponse(socket, statusCode, statusText, 'text/html; charset=utf-8', content);
    }

    /**
     * 根据文件扩展名获取MIME类型
     */
    getContentType(filePath) {
        const ext = path.extname(filePath).toLowerCase();
        return this.mimeTypes[ext] || 'application/octet-stream';
    }
}

// 主函数
function main() {
    const args = process.argv.slice(2);
    
    let port = 8080;
    let documentRoot = './Pub';
    
    // 解析命令行参数
    if (args.length >= 1) {
        const parsedPort = parseInt(args[0]);
        if (isNaN(parsedPort)) {
            console.error(`无效的端口号: ${args[0]}`);
            process.exit(1);
        }
        port = parsedPort;
    }
    
    if (args.length >= 2) {
        documentRoot = args[1];
    }
    
    // 检查文档根目录
    if (!fs.existsSync(documentRoot)) {
        console.error(`文档根目录不存在: ${documentRoot}`);
        process.exit(1);
    }
    
    // 创建并启动服务器
    const server = new HttpServer(port, documentRoot);
    
    server.start().catch((error) => {
        console.error(`启动服务器失败: ${error.message}`);
        process.exit(1);
    });
}

// 如果直接运行此文件
if (require.main === module) {
    main();
}

module.exports = { HttpServer, HttpRequest };