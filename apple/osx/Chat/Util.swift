import Foundation

func checkError(_ status: OSStatus) -> Bool {
    if status != noErr {
        print("Error " + status.description)
        return true
    }
    return false
}
