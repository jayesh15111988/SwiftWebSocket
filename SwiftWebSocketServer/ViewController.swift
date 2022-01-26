//
//  ViewController.swift
//  SwiftWebSocketServer
//
//  Created by Jayesh Kawli on 1/25/22.
//

import Cocoa

class ViewController: NSViewController {
    @IBOutlet weak var outputLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let server = SwiftWebSocketServer(port: 8080)
        server.startServer()
        // To check if the connection is established at port 8080, run
        // sudo lsof -i :8080 from command line to verify connection on given port
        server.completion = { value in
            DispatchQueue.main.async {
                self.outputLabel.stringValue = value
            }
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

