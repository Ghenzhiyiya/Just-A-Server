using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

/**
 * 从底层实现的HTTP服务器 - C#版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

namespace HttpServerCSharp
{
    public class HttpRequest
    {
        public string Method { get; set; }
        public string Path { get; set; }
        public string Version { get; set; }
        public Dictionary<string, string> Headers { get; set; }

        public HttpRequest()
        {
            Headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        }
    }

    public class HttpServer
    {
        private readonly int _port;
        private readonly string _documentRoot;
        private TcpListener _listener;
        private CancellationTokenSource _cancellationTokenSource;
        private readonly SemaphoreSlim _connectionSemaphore;

        public HttpServer(int port, string documentRoot)
        {
            _port = port;
            _documentRoot = documentRoot;
            _connectionSemaphore = new SemaphoreSlim(100, 100); // 限制并发连接数
        }

        public async Task StartAsync()
        {
            _listener = new TcpListener(IPAddress.Any, _port);
            _cancellationTokenSource = new CancellationTokenSource();
            
            _listener.Start();
            Console.WriteLine($"HTTP服务器启动在端口: {_port}");
            Console.WriteLine($"文档根目录: {_documentRoot}");
            Console.WriteLine("按 Ctrl+C 停止服务器");

            // 设置控制台取消事件
            Console.CancelKeyPress += (sender, e) => {
                e.Cancel = true;
                Stop();
            };

            try
            {
                while (!_cancellationTokenSource.Token.IsCancellationRequested)
                {
                    var tcpClient = await _listener.AcceptTcpClientAsync();
                    
                    // 异步处理客户端连接
                    _ = Task.Run(async () => await HandleClientAsync(tcpClient), _cancellationTokenSource.Token);
                }
            }
            catch (ObjectDisposedException)
            {
                // 服务器已停止
            }
            catch (Exception ex)
            {
                Console.WriteLine($"服务器错误: {ex.Message}");
            }
        }

        public void Stop()
        {
            Console.WriteLine("\n正在停止服务器...");
            _cancellationTokenSource?.Cancel();
            _listener?.Stop();
        }

        private async Task HandleClientAsync(TcpClient client)
        {
            await _connectionSemaphore.WaitAsync();
            
            try
            {
                using (client)
                using (var stream = client.GetStream())
                {
                    // 设置超时
                    client.ReceiveTimeout = 30000;
                    client.SendTimeout = 30000;

                    var request = await ParseRequestAsync(stream);
                    if (request == null)
                    {
                        await SendErrorResponseAsync(stream, 400, "Bad Request");
                        return;
                    }

                    Console.WriteLine($"收到请求: {request.Method} {request.Path}");
                    await HandleRequestAsync(request, stream);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"处理客户端请求时出错: {ex.Message}");
            }
            finally
            {
                _connectionSemaphore.Release();
            }
        }

        private async Task<HttpRequest> ParseRequestAsync(NetworkStream stream)
        {
            try
            {
                var buffer = new byte[4096];
                var bytesRead = await stream.ReadAsync(buffer, 0, buffer.Length);
                
                if (bytesRead == 0)
                    return null;

                var requestData = Encoding.UTF8.GetString(buffer, 0, bytesRead);
                var lines = requestData.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None);
                
                if (lines.Length == 0)
                    return null;

                // 解析请求行
                var requestLineParts = lines[0].Split(' ');
                if (requestLineParts.Length != 3)
                    return null;

                var request = new HttpRequest
                {
                    Method = requestLineParts[0],
                    Path = requestLineParts[1],
                    Version = requestLineParts[2]
                };

                // 解析请求头
                for (int i = 1; i < lines.Length; i++)
                {
                    var line = lines[i].Trim();
                    if (string.IsNullOrEmpty(line))
                        break;

                    var colonIndex = line.IndexOf(':');
                    if (colonIndex > 0)
                    {
                        var headerName = line.Substring(0, colonIndex).Trim();
                        var headerValue = line.Substring(colonIndex + 1).Trim();
                        request.Headers[headerName] = headerValue;
                    }
                }

                return request;
            }
            catch
            {
                return null;
            }
        }

        private async Task HandleRequestAsync(HttpRequest request, NetworkStream stream)
        {
            if (request.Method != "GET")
            {
                await SendErrorResponseAsync(stream, 405, "Method Not Allowed");
                return;
            }

            var filePath = request.Path;
            if (filePath == "/")
                filePath = "/index.html";

            var fullPath = Path.Combine(_documentRoot, filePath.TrimStart('/'));
            
            // 安全检查：防止目录遍历攻击
            var normalizedPath = Path.GetFullPath(fullPath);
            var normalizedRoot = Path.GetFullPath(_documentRoot);
            
            if (!normalizedPath.StartsWith(normalizedRoot))
            {
                await SendErrorResponseAsync(stream, 403, "Forbidden");
                return;
            }

            if (!File.Exists(normalizedPath))
            {
                await SendErrorResponseAsync(stream, 404, "Not Found");
                return;
            }

            try
            {
                var content = await File.ReadAllBytesAsync(normalizedPath);
                var contentType = GetContentType(normalizedPath);
                await SendResponseAsync(stream, 200, "OK", contentType, content);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"读取文件时出错: {ex.Message}");
                await SendErrorResponseAsync(stream, 500, "Internal Server Error");
            }
        }

        private async Task SendResponseAsync(NetworkStream stream, int statusCode, string statusText, 
                                           string contentType, byte[] content)
        {
            var response = new StringBuilder();
            
            // HTTP状态行
            response.AppendLine($"HTTP/1.1 {statusCode} {statusText}");
            
            // HTTP响应头
            response.AppendLine($"Content-Type: {contentType}");
            response.AppendLine($"Content-Length: {content.Length}");
            response.AppendLine("Connection: close");
            response.AppendLine("Server: HttpServerCSharp/1.0");
            response.AppendLine($"Date: {DateTime.UtcNow:R}");
            response.AppendLine(); // 空行分隔头部和正文

            var headerBytes = Encoding.UTF8.GetBytes(response.ToString());
            
            // 发送响应头
            await stream.WriteAsync(headerBytes, 0, headerBytes.Length);
            
            // 发送响应正文
            if (content.Length > 0)
            {
                await stream.WriteAsync(content, 0, content.Length);
            }
            
            await stream.FlushAsync();
        }

        private async Task SendErrorResponseAsync(NetworkStream stream, int statusCode, string statusText)
        {
            var errorHtml = $"<html><body><h1>{statusCode} {statusText}</h1><p>HttpServerCSharp/1.0</p></body></html>";
            var content = Encoding.UTF8.GetBytes(errorHtml);
            await SendResponseAsync(stream, statusCode, statusText, "text/html; charset=utf-8", content);
        }

        private string GetContentType(string filePath)
        {
            var extension = Path.GetExtension(filePath).ToLowerInvariant();
            
            return extension switch
            {
                ".html" or ".htm" => "text/html; charset=utf-8",
                ".css" => "text/css",
                ".js" => "application/javascript",
                ".json" => "application/json",
                ".xml" => "application/xml",
                ".png" => "image/png",
                ".jpg" or ".jpeg" => "image/jpeg",
                ".gif" => "image/gif",
                ".svg" => "image/svg+xml",
                ".ico" => "image/x-icon",
                ".pdf" => "application/pdf",
                ".txt" => "text/plain; charset=utf-8",
                ".zip" => "application/zip",
                _ => "application/octet-stream"
            };
        }
    }

    class Program
    {
        static async Task Main(string[] args)
        {
            int port = 8080;
            string documentRoot = "./Pub";
            
            if (args.Length >= 1)
            {
                if (!int.TryParse(args[0], out port))
                {
                    Console.WriteLine($"无效的端口号: {args[0]}");
                    return;
                }
            }
            
            if (args.Length >= 2)
            {
                documentRoot = args[1];
            }

            // 确保文档根目录存在
            if (!Directory.Exists(documentRoot))
            {
                Console.WriteLine($"文档根目录不存在: {documentRoot}");
                return;
            }

            var server = new HttpServer(port, documentRoot);
            
            try
            {
                await server.StartAsync();
            }
            catch (Exception ex)
            {
                Console.WriteLine($"启动服务器失败: {ex.Message}");
            }
            
            Console.WriteLine("服务器已停止");
        }
    }
}