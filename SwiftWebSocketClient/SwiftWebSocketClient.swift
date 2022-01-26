//
//  SwiftWebSocketClient.swift
//  SwiftWebSocketClient
//
//  Created by Jayesh Kawli on 1/25/22.
//

import Foundation

final class SwiftWebSocketClient: NSObject {
        
    static let shared = SwiftWebSocketClient()
    var webSocket: URLSessionWebSocketTask?
    
    var opened = false
    
    private var urlString = "ws://localhost:8080"
    
    var connectionId = -1
    
    private override init() {
        // no-op
    }
    
    func subscribeToService(with completion: @escaping (String?) -> Void) {
        if !opened {
            openWebSocket()
        }
        
        guard let webSocket = webSocket else {
            completion(nil)
            return
        }
        
        webSocket.receive(completionHandler: { [weak self] result in
            
            guard let self = self else { return }
            
            switch result {
            case .failure(let error):
                completion(nil)
            case .success(let webSocketTaskMessage):
                switch webSocketTaskMessage {
                case .string:
                    completion(nil)
                case .data(let data):
                    if let messageType = self.getMessageType(from: data) {
                        switch(messageType) {
                        case .connected:
                            self.subscribeToServer(completion: completion)
                        case .failed:
                            self.opened = false
                            completion(nil)
                        case .tradingQuote:
                            if let currentQuote = self.getCurrentQuoteResponseData(from: data) {
                                completion(currentQuote.body.currentPrice)
                            } else {
                                completion(nil)
                            }
                        case .connectionAck:
                            let ack = try! JSONDecoder().decode(ConnectionAck.self, from: data)
                            self.connectionId = ack.connectionId
                        }
                    }
                    
                    self.subscribeToService(with: completion)
                default:
                    fatalError("Failed. Received unknown data format. Expected String")
                }
            }
        })
    }
    
    func getMessageType(from jsonData: Data) -> MessageType? {
        if let messageType = (try? JSONDecoder().decode(GenericSocketResponse.self, from: jsonData))?.t {
            return MessageType(rawValue: messageType)
        }
        return nil
    }

    func getCurrentQuoteResponseData(from jsonData: Data) -> SocketQuoteResponse? {
        do {
            return try JSONDecoder().decode(SocketQuoteResponse.self, from: jsonData)
        } catch {
            return nil
        }
    }

    func subscriptionPayload(for productID: String) -> String? {
        let payload = ["subscribeTo": "trading.product.\(productID)"]
        if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
            return String(data: jsonData, encoding: .utf8)
        }
        return nil
    }

    private func subscribeToServer(completion: @escaping (String?) -> Void) {
        
        guard let webSocket = webSocket else {
            return
        }
        
        if let subscriptionPayload = self.subscriptionPayload(for: "100") {
            webSocket.send(URLSessionWebSocketTask.Message.string(subscriptionPayload)) { error in
                if let error = error {
                    print("Failed with Error \(error.localizedDescription)")
                }
            }
        } else {
            completion(nil)
        }
    }
    
    private func openWebSocket() {
        if let url = URL(string: urlString) {
            let request = URLRequest(url: url)
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            let webSocket = session.webSocketTask(with: request)
            self.webSocket = webSocket
            self.opened = true
            self.webSocket?.resume()
        } else {
            webSocket = nil
        }
    }
    
    func closeSocket() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        opened = false
        webSocket = nil
    }
}

extension SwiftWebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        opened = true
    }

    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.webSocket = nil
        self.opened = false
    }
}

struct SocketQuoteResponse: Decodable {
    let t: String
    let body: QuoteResponseBody
}

struct QuoteResponseBody: Decodable {
    let securityId: String
    let currentPrice: String
}

struct ConnectionAck: Decodable {
    let t: String
    let connectionId: Int
}

struct GenericSocketResponse: Decodable {
    let t: String
}

enum MessageType: String {
    case connected = "connect.connected"
    case failed =  "connect.failed"
    case tradingQuote = "trading.quote"
    case connectionAck = "connect.ack"
}
