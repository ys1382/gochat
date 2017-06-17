import Foundation
import Starscream

class Model {

    static let shared = Model()

    private var textsStorage = [Data]()

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

    private init() {
        EventBus.addListener(about: .authenticated, didReceive: { notification in
            let key = Key.texts.rawValue.data(using: String.Encoding.utf8)!
            Backend.shared.sendLoad(key: key)
        })
    }

    func didReceivePresence(_ haber: Haber) {
        for contact in haber.contacts {
            roster[contact.name] = contact
        }
        EventBus.post(about:.presence)
    }

    func didReceiveText(_ haber: Haber, data:Data) {
        if let from = haber.from, haber.from != watching {
            unreads[from] = (unreads[from] ?? 0) + 1
        }
        texts.append(haber)
        EventBus.post(about:.text)

        storeText(data: data)
    }

    private func storeText(data: Data) {
        textsStorage.append(data)
        do {
            let allTexts = try Haber.Builder().setRaw(textsStorage).build().data()
            let key = Key.texts.rawValue.data(using: String.Encoding.utf8)!
            Backend.shared.sendStore(key: key, value: allTexts)
        } catch {
            print(error.localizedDescription)
        }
    }

    func didReceiveContacts(_ contacts: [Contact]) {
        roster = contacts.reduce([String: Contact]()) { (dict, contact) -> [String: Contact] in
            var dict = dict
            dict[contact.name] = contact
            return dict
        }
        EventBus.post(about:.contacts)
    }

    func didReceiveStore(key keyData: Data, value: Data) {
        guard let key = String(data: keyData, encoding: .utf8) else {
            print("could not get store")
            return
        }
        guard key == Key.texts.rawValue else {
            print("Unexpected key " + key)
            return
        }
        do {
            let parsed = try Haber.parseFrom(data: value)
            textsStorage = parsed.raw
            texts = previousTexts()
            EventBus.post(forKey: key)
        } catch {
            print(error.localizedDescription)
        }
    }

    private func previousTexts() -> [Haber] {
        var result = [Haber]()
        for data in textsStorage {
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

    func setContacts(_ names: [String]) {
        var update = [String:Contact]()
        for name in names {
            if let existing = roster[name] {
                update[name] = existing
            } else {
                update[name] = try? Contact.Builder().setName(name).build()
            }
        }
        roster = update
        Backend.shared.sendContacts(roster)
    }
}
