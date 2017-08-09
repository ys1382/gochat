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
        let whom = Model.shared.watching!
        Model.shared.addText(body: body.data(using: .utf8)!, from: Auth.shared.username!, to: whom)
        VoipBackend.sendText(body, peerId: Model.shared.watching!)
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
            let textsFiltered = Model.shared.texts
                .filter({ text in text.to == whom || text.from == whom })
            let textsReduced = textsFiltered.reduce("", { sum, text in sum + lineOf(text) } )
            transcript.string = textsReduced
        }
    }

    private func lineOf(_ text: Text) -> String {
        return text.from + ": " + String(data: text.body, encoding: .utf8)!  + "\n"
    }
}
