import Foundation
import Starscream

class Model {

    static let shared = Model()

    private var textsStorage = [Data]()

    var roster = [String:Contact]()
    var texts = [Text]()
    var unreads = [String:Int]()
    var watching: String? {
        didSet {
            if let watching = watching {
                unreads[watching] = 0
            }
        }
    }

    private enum ModelError: Error {
        case keyNotHandled
    }

    struct Text {
        var message: Data
        var from: String
        var to: String
    }

    private init() {
        EventBus.addListener(about: .authenticated, didReceive: { notification in
            Backend.shared.sendLoad(key: .texts)
        })
    }

    func didReceivePresence(_ haber: Haber) {
        for contact in haber.contacts {
            roster[contact.id] = contact
        }
        EventBus.post(about:.presence)
    }

    func didReceiveText(_ haber: Haber, data:Data, from: String?) {
        if let from = from, from != watching {
            unreads[from] = (unreads[from] ?? 0) + 1
        }
        let text = Text(message: haber.payload, from: from!, to: haber.to)
        texts.append(text)
        EventBus.post(about:.text)
        storeText(data: data)
    }

    private func storeText(data: Data) {
        textsStorage.append(data)
        do {
            let allTexts = try Haber.Builder().setRaw(textsStorage).build().data()
            let key = LocalStorage.Key.texts.toData()
            Backend.shared.sendStore(key: key, value: allTexts)
        } catch {
            print(error.localizedDescription)
        }
    }

    func didReceiveContacts(_ contacts: [Contact]) {
        roster = contacts.reduce([String: Contact]()) { (dict, contact) -> [String: Contact] in
            var dict = dict
            dict[contact.id] = contact
            return dict
        }
        EventBus.post(about:.contacts)
    }

    func didReceiveStore(key keyData: Data, value: Data) throws {
        let key = try LocalStorage.Key(keyData)
        guard key == .texts else {
            throw ModelError.keyNotHandled
        }
        let parsed = try Haber.parseFrom(data: value)
        textsStorage = parsed.raw
        texts = previousTexts()
        EventBus.post(.texts)
    }

    private func previousTexts() -> [Text] {
        var result = [Text]()
        for data in textsStorage {
            do {
                let message = try Haber.parseFrom(data: data)
                guard message.which == .text else {
                    print("\(message.which) in textStorage")
                    continue
                }
                let text = Text(message: message.payload, from: message.from, to: message.to)
                result.append(text)
            } catch {
                print(error.localizedDescription)
            }
        }
        return result
    }

    func setContacts(_ ids: [String]) {
        var update = [String:Contact]()
        for id in ids {
            if let existing = roster[id] {
                update[id] = existing
            } else {
                update[id] = try? Contact.Builder().setId(id).build()
            }
        }
        roster = update
        Backend.shared.sendContacts(Array(roster.values))
    }

    func nameFor(_ id: String) -> String {
        var result: String? = nil
        if let contact = roster[id] {
            result = contact.name ?? contact.id
        }
        return result ?? "?"
    }
}
