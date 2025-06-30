import java.io.*;
import java.net.*;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/**
 * 从底层实现的HTTP服务器 - Java版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */
public class HttpServerJava {
    private final int port;
    private final String documentRoot;
    private ServerSocket serverSocket;
    private ExecutorService threadPool;
    private volatile boolean running = false;

    public HttpServerJava(int port, String documentRoot) {
        this.port = port;
        this.documentRoot = documentRoot;
        this.threadPool = Executors.newFixedThreadPool(10);
    }

    public void start() throws IOException {
        serverSocket = new ServerSocket(port);
        running = true;
        System.out.println("HTTP服务器启动在端口: " + port);
        System.out.println("文档根目录: " + documentRoot);
        
        while (running) {
            try {
                Socket clientSocket = serverSocket.accept();
                threadPool.submit(new HttpRequestHandler(clientSocket));
            } catch (IOException e) {
                if (running) {
                    System.err.println("接受连接时出错: " + e.getMessage());
                }
            }
        }
    }

    public void stop() throws IOException {
        running = false;
        if (serverSocket != null) {
            serverSocket.close();
        }
        threadPool.shutdown();
    }

    private class HttpRequestHandler implements Runnable {
        private final Socket clientSocket;

        public HttpRequestHandler(Socket clientSocket) {
            this.clientSocket = clientSocket;
        }

        @Override
        public void run() {
            try (BufferedReader in = new BufferedReader(new InputStreamReader(clientSocket.getInputStream()));
                 OutputStream out = clientSocket.getOutputStream()) {
                
                // 解析HTTP请求
                HttpRequest request = parseRequest(in);
                if (request == null) {
                    sendErrorResponse(out, 400, "Bad Request");
                    return;
                }

                System.out.println("收到请求: " + request.method + " " + request.path);

                // 处理请求并发送响应
                handleRequest(request, out);
                
            } catch (IOException e) {
                System.err.println("处理请求时出错: " + e.getMessage());
            } finally {
                try {
                    clientSocket.close();
                } catch (IOException e) {
                    System.err.println("关闭客户端连接时出错: " + e.getMessage());
                }
            }
        }

        private HttpRequest parseRequest(BufferedReader in) throws IOException {
            String requestLine = in.readLine();
            if (requestLine == null || requestLine.trim().isEmpty()) {
                return null;
            }

            String[] parts = requestLine.split(" ");
            if (parts.length != 3) {
                return null;
            }

            String method = parts[0];
            String path = parts[1];
            String version = parts[2];

            // 解析请求头
            Map<String, String> headers = new HashMap<>();
            String line;
            while ((line = in.readLine()) != null && !line.trim().isEmpty()) {
                int colonIndex = line.indexOf(':');
                if (colonIndex > 0) {
                    String headerName = line.substring(0, colonIndex).trim().toLowerCase();
                    String headerValue = line.substring(colonIndex + 1).trim();
                    headers.put(headerName, headerValue);
                }
            }

            return new HttpRequest(method, path, version, headers);
        }

        private void handleRequest(HttpRequest request, OutputStream out) throws IOException {
            if (!"GET".equals(request.method)) {
                sendErrorResponse(out, 405, "Method Not Allowed");
                return;
            }

            String filePath = request.path;
            if (filePath.equals("/")) {
                filePath = "/index.html";
            }

            Path fullPath = Paths.get(documentRoot, filePath.substring(1));
            
            if (!Files.exists(fullPath) || Files.isDirectory(fullPath)) {
                sendErrorResponse(out, 404, "Not Found");
                return;
            }

            try {
                byte[] content = Files.readAllBytes(fullPath);
                String contentType = getContentType(fullPath.toString());
                
                sendResponse(out, 200, "OK", contentType, content);
            } catch (IOException e) {
                sendErrorResponse(out, 500, "Internal Server Error");
            }
        }

        private void sendResponse(OutputStream out, int statusCode, String statusText, 
                                String contentType, byte[] content) throws IOException {
            PrintWriter writer = new PrintWriter(out, true);
            
            // HTTP状态行
            writer.println("HTTP/1.1 " + statusCode + " " + statusText);
            
            // HTTP响应头
            writer.println("Content-Type: " + contentType);
            writer.println("Content-Length: " + content.length);
            writer.println("Connection: close");
            writer.println("Server: HttpServerJava/1.0");
            writer.println(); // 空行分隔头部和正文
            
            writer.flush();
            
            // HTTP响应正文
            out.write(content);
            out.flush();
        }

        private void sendErrorResponse(OutputStream out, int statusCode, String statusText) throws IOException {
            String errorHtml = "<html><body><h1>" + statusCode + " " + statusText + "</h1></body></html>";
            sendResponse(out, statusCode, statusText, "text/html", errorHtml.getBytes());
        }

        private String getContentType(String filePath) {
            if (filePath.endsWith(".html") || filePath.endsWith(".htm")) {
                return "text/html";
            } else if (filePath.endsWith(".css")) {
                return "text/css";
            } else if (filePath.endsWith(".js")) {
                return "application/javascript";
            } else if (filePath.endsWith(".png")) {
                return "image/png";
            } else if (filePath.endsWith(".jpg") || filePath.endsWith(".jpeg")) {
                return "image/jpeg";
            } else {
                return "text/plain";
            }
        }
    }

    private static class HttpRequest {
        final String method;
        final String path;
        final String version;
        final Map<String, String> headers;

        HttpRequest(String method, String path, String version, Map<String, String> headers) {
            this.method = method;
            this.path = path;
            this.version = version;
            this.headers = headers;
        }
    }

    public static void main(String[] args) {
        int port = 8080;
        String documentRoot = "./Pub";
        
        if (args.length >= 1) {
            try {
                port = Integer.parseInt(args[0]);
            } catch (NumberFormatException e) {
                System.err.println("无效的端口号: " + args[0]);
                return;
            }
        }
        
        if (args.length >= 2) {
            documentRoot = args[1];
        }

        HttpServerJava server = new HttpServerJava(port, documentRoot);
        
        // 添加关闭钩子
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try {
                System.out.println("\n正在关闭服务器...");
                server.stop();
            } catch (IOException e) {
                System.err.println("关闭服务器时出错: " + e.getMessage());
            }
        }));
        
        try {
            server.start();
        } catch (IOException e) {
            System.err.println("启动服务器失败: " + e.getMessage());
        }
    }
}