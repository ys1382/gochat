import Foundation
import Starscream

class Model {

    static let shared = Model()

    private enum Key: String {
        case username
        case password
        case texts
    }

    struct Credential {
        let username: String
        let password: String
    }
    var credential: Credential?

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
    var textsStorage = [Data]()

    private init() {

        if let username = UserDefaults.standard.string(forKey: Key.username.rawValue),
            let password = UserDefaults.standard.string(forKey: Key.password.rawValue) {
            self.credential = Credential(username: username, password: password)
        }

        EventBus.addListener(about: .authenticated, didReceive: { notification in
            if let username = self.credential?.username, let password = self.credential?.password {
                UserDefaults.standard.set(username, forKey: Key.username.rawValue)
                UserDefaults.standard.set(password, forKey: Key.password.rawValue)
            }
            let key = Key.texts.rawValue.data(using: String.Encoding.utf8)!
            Backend.sendLoad(key: key)
        })
    }

    func didReceivePresence(_ haber: Haber) {
        for contact in haber.contacts {
            self.roster[contact.name] = contact
        }
        EventBus.post(about:.presence)
    }

    func didReceiveText(_ haber: Haber, data:Data) {
        if let from = haber.from, haber.from != self.watching {
            self.unreads[from] = (self.unreads[from] ?? 0) + 1
        }
        self.texts.append(haber)
        EventBus.post(about:.text)

        self.storeText(data: data)
    }

    private func storeText(data: Data) {
        self.textsStorage.append(data)
        do {
            let allTexts = try Haber.Builder().setRaw(self.textsStorage).build().data()
            let key = Key.texts.rawValue.data(using: String.Encoding.utf8)!
            Backend.sendStore(key: key, value: allTexts)
        } catch {
            print(error.localizedDescription)
        }
    }

    func didReceiveContacts(_ contacts: [Contact]) {
        self.roster = contacts.reduce([String: Contact]()) { (dict, contact) -> [String: Contact] in
            var dict = dict
            dict[contact.name] = contact
            return dict
        }
        EventBus.post(about:.contacts)
    }

    func didReceiveStore(_ haber: Haber) {
        guard let key = String(data: haber.store.key, encoding: .utf8) else {
            print("could not get store")
            return
        }
        guard key == Key.texts.rawValue else {
            print("Unexpected key " + key)
            return
        }
        do {
            let parsed = try Haber.parseFrom(data: haber.store.value)
            self.textsStorage = parsed.raw
            self.texts = self.previousTexts()
            EventBus.post(forKey: key)
        } catch {
            print(error.localizedDescription)
        }
    }

    func previousTexts() -> [Haber] {
        var result = [Haber]()
        for data in self.textsStorage {
            do {
                let message = try Haber.parseFrom(data: data)
                guard message.which == .text else {
                    print("\(message.which) in textStorage")
                    continue
                }
                result.append(message)
            } catch {
                print(error.localizedDescription)
            }
        }
        return result
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
}
