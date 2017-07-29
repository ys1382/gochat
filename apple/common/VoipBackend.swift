import Foundation

// todo: add file, AV
class VoipBackend {

    static func sendText(_ body: String, peerId: String) {
        do {
            let data = try Voip.Builder().setWhich(.text).setPayload(body.data(using: .utf8)!).build().data()
            WireBackend.shared.send(data: data, peerId: peerId)
        } catch {
            print(error.localizedDescription)
        }
    }

    static func didReceiveFromPeer(_ data: Data, from peerId: String) {
        guard let voip = try? Voip.parseFrom(data:data) else {
            print("Could not deserialize voip")
            return
        }

        print("read \(data.count) bytes for \(voip.which) from \(peerId)")
        switch voip.which {
            case        .text: Model.shared.didReceiveText(voip.payload, from: peerId)
            default:    print("did not handle \(voip.which)")
        }
    }
}
