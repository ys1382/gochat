
import AVFoundation

class NetworkVideoSessionInfo : NetworkIOSessionInfo {
    let format: VideoFormat.Factory?
    
    init(_ id: IOID, _ format: @escaping VideoFormat.Factory) {
        self.format = format
        super.init(id, data(format))
    }

    override init(_ id: IOID) {
        format = nil
        super.init(id)
    }
    
    override init(_ id: IOID, _ format: NSData.Factory?) {
        if format != nil {
            self.format = videoFormat(format!)
        }
        else  {
            self.format = nil
        }
        super.init(id, format)
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkH264Serializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkH264Serializer : VideoOutputProtocol, IOQoSProtocol {
    
    private let output: IODataProtocol?
    private var qid: String = ""
    
    init(_ output: IODataProtocol) {
        
        self.output = output
    }
    
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // IOQoSProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func change(_ toQID: String, _ diff: Int) {
        self.qid = toQID
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // VideoOutputProtocol
    ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    func process(_ sampleBuffer: CMSampleBuffer) {
        do {
            let formatDescription: CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!
            
            assert(CMSampleBufferGetNumSamples(sampleBuffer) == 1)
            
            // timing info
            
            var timingInfo = CMSampleTimingInfo()
            
            try checkStatus(CMSampleBufferGetSampleTimingInfo(sampleBuffer,
                                                              0,
                                                              &timingInfo),
                            "CMSampleBufferGetSampleTimingInfo failed")
            
            // H264 description (SPS)
            
            var sps: UnsafePointer<UInt8>?
            var spsLength: Int = 0
            var count: Int = 0
            
            try checkStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                               0,
                                                                               &sps,
                                                                               &spsLength,
                                                                               &count,
                                                                               nil),
                            "An Error occured while getting h264 sps parameter")
            
            assert(count == 2) // sps and pps
            
            // H264 description (PPS)
            
            var pps: UnsafePointer<UInt8>?
            var ppsLength: Int = 0
            
            try checkStatus(CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDescription,
                                                                               1,
                                                                               &pps,
                                                                               &ppsLength,
                                                                               &count,
                                                                               nil),
                            "An Error occured while getting h264 pps parameter")
            
            assert(count == 2) // sps and pps
            
            // H264 data
            
            let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)
            var totalLength = Int()
            var length = Int()
            var dataPointer: UnsafeMutablePointer<Int8>? = nil
            
            try checkStatus(CMBlockBufferGetDataPointer(blockBuffer!,
                                                        0,
                                                        &length,
                                                        &totalLength,
                                                        &dataPointer), "CMBlockBufferGetDataPointer failed")
            
            assert(length == totalLength)
            
            // build data
            
            let s = PacketSerializer()
            
            s.push(data: VideoTime(timingInfo).ToNSData())
            s.push(string: qid)
            s.push(data: NSData(bytes: sps!, length: spsLength))
            s.push(data: NSData(bytes: pps!, length: ppsLength))
            s.push(data: NSData(bytes: dataPointer!, length: Int(totalLength)))
            
            // output
            
            AV.shared.videoCaptureQueue.async { self.output?.process(s.data) }
        }
        catch {
            logIOError(error)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkH264Deserializer
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkH264Deserializer : IODataProtocol, IOBalancedDataProtocol {
    
    private let output: VideoOutputProtocol?
    
    init(_ output: VideoOutputProtocol?) {
        self.output = output
    }
    
    func tuning(_ data: NSData) {
        process(data)
    }
    
    func belated(_ data: NSData) {
        process(data)
    }
    
    func process(_ data: NSData) {
        
        let d = PacketDeserializer(data)
        
        let h264Time = d.popData()
        _ = d.popSkip() // QoS ID
        let h264SPS  = d.popData()
        let h264PPS  = d.popData()
        let h264Data = d.popData()
        
        do {
            // format description
            
            var formatDescription: CMFormatDescription?
            
            let parameterSetPointers : [UnsafePointer<UInt8>] = [h264SPS.bytes.assumingMemoryBound(to: UInt8.self),
                                                                 h264PPS.bytes.assumingMemoryBound(to: UInt8.self)]
            let parameterSetSizes : [Int] = [h264SPS.length,
                                             h264PPS.length]
            
            try checkStatus(CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                                2,
                                                                                parameterSetPointers,
                                                                                parameterSetSizes,
                                                                                4,
                                                                                &formatDescription),
                            "CMVideoFormatDescriptionCreateFromH264ParameterSets failed")
            
            // block buffer
            
            var blockBuffer: CMBlockBuffer?
            let blockBufferData = UnsafeMutablePointer<Int8>.allocate(capacity: h264Data.length)
            blockBufferData.assign(from: h264Data.bytes.assumingMemoryBound(to: Int8.self), count: h264Data.length)
            
            try checkStatus(CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                               blockBufferData,
                                                               h264Data.length,
                                                               kCFAllocatorDefault,
                                                               nil,
                                                               0,
                                                               h264Data.length,
                                                               0,
                                                               &blockBuffer), "createReadonlyBlockBuffer")
            
            // timing info
            
            var timingInfo = VideoTime(deserialize: h264Time).ToCMSampleTimingInfo()
            
            // sample buffer
            
            var sampleBuffer : CMSampleBuffer?
            try checkStatus(CMSampleBufferCreateReady(kCFAllocatorDefault,
                                                      blockBuffer,
                                                      formatDescription,
                                                      1,
                                                      1,
                                                      &timingInfo,
                                                      0,
                                                      nil,
                                                      &sampleBuffer), "CMSampleBufferCreateReady failed")
            
            // output
            
            output?.process(sampleBuffer!)
        }
        catch {
            logIOError(error)
        }
    }
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Video format
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

extension VideoFormat {
    
    func toNetwork() throws -> NSData {
        return try JSONSerialization.data(withJSONObject: format.data,
                                          options: JSONSerialization.defaultWritingOptions) as NSData
    }

    static func fromNetwork(_ data: NSData) throws -> VideoFormat {
        let json = try JSONSerialization.jsonObject(with: data as Data,
                                                    options: JSONSerialization.ReadingOptions()) as! [String: Any]
        return VideoFormat(IOFormat(json))
    }
}

func data(_ src: @escaping VideoFormat.Factory) -> NSData.Factory {
    return { return try src().toNetwork() }
}

func videoFormat(_ src: @escaping NSData.Factory) -> VideoFormat.Factory {
    return { return try VideoFormat.fromNetwork(src()) }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputVideo
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputVideo : NetworkOutput {
    
    override func process(_ dataID: UUID, _ data: NSData) {
        Backend.shared.sendVideo(id, data) {
            self.processed(dataID)
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// NetworkOutputVideoSession
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

class NetworkOutputVideoSession : VideoSessionProtocol {
    
    let id: IOID
    let format: VideoFormat
    
    init(_ id: IOID, _ format: VideoFormat) {
        self.id = id
        self.format = format
    }
    
    func start() throws {
        Backend.shared.sendVideoSession(NetworkVideoSessionInfo(id, factory(format)), true)
    }
    
    func update(_ format: VideoFormat) throws {
        // TODO: send update format
    }
    
    func stop() {
        Backend.shared.sendVideoSession(NetworkVideoSessionInfo(id), false)
    }
}

