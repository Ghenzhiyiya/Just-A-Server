#include <iostream>
#include <string>
#include <map>
#include <vector>
#include <fstream>
#include <sstream>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <queue>
#include <functional>
#include <filesystem>
#include <cstring>
#include <csignal>

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "ws2_32.lib")
    typedef int socklen_t;
#else
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <unistd.h>
    #define SOCKET int
    #define INVALID_SOCKET -1
    #define SOCKET_ERROR -1
    #define closesocket close
#endif

/**
 * 从底层实现的HTTP服务器 - C++版本
 * 纯AI生成，用于学习HTTP协议底层原理
 */

class ThreadPool {
public:
    ThreadPool(size_t numThreads) : stop(false) {
        for (size_t i = 0; i < numThreads; ++i) {
            workers.emplace_back([this] {
                for (;;) {
                    std::function<void()> task;
                    {
                        std::unique_lock<std::mutex> lock(queueMutex);
                        condition.wait(lock, [this] { return stop || !tasks.empty(); });
                        if (stop && tasks.empty()) return;
                        task = std::move(tasks.front());
                        tasks.pop();
                    }
                    task();
                }
            });
        }
    }

    template<class F>
    void enqueue(F&& f) {
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            if (stop) return;
            tasks.emplace(std::forward<F>(f));
        }
        condition.notify_one();
    }

    ~ThreadPool() {
        {
            std::unique_lock<std::mutex> lock(queueMutex);
            stop = true;
        }
        condition.notify_all();
        for (std::thread &worker : workers) {
            worker.join();
        }
    }

private:
    std::vector<std::thread> workers;
    std::queue<std::function<void()>> tasks;
    std::mutex queueMutex;
    std::condition_variable condition;
    bool stop;
};

struct HttpRequest {
    std::string method;
    std::string path;
    std::string version;
    std::map<std::string, std::string> headers;
};

class HttpServerCpp {
private:
    int port;
    std::string documentRoot;
    SOCKET serverSocket;
    ThreadPool threadPool;
    volatile bool running;

    void initializeWinsock() {
#ifdef _WIN32
        WSADATA wsaData;
        int result = WSAStartup(MAKEWORD(2, 2), &wsaData);
        if (result != 0) {
            throw std::runtime_error("WSAStartup failed: " + std::to_string(result));
        }
#endif
    }

    void cleanupWinsock() {
#ifdef _WIN32
        WSACleanup();
#endif
    }

    HttpRequest parseRequest(const std::string& requestData) {
        HttpRequest request;
        std::istringstream stream(requestData);
        std::string line;
        
        // 解析请求行
        if (std::getline(stream, line)) {
            // 移除回车符
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            
            std::istringstream lineStream(line);
            lineStream >> request.method >> request.path >> request.version;
        }
        
        // 解析请求头
        while (std::getline(stream, line)) {
            if (!line.empty() && line.back() == '\r') {
                line.pop_back();
            }
            
            if (line.empty()) break;
            
            size_t colonPos = line.find(':');
            if (colonPos != std::string::npos) {
                std::string headerName = line.substr(0, colonPos);
                std::string headerValue = line.substr(colonPos + 1);
                
                // 去除前后空格
                headerName.erase(0, headerName.find_first_not_of(" \t"));
                headerName.erase(headerName.find_last_not_of(" \t") + 1);
                headerValue.erase(0, headerValue.find_first_not_of(" \t"));
                headerValue.erase(headerValue.find_last_not_of(" \t") + 1);
                
                // 转换为小写
                std::transform(headerName.begin(), headerName.end(), headerName.begin(), ::tolower);
                request.headers[headerName] = headerValue;
            }
        }
        
        return request;
    }

    std::string getContentType(const std::string& filePath) {
        if (filePath.ends_with(".html") || filePath.ends_with(".htm")) {
            return "text/html";
        } else if (filePath.ends_with(".css")) {
            return "text/css";
        } else if (filePath.ends_with(".js")) {
            return "application/javascript";
        } else if (filePath.ends_with(".png")) {
            return "image/png";
        } else if (filePath.ends_with(".jpg") || filePath.ends_with(".jpeg")) {
            return "image/jpeg";
        } else {
            return "text/plain";
        }
    }

    void sendResponse(SOCKET clientSocket, int statusCode, const std::string& statusText,
                     const std::string& contentType, const std::vector<char>& content) {
        std::ostringstream response;
        
        // HTTP状态行
        response << "HTTP/1.1 " << statusCode << " " << statusText << "\r\n";
        
        // HTTP响应头
        response << "Content-Type: " << contentType << "\r\n";
        response << "Content-Length: " << content.size() << "\r\n";
        response << "Connection: close\r\n";
        response << "Server: HttpServerCpp/1.0\r\n";
        response << "\r\n"; // 空行分隔头部和正文
        
        std::string header = response.str();
        
        // 发送响应头
        send(clientSocket, header.c_str(), header.length(), 0);
        
        // 发送响应正文
        if (!content.empty()) {
            send(clientSocket, content.data(), content.size(), 0);
        }
    }

