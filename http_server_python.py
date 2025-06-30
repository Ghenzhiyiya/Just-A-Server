#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从底层实现的HTTP服务器 - Python版本
纯AI生成，用于学习HTTP协议底层原理
"""

import socket
import threading
import os
import mimetypes
import urllib.parse
from datetime import datetime
import signal
import sys
from pathlib import Path

class HttpRequest:
    def __init__(self):
        self.method = ""
        self.path = ""
        self.version = ""
        self.headers = {}
        self.body = b""

class HttpServer:
    def __init__(self, port=8080, document_root="./Pub"):
        self.port = port
        self.document_root = os.path.abspath(document_root)
        self.server_socket = None
        self.running = False
        
        # 初始化MIME类型
        mimetypes.init()
        
    def start(self):
        """启动HTTP服务器"""
        try:
            # 创建socket
            self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            
            # 设置socket选项，允许地址重用
            self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            
            # 绑定地址和端口
            self.server_socket.bind(('', self.port))
            
            # 开始监听
            self.server_socket.listen(10)
            
            self.running = True
            print(f"HTTP服务器启动在端口: {self.port}")
            print(f"文档根目录: {self.document_root}")
            print("按 Ctrl+C 停止服务器")
            
            # 设置信号处理
            signal.signal(signal.SIGINT, self._signal_handler)
            
            while self.running:
                try:
                    # 接受客户端连接
                    client_socket, client_address = self.server_socket.accept()
                    
                    # 创建新线程处理客户端请求
                    client_thread = threading.Thread(
                        target=self._handle_client,
                        args=(client_socket, client_address)
                    )
                    client_thread.daemon = True
                    client_thread.start()
                    
                except socket.error as e:
                    if self.running:
                        print(f"接受连接时出错: {e}")
                    break
                    
        except Exception as e:
            print(f"启动服务器失败: {e}")
        finally:
            self.stop()
    
    def stop(self):
        """停止HTTP服务器"""
        self.running = False
        if self.server_socket:
            try:
                self.server_socket.close()
            except:
                pass
        print("\n服务器已停止")
    
    def _signal_handler(self, signum, frame):
        """信号处理函数"""
        print("\n收到中断信号，正在停止服务器...")
        self.stop()
        sys.exit(0)
    
    def _handle_client(self, client_socket, client_address):
        """处理客户端请求"""
        try:
            # 设置超时
            client_socket.settimeout(30)
            
            # 接收请求数据
            request_data = client_socket.recv(4096)
            
            if not request_data:
                return
            
            # 解析HTTP请求
            request = self._parse_request(request_data.decode('utf-8', errors='ignore'))
            
            if not request:
                self._send_error_response(client_socket, 400, "Bad Request")
                return
            
            print(f"收到请求: {request.method} {request.path} - {client_address[0]}")
            
            # 处理请求
            self._handle_request(request, client_socket)
            
        except socket.timeout:
            print(f"客户端连接超时: {client_address[0]}")
        except Exception as e:
            print(f"处理客户端请求时出错: {e}")
        finally:
            try:
                client_socket.close()
            except:
                pass
    
    def _parse_request(self, request_data):
        """解析HTTP请求"""
        try:
            lines = request_data.split('\r\n')
            if not lines:
                return None
            
            # 解析请求行
            request_line = lines[0]
            parts = request_line.split(' ')
            
            if len(parts) != 3:
                return None
            
            request = HttpRequest()
            request.method = parts[0]
            request.path = urllib.parse.unquote(parts[1])  # URL解码
            request.version = parts[2]
            
            # 解析请求头
            for line in lines[1:]:
                if not line.strip():
                    break
                
                if ':' in line:
                    header_name, header_value = line.split(':', 1)
                    request.headers[header_name.strip().lower()] = header_value.strip()
            
            return request
            
        except Exception as e:
            print(f"解析请求时出错: {e}")
            return None
    
    def _handle_request(self, request, client_socket):
        """处理HTTP请求"""
        # 只支持GET方法
        if request.method != 'GET':
            self._send_error_response(client_socket, 405, "Method Not Allowed")
            return
        
        # 处理路径
        file_path = request.path
        if file_path == '/':
            file_path = '/index.html'
        
        # 移除查询参数
        if '?' in file_path:
            file_path = file_path.split('?')[0]
        
        # 构建完整文件路径
        full_path = os.path.join(self.document_root, file_path.lstrip('/'))
        full_path = os.path.abspath(full_path)
        
        # 安全检查：防止目录遍历攻击
        if not full_path.startswith(self.document_root):
            self._send_error_response(client_socket, 403, "Forbidden")
            return
        
        # 检查文件是否存在
        if not os.path.exists(full_path) or os.path.isdir(full_path):
            self._send_error_response(client_socket, 404, "Not Found")
            return
        
        try:
            # 读取文件内容
            with open(full_path, 'rb') as f:
                content = f.read()
            
            # 获取MIME类型
            content_type = self._get_content_type(full_path)
            
            # 发送响应
            self._send_response(client_socket, 200, "OK", content_type, content)
            
        except Exception as e:
            print(f"读取文件时出错: {e}")
            self._send_error_response(client_socket, 500, "Internal Server Error")
    
    def _send_response(self, client_socket, status_code, status_text, content_type, content):
        """发送HTTP响应"""
        try:
            # 构建响应头
            response_lines = [
                f"HTTP/1.1 {status_code} {status_text}",
                f"Content-Type: {content_type}",
                f"Content-Length: {len(content)}",
                "Connection: close",
                "Server: HttpServerPython/1.0",
                f"Date: {datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S GMT')}",
                ""  # 空行分隔头部和正文
            ]
            
            response_header = '\r\n'.join(response_lines) + '\r\n'
            
            # 发送响应头
            client_socket.send(response_header.encode('utf-8'))
            
            # 发送响应正文
            if content:
                client_socket.send(content)
                
        except Exception as e:
            print(f"发送响应时出错: {e}")
    
    def _send_error_response(self, client_socket, status_code, status_text):
        """发送错误响应"""
        error_html = f"""
        <html>
        <head><title>{status_code} {status_text}</title></head>
        <body>
            <h1>{status_code} {status_text}</h1>
            <p>HttpServerPython/1.0</p>
            <hr>
            <p><em>纯AI生成的HTTP服务器</em></p>
        </body>
        </html>
        """
        
        content = error_html.encode('utf-8')
        self._send_response(client_socket, status_code, status_text, "text/html; charset=utf-8", content)
    
    def _get_content_type(self, file_path):
        """根据文件扩展名获取MIME类型"""
        # 使用Python内置的mimetypes模块
        content_type, _ = mimetypes.guess_type(file_path)
        
        if content_type:
            # 为文本类型添加字符集
            if content_type.startswith('text/'):
                content_type += '; charset=utf-8'
            return content_type
        
        # 默认类型
        return 'application/octet-stream'

def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='HTTP服务器 - Python版本（纯AI生成）')
    parser.add_argument('--port', '-p', type=int, default=8080, help='服务器端口（默认: 8080）')
    parser.add_argument('--root', '-r', default='./Pub', help='文档根目录（默认: ./Pub）')
    parser.add_argument('--verbose', '-v', action='store_true', help='详细输出')
    
    args = parser.parse_args()
    
    # 检查文档根目录
    if not os.path.exists(args.root):
        print(f"错误: 文档根目录不存在: {args.root}")
        return 1
    
    # 创建并启动服务器
    server = HttpServer(args.port, args.root)
    
    try:
        server.start()
    except KeyboardInterrupt:
        print("\n收到键盘中断")
    except Exception as e:
        print(f"服务器错误: {e}")
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())