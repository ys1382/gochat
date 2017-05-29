
import Foundation

func logMessage(_ message: String) {
    print(message)
}

func logMessage(_ scope: String, _ message: String) {
    logMessage((scope + ": ").padding(toLength: 10, withPad: " ", startingAt: 0) + message)
}

func logError(_ scope: String, _ error: Error) {
    logMessage("Error in " + scope + ": " + error.localizedDescription)
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
