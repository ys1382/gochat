import Foundation
import Starscream

class Model {

    static let shared = Model()

    var username: String?
    var roster = [String:Contact]()
    var texts = [String:[Haber]]()

    func didReceivePresence(_ haber: Haber) {
        self.roster[haber.presence.name] = haber.presence
        self.post(about:.presence, with:haber as AnyObject)
    }

    func didReceiveText(_ haber: Haber) {
        if self.texts[haber.from] == nil {
            self.texts[haber.from] = []
        }
        self.texts[haber.from]?.append(haber)
        self.post(about:.text, with:haber as AnyObject)
    }

    func didReceiveRoster(_ contacts: [Contact]) {
        self.roster = contacts.reduce([String: Contact]()) { (dict, contact) -> [String: Contact] in
            var dict = dict
            dict[contact.name] = contact
            return dict
        }
        self.post(about:.roster, with:self.roster as AnyObject)
    }

    func addListener(about:Haber.Which, didReceive:@escaping (Notification)->Void) {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: about.toString()),
                                               object: nil,
                                               queue: nil,
                                               using: didReceive)
    }

    func post(about:Haber.Which, with info:AnyObject) {
        NotificationCenter.default.post(name:Notification.Name(rawValue:about.toString()),
                                        object: nil,
                                        userInfo:[about:info])
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
