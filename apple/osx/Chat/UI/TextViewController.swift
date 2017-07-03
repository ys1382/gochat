import Cocoa
import AVFoundation

class TextViewController: NSViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    static var shared: TextViewController?

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var transcript: NSTextView!
    @IBOutlet weak var input: NSTextField!
    @IBOutlet weak var sendButton: NSButton!

    func update(_ watching: String?) {
        updateTranscript()
    }

    @IBAction func didClickSend(_ sender: Any) {
        let body = input.stringValue
        Backend.shared.sendText(body, to: Model.shared.watching!)
        input.stringValue = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TextViewController.shared = self

        self.updateTranscript()
        Model.shared.addListener(about: .text) { notification in
            self.updateTranscript()
        }
    }

    private func updateTranscript() {
        if let whom = Model.shared.watching {
            self.transcript.string = Model.shared.texts
                .filter({ haber in haber.from == Model.shared.username || haber.from == whom })
                .reduce("", { text,haber in text + "\n" + haber.from + ": " + haber.text.body} )
        }
    }
}
