import Foundation

func logMessage(_ message: String) {
    print(message)
}

func logMessage(_ scope: String, _ message: String) {
    logMessage((scope + ": ").padding(toLength: 10, withPad: " ", startingAt: 0) + message)
}

func logError(_ scope: String, _ message: String) {
    logMessage("Error in " + scope + ": " + message)
}

func logError(_ message: String) {
    logError("global", message)
}

func checkError(_ status: OSStatus) -> Bool {
    if status != noErr {
        logError(status.description)
        return true
    }
    return false
}

func logIO(_ message: String) {
    logMessage("IO", message)
}

func logIOError(_ message: String) {
    logError("IO", message)
}

func logNetwork(_ message: String) {
    logMessage("Network", message)
}

func logNetworkError(_ message: String) {
    logError("Network", message)
}
