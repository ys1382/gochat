import Cocoa

class TextViewController: NSViewController {

    static var shared: TextViewController?

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var transcript: NSTextView!
    @IBOutlet weak var input: NSTextField!
    @IBOutlet weak var sendButton: NSButton!

    func reload() {
        _ = [scrollView, input, sendButton].map({ view in view.isHidden = Model.shared.watching == nil })
        updateTranscript()
    }

    @IBAction func didClickSend(_ sender: Any) {
        let body = input.stringValue
        Backend.sendText(body, to: Model.shared.watching!)
        input.stringValue = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TextViewController.shared = self

        self.updateTranscript()
        EventBus.addListener(about: .text) { notification in
            self.updateTranscript()
        }

        self.updateTranscript()
    }

    private func updateTranscript() {
        if let whom = Model.shared.watching {
            self.transcript.string = Model.shared.texts
                .filter({ haber in haber.from == Model.shared.credential?.username || haber.from == whom })
                .reduce("", { text,haber in text! + haber.from + ": " + haber.text.body + "\n"} )
        }
    }
}
