import Foundation
import Starscream

class Model {

    static let shared = Model()

    private static let usernameKey = "usernamekey"
    private static let passwordKey = "passwordkey"

//    var username: String?

    struct Credential {
        let username: String
        let password: String
    }
    static var credential: Credential?

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
    var store = [String:Haber]()

    func didReceivePresence(_ haber: Haber) {
        for contact in haber.contacts {
            self.roster[contact.name] = contact
        }
        EventBus.post(about:.presence)
    }

    func didReceiveText(_ haber: Haber) {
        if let from = haber.from, haber.from != self.watching {
            self.unreads[from] = (self.unreads[from] ?? 0) + 1
        }
        self.texts.append(haber)
        EventBus.post(about:.text)
    }

    func didReceiveRoster(_ contacts: [Contact]) {
        self.roster = contacts.reduce([String: Contact]()) { (dict, contact) -> [String: Contact] in
            var dict = dict
            dict[contact.name] = contact
            return dict
        }
        EventBus.post(about:.contacts)
    }

    func store(key: String, value: Haber) {
        guard let key2 = key.data(using: .utf8) else {
            print("could not make key.data")
            return
        }
        self.store[key] = value
        Backend.store(key: key2, value: value)
    }

    func didReceiveStore(_ haber: Haber) {
        guard let key = String(data: haber.store.key, encoding: .utf8),
                let value = try? Haber.parseFrom(data:haber.store.value)
                else {
            print("could not get store")
            return
        }
        self.store[key] = value
        EventBus.post(forKey: key)
    }

    private func post(about:Haber.Which) {
        EventBus.post(about: about)
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
        Backend.sendContacts(self.roster)
    }

    func credentials() -> (username: String, password: String)? {
        if let username = UserDefaults.standard.string(forKey: Model.usernameKey),
            let password = UserDefaults.standard.string(forKey: Model.passwordKey) {
            return (username, password)
        }
        return nil
    }

    private init() {}
}
