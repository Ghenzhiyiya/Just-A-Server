use std::collections::HashMap;
use std::fs;
use std::io::prelude::*;
use std::net::{TcpListener, TcpStream};
use std::path::Path;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

/**
 * 从底层实现的HTTP服务器 - Rust版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

#[derive(Debug, Clone)]
struct HttpRequest {
    method: String,
    path: String,
    version: String,
    headers: HashMap<String, String>,
}

struct HttpServer {
    port: u16,
    document_root: String,
}

impl HttpServer {
    fn new(port: u16, document_root: String) -> Self {
        HttpServer {
            port,
            document_root,
        }
    }

    fn start(&self) -> std::io::Result<()> {
        let listener = TcpListener::bind(format!("127.0.0.1:{}", self.port))?;
        println!("HTTP服务器启动在端口: {}", self.port);
        println!("文档根目录: {}", self.document_root);

        let document_root = Arc::new(self.document_root.clone());

        for stream in listener.incoming() {
            match stream {
                Ok(stream) => {
                    let document_root = Arc::clone(&document_root);
                    thread::spawn(move || {
                        if let Err(e) = Self::handle_client(stream, document_root) {
                            eprintln!("处理客户端请求时出错: {}", e);
                        }
                    });
                }
                Err(e) => {
                    eprintln!("接受连接时出错: {}", e);
                }
            }
        }

        Ok(())
    }

    fn handle_client(mut stream: TcpStream, document_root: Arc<String>) -> std::io::Result<()> {
        // 设置读取超时
        stream.set_read_timeout(Some(Duration::from_secs(30)))?;
        
        let mut buffer = [0; 4096];
        let bytes_read = stream.read(&mut buffer)?;
        
        if bytes_read == 0 {
            return Ok(());
        }

        let request_data = String::from_utf8_lossy(&buffer[..bytes_read]);
        
        match Self::parse_request(&request_data) {
            Some(request) => {
                println!("收到请求: {} {}", request.method, request.path);
                Self::handle_request(request, &mut stream, &document_root)?
            }
            None => Self::send_error_response(&mut stream, 400, "Bad Request")?,
        }

        Ok(())
    }

    fn parse_request(request_data: &str) -> Option<HttpRequest> {
        let lines: Vec<&str> = request_data.lines().collect();
        
        if lines.is_empty() {
            return None;
        }

        // 解析请求行
        let request_line_parts: Vec<&str> = lines[0].split_whitespace().collect();
        if request_line_parts.len() != 3 {
            return None;
        }

        let method = request_line_parts[0].to_string();
        let path = request_line_parts[1].to_string();
        let version = request_line_parts[2].to_string();

        // 解析请求头
        let mut headers = HashMap::new();
        for line in &lines[1..] {
            if line.trim().is_empty() {
                break;
            }

            if let Some(colon_pos) = line.find(':') {
                let header_name = line[..colon_pos].trim().to_lowercase();
                let header_value = line[colon_pos + 1..].trim().to_string();
                headers.insert(header_name, header_value);
            }
        }

        Some(HttpRequest {
            method,
            path,
            version,
            headers,
        })
    }

    fn handle_request(
        request: HttpRequest,
        stream: &mut TcpStream,
        document_root: &str,
    ) -> std::io::Result<()> {
        if request.method != "GET" {
            return Self::send_error_response(stream, 405, "Method Not Allowed");
        }

        let mut file_path = request.path;
        if file_path == "/" {
            file_path = "/index.html".to_string();
        }

        // 移除路径开头的斜杠
        let file_path = if file_path.starts_with('/') {
            &file_path[1..]
        } else {
            &file_path
        };

        let full_path = Path::new(document_root).join(file_path);

        if !full_path.exists() || full_path.is_dir() {
            return Self::send_error_response(stream, 404, "Not Found");
        }

        match fs::read(&full_path) {
            Ok(content) => {
                let content_type = Self::get_content_type(&full_path);
                Self::send_response(stream, 200, "OK", &content_type, &content)
            }
            Err(_) => Self::send_error_response(stream, 500, "Internal Server Error"),
        }
    }

    fn send_response(
        stream: &mut TcpStream,
        status_code: u16,
        status_text: &str,
        content_type: &str,
        content: &[u8],
    ) -> std::io::Result<()> {
        // HTTP状态行
        let status_line = format!("HTTP/1.1 {} {}\r\n", status_code, status_text);
        
        // HTTP响应头
        let headers = format!(
            "Content-Type: {}\r\nContent-Length: {}\r\nConnection: close\r\nServer: HttpServerRust/1.0\r\n\r\n",
            content_type,
            content.len()
        );

        // 发送响应头
        stream.write_all(status_line.as_bytes())?;
        stream.write_all(headers.as_bytes())?;
        
        // 发送响应正文
        stream.write_all(content)?;
        stream.flush()?;

        Ok(())
    }

    fn send_error_response(
        stream: &mut TcpStream,
        status_code: u16,
        status_text: &str,
    ) -> std::io::Result<()> {
        let error_html = format!(
            "<html><body><h1>{} {}</h1></body></html>",
            status_code, status_text
        );
        Self::send_response(
            stream,
            status_code,
            status_text,
            "text/html",
            error_html.as_bytes(),
        )
    }

    fn get_content_type(file_path: &Path) -> String {
        match file_path.extension().and_then(|ext| ext.to_str()) {
            Some("html") | Some("htm") => "text/html".to_string(),
            Some("css") => "text/css".to_string(),
            Some("js") => "application/javascript".to_string(),
            Some("png") => "image/png".to_string(),
            Some("jpg") | Some("jpeg") => "image/jpeg".to_string(),
            Some("gif") => "image/gif".to_string(),
            Some("svg") => "image/svg+xml".to_string(),
            Some("ico") => "image/x-icon".to_string(),
            Some("json") => "application/json".to_string(),
            Some("xml") => "application/xml".to_string(),
            Some("pdf") => "application/pdf".to_string(),
            Some("txt") => "text/plain".to_string(),
            _ => "application/octet-stream".to_string(),
        }
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    
    let port = if args.len() >= 2 {
        match args[1].parse::<u16>() {
            Ok(p) => p,
            Err(_) => {
                eprintln!("无效的端口号: {}", args[1]);
                return;
            }
        }
    } else {
        8080
    };

    let document_root = if args.len() >= 3 {
        args[2].clone()
    } else {
        "./Pub".to_string()
    };

    // 设置Ctrl+C处理
    ctrlc::set_handler(move || {
        println!("\n收到中断信号，正在关闭服务器...");
        std::process::exit(0);
    })
    .expect("设置Ctrl+C处理器时出错");

    let server = HttpServer::new(port, document_root);
    
    if let Err(e) = server.start() {
        eprintln!("启动服务器失败: {}", e);
    }
}