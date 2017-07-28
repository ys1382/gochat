import Foundation

class EventBus {

    enum Event: String {
        case connected
        case disconnected
        case authenticated
        case contacts
        case presence
        case text
        case texts
    }

    static func post(about: Wire.Which) {
        guard let event = Event(rawValue: about.toString().lowercased()) else {
            print("no event for " + about.toString())
            return
        }
        post(event)
    }

    static func post(_ key: Event) {
        NotificationCenter.default.post(name:Notification.Name(rawValue:key.rawValue), object: nil, userInfo:nil)
    }

    static func post(forKey key: String) {
        NotificationCenter.default.post(name:Notification.Name(rawValue:key), object: nil, userInfo:nil)
    }

    static func addListener(about:Event, didReceive:@escaping (Notification)->Void) {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: about.rawValue),
            object: nil,
            queue: nil,
            using: didReceive)
    }
}
