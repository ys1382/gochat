
import AudioToolbox

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkAudioSerializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkAudioSerializer : AudioOutputProtocol {
 
    private let output: IODataProtocol?
    
    init(_ output: IODataProtocol?) {
        self.output = output
    }
    
    func process(_ packet: AudioData) {
    
        let s = PacketSerializer()
        var t = AudioTime(packet.time)
        
        s.push(&t, MemoryLayout<AudioTime>.size)
        s.push(packet.data.bytes, packet.data.length)
        s.push(array: packet.desc)
        
        output?.process([AudioPart.NetworkPacket.rawValue: s.data])
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkAudioDeserializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkAudioDeserializer : IODataProtocol {
    
    private let output: AudioOutputProtocol?
    
    init(_ output: AudioOutputProtocol) {
        self.output = output
    }
    
    func process(_ packets: [Int: NSData]) {
        
        let deserializer = PacketDeserializer(packets[AudioPart.NetworkPacket.rawValue]!)
        var time = AudioTime()
        var data: NSData?
        var desc: [AudioStreamPacketDescription]?
        
        deserializer.pop(&time)
        deserializer.pop(data: &data)
        deserializer.pop(array: &desc)

        output?.process(AudioData(time.ToAudioTimeStamp(), data!, desc))
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Audio format
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension AudioFormat {
    
    func toNetwork() throws -> NSData {
        return try JSONSerialization.data(withJSONObject: data,
                                          options: JSONSerialization.defaultWritingOptions) as NSData
    }
    
    static func fromNetwork(_ data: NSData) throws -> AudioFormat {
        let json = try JSONSerialization.jsonObject(with: data as Data,
                                                    options: JSONSerialization.ReadingOptions()) as! [String: Any]
        return AudioFormat(json)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputAudio
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputAudio : IODataProtocol {
    
    let id: IOID
    
    init(_ id: IOID) {
        self.id = id
    }
    
    func process(_ data: [Int: NSData]) {
        Backend.shared.sendAudio(id, data[AudioPart.NetworkPacket.rawValue]!)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputAudioSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputAudioSession : IOSessionProtocol {
    
    let id: IOID
    let format: AudioFormat.Factory
    
    init(_ id: IOID, _ format: @escaping AudioFormat.Factory) {
        self.id = id
        self.format = format
    }
    
    func start() throws {
        Backend.shared.sendAudioSession(id, try format().toNetwork(), true)
    }
    
    func stop() {
        Backend.shared.sendAudioSession(id, nil, false)
    }
}
