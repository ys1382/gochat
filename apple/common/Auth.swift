import Foundation

// placeholder until we have real authentication
class Auth {

    static let shared = Auth()
    var username: String?
    var password: String?
    private static let usernameKey = "username"
    private static let passwordKey = "password"

    init() {
        username = UserDefaults.standard.string(forKey: Auth.usernameKey)
        password = UserDefaults.standard.string(forKey: Auth.passwordKey)
    }

    func save() {
        UserDefaults.standard.set(username, forKey: Auth.usernameKey)
        UserDefaults.standard.set(password, forKey: Auth.passwordKey)
    }

    func login() -> Bool {
        if let username = username, let password = password {
            login(username: username, password: password)
            return true
        } else {
            return false
        }
    }

    func login(username: String, password: String) {
        self.username = username
        self.password = password
        WireBackend.shared.login(username: username, password: password)
    }

    private func authenticated(sessionId sid: String) {
        UserDefaults.standard.set(username, forKey: Auth.usernameKey)
        UserDefaults.standard.set(password, forKey: Auth.passwordKey)
    }
}
