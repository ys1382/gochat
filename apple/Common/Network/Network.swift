
import Foundation

func logNetwork(_ message: String) {
    logMessage("Network", message)
}

func logNetworkError(_ message: String) {
    logError("Network", message)
}

func logNetworkError(_ error: Error) {
    logError("Network", error)
}
