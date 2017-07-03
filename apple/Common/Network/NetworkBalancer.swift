
import Foundation

class NetworkBalancer : IOQoSBalancerProtocol {

    private static let kGapCount = 3 // number packets for tuning
    private static let kGapMax = 1.5
    
    private var qid: String?
    private var qidObsolete: Bool = true
    
    var gaps = [Double]()
    
    func process(_ qosID: String, _ gap: Double) {
        _update(qosID, gap)
    }

    fileprivate func change(_ diff: Int) {
        
    }

    private func _update(_ qosID: String, _ gap: Double) {
        
        if qidObsolete && self.qid != qosID {
            self.qid = qosID
            qidObsolete = false
        }
        
        _update(gap)
    }

    private func _update(_ gap: Double) {
        gaps.append(gap)
        
        if gaps.count > NetworkBalancer.kGapCount {
            gaps.removeFirst()
        }
        else {
            return
        }
        
        for i in gaps {
            if i < NetworkBalancer.kGapMax {
                return
            }
        }
        
        if qidObsolete == false {
            qidObsolete = true
            change(IOQoS.kDecrease)
        }
    }
}

class NetworkCallQuality : NetworkBalancer {
    
    let to: String
    let call: NetworkCallInfo
    
    init(_ to: String, _ call: NetworkCallInfo) {
        self.to = to
        self.call = call
    }
    
    override func change(_ diff: Int) {
        changeCallQuality(call, diff)
    }
}
