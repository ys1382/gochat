
import Foundation

fileprivate extension DispatchQueue {
    static let logQueue = DispatchQueue(label: "Log")
}

fileprivate extension OutputStream {
    
    static let log = CreateLog()
    
    static func CreateLog() -> OutputStream? {
        let url = URL
            .appLogs
            .appendingPathComponent("\(Date().description) - \(deviceModel()).txt")
        
        if FileManager.default.fileExists(atPath: URL.appLogs.path) == false {
            try! FileManager.default.createDirectory(at: URL.appLogs,
                                                     withIntermediateDirectories: true, attributes: nil)
        }
        
        let result = OutputStream(toFileAtPath: url.path, append: true)
        result?.open()
        return result
    }
}

func logWrite(_ x: String) {
    let xx = String(format: "%.5f", app_absolute_seconds()) + ": \(x)"
    
    #if DEBUG
        print(xx)
    #else
        DispatchQueue.logQueue.async {
            OutputStream.log?.write(xx + "\n")
        }
    #endif
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Pipe: Messages
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func logMessage(_ message: String) {
#if !DEBUG
    logWrite(message)
#endif
}

func logMessage(_ scope: String, _ message: String) {
    logMessage((scope + ": ").padding(toLength: 10, withPad: " ", startingAt: 0) + message)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Pipe: Important messages
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func logPrior(_ message: String) {
    logWrite(message)
}

func logPrior(_ scope: String, _ message: String) {
    logPrior((scope + ": ").padding(toLength: 10, withPad: " ", startingAt: 0) + message)
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Pipe: Errors
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

func logError(_ scope: String, _ message: String) {
    logWrite(scope + " error" + ": " + message)
}

func logError(_ scope: String, _ error: Error) {
    logError(scope + " error" + ": " + String(describing: error))
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
