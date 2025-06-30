#!/usr/bin/env ruby

# 从底层实现的HTTP服务器 - Ruby版本
# 纯AI生成，用于学习HTTP协议底层原理

require 'socket'
require 'uri'
require 'pathname'

class HttpRequest
  attr_accessor :method, :path, :version, :headers, :body
  
  def initialize
    @method = ''
    @path = ''
    @version = ''
    @headers = {}
    @body = ''
  end
end

class HttpServer
  def initialize(port = 8080, document_root = './Pub')
    @port = port
    @document_root = File.expand_path(document_root)
    @server = nil
    @running = false
    
    # MIME类型映射
    @mime_types = {
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
    }
  end
  
  # 启动HTTP服务器
  def start
    begin
      @server = TCPServer.new('0.0.0.0', @port)
      @running = true
      
      puts "HTTP服务器启动在端口: #{@port}"
      puts "文档根目录: #{@document_root}"
      puts "按 Ctrl+C 停止服务器"
      
      # 设置信号处理
      Signal.trap('INT') do
        puts "\n收到中断信号，正在停止服务器..."
        stop
        exit(0)
      end
      
      Signal.trap('TERM') do
        puts "\n收到终止信号，正在停止服务器..."
        stop
        exit(0)
      end
      
      # 主循环
      while @running
        begin
          # 接受连接
          client_socket = @server.accept
          
          # 在新线程中处理客户端请求
          Thread.new(client_socket) do |socket|
            handle_client(socket)
          end
          
        rescue => e
          if @running
            puts "接受连接时出错: #{e.message}"
          end
        end
      end
      
    rescue => e
      puts "启动服务器失败: #{e.message}"
      raise e
    end
  end
  
  # 停止HTTP服务器
  def stop
    @running = false
    if @server
      @server.close
      puts "服务器已停止"
    end
  end
  
  private
  
  # 处理客户端连接
  def handle_client(client_socket)
    begin
      # 设置超时
      client_socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, [30, 0].pack('l_2'))
      
      # 获取客户端地址
      client_address = client_socket.peeraddr[3]
      
      # 读取请求数据
      request_data = ''
      
      while true
        begin
          chunk = client_socket.recv_nonblock(8192)
          break if chunk.empty?
          
          request_data += chunk
          
          # 检查是否接收完整的HTTP头部
          break if request_data.include?("\r\n\r\n")
          
        rescue IO::WaitReadable
          # 使用select等待数据可读
          if IO.select([client_socket], nil, nil, 1)
            retry
          else
            break # 超时
          end
        rescue => e
          break
        end
      end
      
      return if request_data.empty?
      
      # 解析请求
      request = parse_request(request_data)
      unless request
        send_error_response(client_socket, 400, 'Bad Request')
        return
      end
      
      puts "收到请求: #{request.method} #{request.path} - #{client_address}"
      
      # 处理请求
      handle_request(request, client_socket)
      
    rescue => e
      puts "处理客户端时出错: #{e.message}"
    ensure
      client_socket.close
    end
  end
  
  # 解析HTTP请求
  def parse_request(request_data)
    begin
      lines = request_data.split("\r\n")
      
      return nil if lines.empty?
      
      # 解析请求行
      request_line = lines[0]
      parts = request_line.split(' ')
      
      return nil if parts.length != 3
      
      request = HttpRequest.new
      request.method = parts[0]
      request.path = URI.decode_www_form_component(parts[1]) # URL解码
      request.version = parts[2]
      
      # 解析请求头
      (1...lines.length).each do |i|
        line = lines[i].strip
        
        break if line.empty? # 空行表示头部结束
        
        colon_index = line.index(':')
        if colon_index && colon_index > 0
          header_name = line[0...colon_index].strip.downcase
          header_value = line[(colon_index + 1)..-1].strip
          request.headers[header_name] = header_value
        end
      end
      
      request
      
    rescue => e
      puts "解析请求时出错: #{e.message}"
      nil
    end
  end
  
  # 处理HTTP请求
  def handle_request(request, client_socket)
    begin
      # 只支持GET方法
      unless request.method == 'GET'
        send_error_response(client_socket, 405, 'Method Not Allowed')
        return
      end
      
      # 处理路径
      file_path = request.path
      
      # 移除查询参数
      uri = URI.parse(file_path)
      file_path = uri.path
      
      file_path = '/index.html' if file_path == '/'
      
      # 构建完整文件路径
      full_path = File.join(@document_root, file_path)
      real_path = File.expand_path(full_path)
      
      # 安全检查：防止目录遍历攻击
      unless real_path.start_with?(@document_root)
        send_error_response(client_socket, 403, 'Forbidden')
        return
      end
      
      # 检查文件是否存在
      unless File.exist?(real_path)
        send_error_response(client_socket, 404, 'Not Found')
        return
      end
      
      if File.directory?(real_path)
        send_error_response(client_socket, 404, 'Not Found')
        return
      end
      
      # 读取文件内容
      begin
        content = File.binread(real_path)
      rescue => e
        puts "读取文件时出错: #{e.message}"
        send_error_response(client_socket, 500, 'Internal Server Error')
        return
      end
      
      # 获取MIME类型
      content_type = get_content_type(real_path)
      
      # 发送响应
      send_response(client_socket, 200, 'OK', content_type, content)
      
    rescue => e
      puts "处理请求时出错: #{e.message}"
      send_error_response(client_socket, 500, 'Internal Server Error')
    end
  end
  
  # 发送HTTP响应
  def send_response(client_socket, status_code, status_text, content_type, content)
    begin
      content_length = content.bytesize
      
      response_headers = [
        "HTTP/1.1 #{status_code} #{status_text}",
        "Content-Type: #{content_type}",
        "Content-Length: #{content_length}",
        "Connection: close",
        "Server: HttpServerRuby/1.0",
        "Date: #{Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S GMT')}",
        "" # 空行分隔头部和正文
      ]
      
      response_header = response_headers.join("\r\n") + "\r\n"
      
      # 发送响应头
      client_socket.write(response_header)
      
      # 发送响应正文
      client_socket.write(content) if content_length > 0
      
    rescue => e
      puts "发送响应时出错: #{e.message}"
    end
  end
  
  # 发送错误响应
  def send_error_response(client_socket, status_code, status_text)
    error_html = <<~HTML
      <html>
      <head><title>#{status_code} #{status_text}</title></head>
      <body>
          <h1>#{status_code} #{status_text}</h1>
          <p>HttpServerRuby/1.0</p>
          <hr>
          <p><em>纯AI生成的HTTP服务器</em></p>
      </body>
      </html>
    HTML
    
    send_response(client_socket, status_code, status_text, 'text/html; charset=utf-8', error_html)
  end
  
  # 根据文件扩展名获取MIME类型
  def get_content_type(file_path)
    ext = File.extname(file_path).downcase
    @mime_types[ext] || 'application/octet-stream'
  end
end

# 主函数
def main
  port = 8080
  document_root = './Pub'
  
  # 解析命令行参数
  if ARGV.length >= 1
    port = ARGV[0].to_i
    if port <= 0
      puts "无效的端口号: #{ARGV[0]}"
      exit(1)
    end
  end
  
  if ARGV.length >= 2
    document_root = ARGV[1]
  end
  
  # 检查文档根目录
  unless File.directory?(document_root)
    puts "文档根目录不存在: #{document_root}"
    exit(1)
  end
  
  begin
    # 创建并启动服务器
    server = HttpServer.new(port, document_root)
    server.start
  rescue => e
    puts "启动服务器失败: #{e.message}"
    exit(1)
  end
end

# 如果直接运行此文件
if __FILE__ == $0
  main
end