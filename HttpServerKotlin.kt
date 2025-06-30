#!/usr/bin/env kotlin

/**
 * 从底层实现的HTTP服务器 - Kotlin版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

import java.io.*
import java.net.*
import java.nio.file.*
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.util.*
import java.util.concurrent.Executors
import kotlin.system.exitProcess

data class HttpRequest(
    var method: String = "",
    var path: String = "",
    var version: String = "",
    val headers: MutableMap<String, String> = mutableMapOf(),
    var body: String = ""
)

class HttpServer(private val port: Int = 8080, documentRoot: String = "./Pub") {
    private val documentRoot: Path = Paths.get(documentRoot).toAbsolutePath().normalize()
    private var serverSocket: ServerSocket? = null
    private var running = false
    private val executor = Executors.newFixedThreadPool(10)
    
    // MIME类型映射
    private val mimeTypes = mapOf(
        ".html" to "text/html; charset=utf-8",
        ".htm" to "text/html; charset=utf-8",
        ".css" to "text/css",
        ".js" to "application/javascript",
        ".json" to "application/json",
        ".xml" to "application/xml",
        ".png" to "image/png",
        ".jpg" to "image/jpeg",
        ".jpeg" to "image/jpeg",
        ".gif" to "image/gif",
        ".svg" to "image/svg+xml",
        ".ico" to "image/x-icon",
        ".pdf" to "application/pdf",
        ".txt" to "text/plain; charset=utf-8",
        ".zip" to "application/zip",
        ".mp4" to "video/mp4",
        ".mp3" to "audio/mpeg",
        ".wav" to "audio/wav"
    )
    
    /**
     * 启动HTTP服务器
     */
    fun start() {
        try {
            serverSocket = ServerSocket(port)
            running = true
            
            println("HTTP服务器启动在端口: $port")
            println("文档根目录: $documentRoot")
            println("按 Ctrl+C 停止服务器")
            
            // 设置关闭钩子
            Runtime.getRuntime().addShutdownHook(Thread {
                println("\n收到停止信号，正在停止服务器...")
                stop()
            })
            
            // 主循环
            while (running) {
                try {
                    val clientSocket = serverSocket?.accept()
                    if (clientSocket != null && running) {
                        // 在线程池中处理客户端请求
                        executor.submit {
                            handleClient(clientSocket)
                        }
                    }
                } catch (e: SocketException) {
                    if (running) {
                        println("接受连接时出错: ${e.message}")
                    }
                } catch (e: Exception) {
                    if (running) {
                        println("服务器错误: ${e.message}")
                    }
                }
            }
        } catch (e: Exception) {
            println("启动服务器失败: ${e.message}")
            throw e
        }
    }
    
    /**
     * 停止HTTP服务器
     */
    fun stop() {
        running = false
        try {
            serverSocket?.close()
            executor.shutdown()
            println("服务器已停止")
        } catch (e: Exception) {
            println("停止服务器时出错: ${e.message}")
        }
    }
    
    /**
     * 处理客户端连接
     */
    private fun handleClient(clientSocket: Socket) {
        try {
            clientSocket.soTimeout = 30000 // 30秒超时
            
            val clientAddress = clientSocket.inetAddress.hostAddress
            val input = BufferedReader(InputStreamReader(clientSocket.getInputStream()))
            
            // 读取请求数据
            val requestLines = mutableListOf<String>()
            var line: String?
            
            // 读取请求行和头部
            while (input.readLine().also { line = it } != null) {
                if (line!!.isEmpty()) {
                    break // 空行表示头部结束
                }
                requestLines.add(line!!)
            }
            
            if (requestLines.isEmpty()) {
                return
            }
            
            // 解析请求
            val request = parseRequest(requestLines)
            if (request == null) {
                sendErrorResponse(clientSocket, 400, "Bad Request")
                return
            }
            
            println("收到请求: ${request.method} ${request.path} - $clientAddress")
            
            // 处理请求
            handleRequest(request, clientSocket)
            
        } catch (e: SocketTimeoutException) {
            println("客户端连接超时: ${clientSocket.inetAddress.hostAddress}")
        } catch (e: Exception) {
            println("处理客户端时出错: ${e.message}")
        } finally {
            try {
                clientSocket.close()
            } catch (e: Exception) {
                // 忽略关闭错误
            }
        }
    }
    
    /**
     * 解析HTTP请求
     */
    private fun parseRequest(requestLines: List<String>): HttpRequest? {
        try {
            if (requestLines.isEmpty()) {
                return null
            }
            
            // 解析请求行
            val requestLine = requestLines[0]
            val parts = requestLine.split(" ")
            
            if (parts.size != 3) {
                return null
            }
            
            val request = HttpRequest()
            request.method = parts[0]
            request.path = URLDecoder.decode(parts[1], "UTF-8") // URL解码
            request.version = parts[2]
            
            // 解析请求头
            for (i in 1 until requestLines.size) {
                val line = requestLines[i].trim()
                
                val colonIndex = line.indexOf(':')
                if (colonIndex > 0) {
                    val headerName = line.substring(0, colonIndex).trim().lowercase()
                    val headerValue = line.substring(colonIndex + 1).trim()
                    request.headers[headerName] = headerValue
                }
            }
            
            return request
            
        } catch (e: Exception) {
            println("解析请求时出错: ${e.message}")
            return null
        }
    }
    
    /**
     * 处理HTTP请求
     */
    private fun handleRequest(request: HttpRequest, clientSocket: Socket) {
        try {
            // 只支持GET方法
            if (request.method != "GET") {
                sendErrorResponse(clientSocket, 405, "Method Not Allowed")
                return
            }
            
            // 处理路径
            var filePath = request.path
            
            // 移除查询参数
            val queryIndex = filePath.indexOf('?')
            if (queryIndex != -1) {
                filePath = filePath.substring(0, queryIndex)
            }
            
            if (filePath == "/") {
                filePath = "/index.html"
            }
            
            // 构建完整文件路径
            val fullPath = documentRoot.resolve(filePath.removePrefix("/")).normalize()
            
            // 安全检查：防止目录遍历攻击
            if (!fullPath.startsWith(documentRoot)) {
                sendErrorResponse(clientSocket, 403, "Forbidden")
                return
            }
            
            // 检查文件是否存在
            if (!Files.exists(fullPath)) {
                sendErrorResponse(clientSocket, 404, "Not Found")
                return
            }
            
            if (Files.isDirectory(fullPath)) {
                sendErrorResponse(clientSocket, 404, "Not Found")
                return
            }
            
            // 读取文件内容
            val content = try {
                Files.readAllBytes(fullPath)
            } catch (e: Exception) {
                println("读取文件时出错: ${e.message}")
                sendErrorResponse(clientSocket, 500, "Internal Server Error")
                return
            }
            
            // 获取MIME类型
            val contentType = getContentType(fullPath.toString())
            
            // 发送响应
            sendResponse(clientSocket, 200, "OK", contentType, content)
            
        } catch (e: Exception) {
            println("处理请求时出错: ${e.message}")
            sendErrorResponse(clientSocket, 500, "Internal Server Error")
        }
    }
    
    /**
     * 发送HTTP响应
     */
    private fun sendResponse(
        clientSocket: Socket,
        statusCode: Int,
        statusText: String,
        contentType: String,
        content: ByteArray
    ) {
        try {
            val output = clientSocket.getOutputStream()
            val writer = PrintWriter(OutputStreamWriter(output, "UTF-8"))
            
            val contentLength = content.size
            val currentTime = ZonedDateTime.now().format(DateTimeFormatter.RFC_1123_DATE_TIME)
            
            // 发送响应头
            writer.println("HTTP/1.1 $statusCode $statusText")
            writer.println("Content-Type: $contentType")
            writer.println("Content-Length: $contentLength")
            writer.println("Connection: close")
            writer.println("Server: HttpServerKotlin/1.0")
            writer.println("Date: $currentTime")
            writer.println() // 空行分隔头部和正文
            writer.flush()
            
            // 发送响应正文
            if (content.isNotEmpty()) {
                output.write(content)
            }
            output.flush()
            
        } catch (e: Exception) {
            println("发送响应时出错: ${e.message}")
        }
    }
    
    /**
     * 发送错误响应
     */
    private fun sendErrorResponse(clientSocket: Socket, statusCode: Int, statusText: String) {
        val errorHtml = """
            <html>
            <head><title>$statusCode $statusText</title></head>
            <body>
                <h1>$statusCode $statusText</h1>
                <p>HttpServerKotlin/1.0</p>
                <hr>
                <p><em>纯AI生成的HTTP服务器</em></p>
            </body>
            </html>
        """.trimIndent()
        
        val content = errorHtml.toByteArray(Charsets.UTF_8)
        sendResponse(clientSocket, statusCode, statusText, "text/html; charset=utf-8", content)
    }
    
    /**
     * 根据文件扩展名获取MIME类型
     */
    private fun getContentType(filePath: String): String {
        val lastDotIndex = filePath.lastIndexOf('.')
        if (lastDotIndex == -1) {
            return "application/octet-stream"
        }
        
        val ext = filePath.substring(lastDotIndex).lowercase()
        return mimeTypes[ext] ?: "application/octet-stream"
    }
}

/**
 * 主函数
 */
fun main(args: Array<String>) {
    var port = 8080
    var documentRoot = "./Pub"
    
    // 解析命令行参数
    if (args.isNotEmpty()) {
        try {
            port = args[0].toInt()
            if (port <= 0) {
                println("无效的端口号: ${args[0]}")
                exitProcess(1)
            }
        } catch (e: NumberFormatException) {
            println("无效的端口号: ${args[0]}")
            exitProcess(1)
        }
    }
    
    if (args.size >= 2) {
        documentRoot = args[1]
    }
    
    // 检查文档根目录
    val docPath = Paths.get(documentRoot)
    if (!Files.exists(docPath) || !Files.isDirectory(docPath)) {
        println("文档根目录不存在: $documentRoot")
        exitProcess(1)
    }
    
    try {
        // 创建并启动服务器
        val server = HttpServer(port, documentRoot)
        server.start()
    } catch (e: Exception) {
        println("启动服务器失败: ${e.message}")
        exitProcess(1)
    }
}