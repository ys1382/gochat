
import AudioToolbox

class NetworkAudioSessionInfo : NetworkIOSessionInfo {
    let format: AudioFormat.Factory?
    
    init(_ id: IOID, _ format: @escaping AudioFormat.Factory) {
        self.format = format
        super.init(id, data(format))
    }

    override init(_ id: IOID) {
        format = nil
        super.init(id)
    }

    override init(_ id: IOID, _ format: NSData.Factory?) {
        if format != nil {
            self.format = audioFormat(format!)
        }
        else {
            self.format = nil
        }
        super.init(id, format)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkAudioSerializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkAudioSerializer : AudioOutputProtocol, IOQoSProtocol {
 
    private let output: IODataProtocol?
    private var qid: String = ""

    init(_ output: IODataProtocol?) {
        self.output = output
    }
    
    func change(_ toQID: String, _ diff: Int) {
        self.qid = toQID
    }

    func process(_ packet: AudioData) {
    
        let s = PacketSerializer()
        var t = AudioTime(packet.time)
        
        s.push(&t, MemoryLayout<AudioTime>.size)
        s.push(string: qid)
        s.push(packet.data.bytes, packet.data.length)
        s.push(array: packet.desc)
        
        output?.process(s.data)
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
    
    func process(_ data: NSData) {
        
        let deserializer = PacketDeserializer(data)
        var time = AudioTime()
        var data: NSData?
        var desc: [AudioStreamPacketDescription]?
        
        deserializer.pop(&time)
        _ = deserializer.popSkip()
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
        return try JSONSerialization.data(withJSONObject: format.data,
                                          options: JSONSerialization.defaultWritingOptions) as NSData
    }
    
    static func fromNetwork(_ data: NSData) throws -> AudioFormat {
        let json = try JSONSerialization.jsonObject(with: data as Data,
                                                    options: JSONSerialization.ReadingOptions()) as! [String: Any]
        return AudioFormat(IOFormat(json))
    }
}

func data(_ src: @escaping AudioFormat.Factory) -> NSData.Factory {
    return { return try src().toNetwork() }
}

func audioFormat(_ src: @escaping NSData.Factory) -> AudioFormat.Factory {
    return { return try AudioFormat.fromNetwork(src()) }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputAudio
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputAudio : NetworkOutput {
    
    override func process(_ dataID: UUID, _ data: NSData) {
        
        VoipBackend.sendAudio(id, data) {
            self.processed(dataID)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputAudioSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputAudioSession : IOSessionProtocol {
    
    let info: NetworkAudioSessionInfo
    
    init(_ info: NetworkAudioSessionInfo) {
        self.info = info
    }
    
    func start() throws {
        //Backend.shared.sendAudioSession(info, true)
        VoipBackend.sendAudioSession(info, true)
    }
    
    func stop() {
        //Backend.shared.sendAudioSession(info, false)
        VoipBackend.sendAudioSession(info, false)
    }
}
