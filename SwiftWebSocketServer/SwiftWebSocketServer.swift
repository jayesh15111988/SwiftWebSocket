//
//  SwiftWebSocketServer.swift
//  SwiftWebSocketServer
//
//  Created by Jayesh Kawli on 1/25/22.
//

import Foundation
import Network
import AppKit

class SwiftWebSocketServer {
    var listener: NWListener
    var connectedClients: [NWConnection] = []
    var timer: Timer?
    var completion: ((String) -> Void)?
    
    init(port: UInt16) {
        
        let parameters = NWParameters(tls: nil)
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true
        
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        
        parameters.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        do {
            if let port = NWEndpoint.Port(rawValue: port) {
                listener = try NWListener(using: parameters, on: port)
            } else {
                fatalError("Unable to start WebSocket server on port \(port)")
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func startServer() {
                            
            let serverQueue = DispatchQueue(label: "ServerQueue")
            
            listener.newConnectionHandler = { newConnection in
                print("New connection connecting")
                
                func receive() {
                    newConnection.receiveMessage { (data, context, isComplete, error) in
                        if let data = data, let context = context {
                            print("Received a new message from client")
                            try! self.handleMessageFromClient(data: data, context: context, stringVal: "", connection: newConnection)
                            receive()
                        }
                    }
                }
                receive()
                
                newConnection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        print("Client ready")
                        try! self.sendMessageToClient(data: JSONEncoder().encode(["t": "connect.connected"]), client: newConnection)
                    case .failed(let error):
                        print("Client connection failed \(error.localizedDescription)")
                    case .waiting(let error):
                        print("Waiting for long time \(error.localizedDescription)")
                    default:
                        break
                    }
                }

                newConnection.start(queue: serverQueue)
            }
            
            listener.stateUpdateHandler = { state in
                print(state)
                switch state {
                case .ready:
                    print("Server Ready")
                case .failed(let error):
                    print("Server failed with \(error.localizedDescription)")
                default:
                    break
                }
            }
            
            listener.start(queue: serverQueue)
            startTimer()
        }
          
        func startTimer() {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { timer in
                
                guard !self.connectedClients.isEmpty else {
                    return
                }
                
                self.sendMessageToAllClients()
                
            })
            timer?.fire()
        }
        
        func sendMessageToAllClients() {
            let data = getTradingQuoteData()
            for (index, client) in self.connectedClients.enumerated() {
                print("Sending message to client number \(index)")
                try! self.sendMessageToClient(data: data, client: client)
            }
        }
        
        func sendMessageToClient(data: Data, client: NWConnection) throws {
            let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
            let context = NWConnection.ContentContext(identifier: "context", metadata: [metadata])
            
            client.send(content: data, contentContext: context, isComplete: true, completion: .contentProcessed({ error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    // no-op
                }
            }))
        }
        
        func getTradingQuoteData() -> Data {
            let outputValue = String(Int.random(in: 1...1000))
            completion?("Server Sending \(outputValue)")
            let data = SocketQuoteResponse(t: "trading.quote", body: QuoteResponseBody(securityId: "100", currentPrice: outputValue))
            return try! JSONEncoder().encode(data)
        }
    
        func handleMessageFromClient(data: Data, context: NWConnection.ContentContext, stringVal: String, connection: NWConnection) throws {
            
            if let message = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if message["subscribeTo"] != nil {
                        
                    print("Appending new connection to connectedClients")
                    
                    self.connectedClients.append(connection)
                    
                    self.sendAckToClient(connection: connection)
                    let tradingQuoteData = self.getTradingQuoteData()
                    try! self.sendMessageToClient(data: tradingQuoteData, client: connection)

                } else if message["unsubscribeFrom"] != nil {
                    
                    print("Removing old connection from connectedClients")
                    
                    if let id = message["unsubscribeFrom"] as? Int {
                        let connection = self.connectedClients.remove(at: id)
                        connection.cancel()
                        print("Cancelled old connection with id \(id)")
                    } else {
                        print("Invalid Payload")
                    }
                }
            } else {
                print("Invalid value from client")
            }
            
        }
    
        func sendAckToClient(connection: NWConnection) {
            let model = ConnectionAck(t: "connect.ack", connectionId: self.connectedClients.count - 1)
            let data = try! JSONEncoder().encode(model)
            
            try! self.sendMessageToClient(data: data, client: connection)
        }
}

struct SocketQuoteResponse: Encodable {
    let t: String
    let body: QuoteResponseBody
}

struct QuoteResponseBody: Encodable {
    let securityId: String
    let currentPrice: String
}

struct ConnectionAck: Encodable {
    let t: String
    let connectionId: Int
}

