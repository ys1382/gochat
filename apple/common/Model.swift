import Foundation
import Starscream

class Model {

    static let shared = Model()

    var username: String?
    var roster = [String:Contact]()
    var texts = [Haber]()
    var unreads = [String:Int]()
    var watching: String? {
        didSet {
            if let watching = watching {
                self.unreads[watching] = 0
            }
        }
    }

    func didReceivePresence(_ haber: Haber) {
        for contact in haber.contacts {
            self.roster[contact.name] = contact
        }
        self.post(about:.presence)
    }

    func didReceiveText(_ haber: Haber) {
        let from = haber.from
        if haber.from != self.watching {
            self.unreads[from] = (self.unreads[from] ?? 0) + 1
        }
        self.texts.append(haber)
        self.post(about:.text)
    }

    func didReceiveRoster(_ contacts: [Contact]) {
        self.roster = contacts.reduce([String: Contact]()) { (dict, contact) -> [String: Contact] in
            var dict = dict
            dict[contact.name] = contact
            return dict
        }
        self.post(about:.contacts)
    }

    func addListener(about:Haber.Which, didReceive:@escaping (Notification)->Void) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: about.toString()),
                                               object: nil,
                                               queue: nil,
                                               using: didReceive)
    }

    private func post(about:Haber.Which) {
        NotificationCenter.default.post(name:Notification.Name(rawValue:about.toString()),
                                        object: nil,
                                        userInfo:nil)
    }

    func setContacts(_ names: [String]) {
        var update = [String:Contact]()
        for name in names {
            if let existing = self.roster[name] {
                update[name] = existing
            } else {
                update[name] = try? Contact.Builder().setName(name).build()
            }
        }
        self.roster = update
        Backend.shared.sendContacts(self.roster)
    }
    
    private init() {}
}
