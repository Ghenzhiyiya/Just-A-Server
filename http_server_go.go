package main

import (
	"bufio"
	"fmt"
	"io"
	"log"
	"mime"
	"net"
	"os"
	"os/signal"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

/**
 * 从底层实现的HTTP服务器 - Go版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

// HttpRequest 表示HTTP请求
type HttpRequest struct {
	Method  string
	Path    string
	Version string
	Headers map[string]string
}

// HttpServer HTTP服务器结构
type HttpServer struct {
	port         int
	documentRoot string
	listener     net.Listener
	running      bool
}

// NewHttpServer 创建新的HTTP服务器实例
func NewHttpServer(port int, documentRoot string) *HttpServer {
	return &HttpServer{
		port:         port,
		documentRoot: documentRoot,
		running:      false,
	}
}

// Start 启动HTTP服务器
func (s *HttpServer) Start() error {
	var err error
	s.listener, err = net.Listen("tcp", fmt.Sprintf(":%d", s.port))
	if err != nil {
		return fmt.Errorf("监听端口失败: %v", err)
	}

	s.running = true
	fmt.Printf("HTTP服务器启动在端口: %d\n", s.port)
	fmt.Printf("文档根目录: %s\n", s.documentRoot)
	fmt.Println("按 Ctrl+C 停止服务器")

	// 设置信号处理
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		fmt.Println("\n收到中断信号，正在停止服务器...")
		s.Stop()
	}()

	// 主循环：接受连接
	for s.running {
		conn, err := s.listener.Accept()
		if err != nil {
			if s.running {
				log.Printf("接受连接时出错: %v", err)
			}
			continue
		}

		// 并发处理客户端连接
		go s.handleClient(conn)
	}

	return nil
}

// Stop 停止HTTP服务器
func (s *HttpServer) Stop() {
	s.running = false
	if s.listener != nil {
		s.listener.Close()
	}
	fmt.Println("服务器已停止")
}

// handleClient 处理客户端连接
func (s *HttpServer) handleClient(conn net.Conn) {
	defer conn.Close()

	// 设置超时
	conn.SetReadDeadline(time.Now().Add(30 * time.Second))
	conn.SetWriteDeadline(time.Now().Add(30 * time.Second))

	// 解析HTTP请求
	request, err := s.parseRequest(conn)
	if err != nil {
		log.Printf("解析请求时出错: %v", err)
		s.sendErrorResponse(conn, 400, "Bad Request")
		return
	}

	if request == nil {
		s.sendErrorResponse(conn, 400, "Bad Request")
		return
	}

	fmt.Printf("收到请求: %s %s\n", request.Method, request.Path)

	// 处理请求
	s.handleRequest(request, conn)
}

// parseRequest 解析HTTP请求
func (s *HttpServer) parseRequest(conn net.Conn) (*HttpRequest, error) {
	reader := bufio.NewReader(conn)

	// 读取请求行
	requestLine, err := reader.ReadLine()
	if err != nil {
		return nil, err
	}

	parts := strings.Fields(string(requestLine))
	if len(parts) != 3 {
		return nil, fmt.Errorf("无效的请求行")
	}

	request := &HttpRequest{
		Method:  parts[0],
		Path:    parts[1],
		Version: parts[2],
		Headers: make(map[string]string),
	}

	// 读取请求头
	for {
		headerLine, err := reader.ReadLine()
		if err != nil {
			break
		}

		headerStr := string(headerLine)
		if headerStr == "" {
			break // 空行表示头部结束
		}

		colonIndex := strings.Index(headerStr, ":")
		if colonIndex > 0 {
			headerName := strings.ToLower(strings.TrimSpace(headerStr[:colonIndex]))
			headerValue := strings.TrimSpace(headerStr[colonIndex+1:])
			request.Headers[headerName] = headerValue
		}
	}

	return request, nil
}

// handleRequest 处理HTTP请求
func (s *HttpServer) handleRequest(request *HttpRequest, conn net.Conn) {
	// 只支持GET方法
	if request.Method != "GET" {
		s.sendErrorResponse(conn, 405, "Method Not Allowed")
		return
	}

	// 处理路径
	filePath := request.Path
	if filePath == "/" {
		filePath = "/index.html"
	}

	// 移除查询参数
	if queryIndex := strings.Index(filePath, "?"); queryIndex != -1 {
		filePath = filePath[:queryIndex]
	}

	// 构建完整文件路径
	fullPath := filepath.Join(s.documentRoot, strings.TrimPrefix(filePath, "/"))
	
	// 安全检查：防止目录遍历攻击
	absDocRoot, _ := filepath.Abs(s.documentRoot)
	absFullPath, _ := filepath.Abs(fullPath)
	if !strings.HasPrefix(absFullPath, absDocRoot) {
		s.sendErrorResponse(conn, 403, "Forbidden")
		return
	}

	// 检查文件是否存在
	fileInfo, err := os.Stat(absFullPath)
	if err != nil || fileInfo.IsDir() {
		s.sendErrorResponse(conn, 404, "Not Found")
		return
	}

	// 读取文件内容
	content, err := os.ReadFile(absFullPath)
	if err != nil {
		log.Printf("读取文件时出错: %v", err)
		s.sendErrorResponse(conn, 500, "Internal Server Error")
		return
	}

	// 获取MIME类型
	contentType := s.getContentType(absFullPath)

	// 发送响应
	s.sendResponse(conn, 200, "OK", contentType, content)
}

// sendResponse 发送HTTP响应
func (s *HttpServer) sendResponse(conn net.Conn, statusCode int, statusText, contentType string, content []byte) {
	response := fmt.Sprintf(
		"HTTP/1.1 %d %s\r\n"+
			"Content-Type: %s\r\n"+
			"Content-Length: %d\r\n"+
			"Connection: close\r\n"+
			"Server: HttpServerGo/1.0\r\n"+
			"Date: %s\r\n"+
			"\r\n",
		statusCode, statusText,
		contentType,
		len(content),
		time.Now().UTC().Format(time.RFC1123),
	)

	// 发送响应头
	conn.Write([]byte(response))

	// 发送响应正文
	if len(content) > 0 {
		conn.Write(content)
	}
}

// sendErrorResponse 发送错误响应
func (s *HttpServer) sendErrorResponse(conn net.Conn, statusCode int, statusText string) {
	errorHTML := fmt.Sprintf(`
<html>
<head><title>%d %s</title></head>
<body>
	<h1>%d %s</h1>
	<p>HttpServerGo/1.0</p>
	<hr>
	<p><em>纯AI生成的HTTP服务器</em></p>
</body>
</html>
`, statusCode, statusText, statusCode, statusText)

	content := []byte(errorHTML)
	s.sendResponse(conn, statusCode, statusText, "text/html; charset=utf-8", content)
}

// getContentType 根据文件扩展名获取MIME类型
func (s *HttpServer) getContentType(filePath string) string {
	ext := strings.ToLower(path.Ext(filePath))
	
	// 使用Go内置的mime包
	contentType := mime.TypeByExtension(ext)
	if contentType != "" {
		return contentType
	}

	// 手动处理一些常见类型
	switch ext {
	case ".html", ".htm":
		return "text/html; charset=utf-8"
	case ".css":
		return "text/css"
	case ".js":
		return "application/javascript"
	case ".json":
		return "application/json"
	case ".xml":
		return "application/xml"
	case ".png":
		return "image/png"
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".gif":
		return "image/gif"
	case ".svg":
		return "image/svg+xml"
	case ".ico":
		return "image/x-icon"
	case ".pdf":
		return "application/pdf"
	case ".txt":
		return "text/plain; charset=utf-8"
	case ".zip":
		return "application/zip"
	default:
		return "application/octet-stream"
	}
}

func main() {
	port := 8080
	documentRoot := "./Pub"

	// 解析命令行参数
	args := os.Args[1:]
	if len(args) >= 1 {
		if p, err := strconv.Atoi(args[0]); err == nil {
			port = p
		} else {
			fmt.Printf("无效的端口号: %s\n", args[0])
			os.Exit(1)
		}
	}

	if len(args) >= 2 {
		documentRoot = args[1]
	}

	// 检查文档根目录
	if _, err := os.Stat(documentRoot); os.IsNotExist(err) {
		fmt.Printf("文档根目录不存在: %s\n", documentRoot)
		os.Exit(1)
	}

	// 创建并启动服务器
	server := NewHttpServer(port, documentRoot)

	if err := server.Start(); err != nil {
		log.Fatalf("启动服务器失败: %v", err)
	}
}