    void sendErrorResponse(SOCKET clientSocket, int statusCode, const std::string& statusText) {
        std::string errorHtml = "<html><body><h1>" + std::to_string(statusCode) + " " + statusText + "</h1></body></html>";
        std::vector<char> content(errorHtml.begin(), errorHtml.end());
        sendResponse(clientSocket, statusCode, statusText, "text/html", content);
    }

    void handleRequest(const HttpRequest& request, SOCKET clientSocket) {
        if (request.method != "GET") {
            sendErrorResponse(clientSocket, 405, "Method Not Allowed");
            return;
        }

        std::string filePath = request.path;
        if (filePath == "/") {
            filePath = "/index.html";
        }

        std::filesystem::path fullPath = std::filesystem::path(documentRoot) / filePath.substr(1);
        
        if (!std::filesystem::exists(fullPath) || std::filesystem::is_directory(fullPath)) {
            sendErrorResponse(clientSocket, 404, "Not Found");
            return;
        }

        try {
            std::ifstream file(fullPath, std::ios::binary);
            if (!file) {
                sendErrorResponse(clientSocket, 500, "Internal Server Error");
                return;
            }

            std::vector<char> content((std::istreambuf_iterator<char>(file)),
                                    std::istreambuf_iterator<char>());
            
            std::string contentType = getContentType(fullPath.string());
            sendResponse(clientSocket, 200, "OK", contentType, content);
        } catch (const std::exception& e) {
            sendErrorResponse(clientSocket, 500, "Internal Server Error");
        }
    }

    void handleClient(SOCKET clientSocket) {
        char buffer[4096];
        int bytesReceived = recv(clientSocket, buffer, sizeof(buffer) - 1, 0);
        
        if (bytesReceived > 0) {
            buffer[bytesReceived] = '\0';
            std::string requestData(buffer);
            
            HttpRequest request = parseRequest(requestData);
            
            if (!request.method.empty()) {
                std::cout << "收到请求: " << request.method << " " << request.path << std::endl;
                handleRequest(request, clientSocket);
            } else {
                sendErrorResponse(clientSocket, 400, "Bad Request");
            }
        }
        
        closesocket(clientSocket);
    }

public:
    HttpServerCpp(int port, const std::string& documentRoot) 
        : port(port), documentRoot(documentRoot), threadPool(10), running(false) {
        initializeWinsock();
    }

    ~HttpServerCpp() {
        stop();
        cleanupWinsock();
    }

    void start() {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0);
        if (serverSocket == INVALID_SOCKET) {
            throw std::runtime_error("创建socket失败");
        }

        // 设置socket选项
        int opt = 1;
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, (char*)&opt, sizeof(opt));

        sockaddr_in serverAddr{};
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(port);

        if (bind(serverSocket, (sockaddr*)&serverAddr, sizeof(serverAddr)) == SOCKET_ERROR) {
            closesocket(serverSocket);
            throw std::runtime_error("绑定端口失败");
        }

        if (listen(serverSocket, 10) == SOCKET_ERROR) {
            closesocket(serverSocket);
            throw std::runtime_error("监听失败");
        }

        running = true;
        std::cout << "HTTP服务器启动在端口: " << port << std::endl;
        std::cout << "文档根目录: " << documentRoot << std::endl;

        while (running) {
            sockaddr_in clientAddr{};
            socklen_t clientAddrLen = sizeof(clientAddr);
            
            SOCKET clientSocket = accept(serverSocket, (sockaddr*)&clientAddr, &clientAddrLen);
            if (clientSocket != INVALID_SOCKET) {
                threadPool.enqueue([this, clientSocket] {
                    handleClient(clientSocket);
                });
            }
        }
    }

    void stop() {
        running = false;
        if (serverSocket != INVALID_SOCKET) {
            closesocket(serverSocket);
            serverSocket = INVALID_SOCKET;
        }
    }
};

// 全局服务器实例用于信号处理
HttpServerCpp* globalServer = nullptr;

void signalHandler(int signal) {
    std::cout << "\n收到信号 " << signal << "，正在关闭服务器..." << std::endl;
    if (globalServer) {
        globalServer->stop();
    }
    exit(0);
}

int main(int argc, char* argv[]) {
    int port = 8080;
    std::string documentRoot = "./Pub";
    
    if (argc >= 2) {
        try {
            port = std::stoi(argv[1]);
        } catch (const std::exception& e) {
            std::cerr << "无效的端口号: " << argv[1] << std::endl;
            return 1;
        }
    }
    
    if (argc >= 3) {
        documentRoot = argv[2];
    }

    try {
        HttpServerCpp server(port, documentRoot);
        globalServer = &server;
        
        // 设置信号处理
        signal(SIGINT, signalHandler);
        signal(SIGTERM, signalHandler);
        
        server.start();
    } catch (const std::exception& e) {
        std::cerr << "服务器错误: " << e.what() << std::endl;
        return 1;
    }

    return 0;
}