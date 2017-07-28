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
        Backend.shared.sendText(body, to: Model.shared.watching!)
        input.stringValue = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TextViewController.shared = self

        updateTranscript()
        EventBus.addListener(about: .text) { notification in
            self.updateTranscript()
        }

        updateTranscript()
    }

    private func updateTranscript() {
        if let whom = Model.shared.watching {
            transcript.string = Model.shared.texts
                .filter({ text in text.to == whom || text.from == whom })
                .reduce("", { sum, text in
                    sum! + Model.shared.nameFor(text.from) + ": " + String(data: text.body, encoding: .utf8)!  + "\n"} )
        }
    }
}
