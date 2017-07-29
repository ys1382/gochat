import Foundation
import Starscream

class Network: WebSocketDelegate {

    static let address = "ws://10.17.7.91:8000/ws"

    static let shared = Network()

    private var websocket: WebSocket?

    func connect() {
        guard let url = URL(string: Network.address) else {
            print("could not create url from " + Network.address)
            return
        }
        websocket = WebSocket(url: url)
        websocket?.delegate = self
        websocket?.connect()
    }

    func send(_ data: Data) {
        websocket?.write(data: data)
    }

    // websocket delegate

    func websocketDidConnect(_ websocket: Starscream.WebSocket) {
        EventBus.post(.connected)
    }

    func websocketDidDisconnect(_ websocket: Starscream.WebSocket, error: NSError?) {
        EventBus.post(.disconnected)
    }

    func websocketDidReceiveData(_ websocket: Starscream.WebSocket, data: Data) {
        WireBackend.shared.didReceiveFromServer(data)
    }

    func websocketDidReceiveMessage(_ socket: WebSocket, text: String) {
        print("websocketDidReceiveMessage")
    }
}
