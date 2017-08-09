
import Foundation

class NetworkIOSessionInfo {
    let id: IOID
    let formatData: NSData.Factory?

    init(_ id: IOID) {
        self.id = id
        formatData = nil
    }
    
    init(_ id: IOID, _ format: NSData.Factory?) {
        self.id = id
        self.formatData = format
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Logs
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func logNetwork(_ message: String) {
    logMessage("Network", message)
}

func logNetworkPrior(_ message: String) {
    logPrior("Network", message)
}

func logNetworkError(_ message: String) {
    logError("Network", message)
}

func logNetworkError(_ error: Error) {
    logError("Network", error)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Serialization
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkDeserializer {
    
    static let timeIndex = 0
    static let qosIDIndex = 1
    static let dataIndex = 2
    
    private let _data: NSData
    
    init(_ data: NSData) {
        self._data = data
    }
    
    var time: PacketDeserializer {
        get {
            return PacketDeserializer(_data, NetworkDeserializer.timeIndex)
        }
    }

    var qosID: PacketDeserializer {
        get {
            return PacketDeserializer(_data, NetworkDeserializer.qosIDIndex)
        }
    }

    var data: PacketDeserializer {
        get {
            return PacketDeserializer(_data, NetworkDeserializer.dataIndex)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkInput
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkInput {
    
    private var output = [String: IODataProtocol]()
    
    func add(_ sid: String, _ output: IODataProtocol) {
        self.output[sid] = output
    }
    
    func remove(_ sid: String) {
        output.removeValue(forKey: sid)
    }
    
    func removeAll() {
        self.output.removeAll()
    }
    
    func process(_ sid: String, _ data: NSData) {
        guard output.keys.contains(sid) else { return }
        output[sid]?.process(data)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutput
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutput : IODataProtocol {
    
    struct _Item {
        let time: Double
        let qosID: String
    }
    
    let id: IOID
    
    private let qos: IOQoS
    private let balancer: IOQoSBalancerProtocol
    private var queue = [UUID: _Item]()
    
    init(_ id: IOID, _ qos: IOQoS, _ balancer: IOQoSBalancerProtocol) {
        self.id = id
        self.qos = qos
        self.balancer = balancer
    }
    
    func process(_ dataID: UUID, _ data: NSData) {
        
    }
    
    func process(_ data: NSData) {
        let dataID = UUID()
        
        queue[dataID] = _Item(time: mach_absolute_seconds(),
                              qosID: NetworkDeserializer(data).qosID.popString())
        
        process(dataID, data)
    }
    
    func processed(_ id: UUID) {
        let item = queue[id]!
        let gap = mach_absolute_seconds() - item.time
        
        balancer.process(item.qosID, gap)
        queue.removeValue(forKey: id)
    }
}
