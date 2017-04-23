import Cocoa

class TextViewController: NSViewController {

    static var shared: TextViewController?

    @IBOutlet weak var scrollView: NSScrollView!
    @IBOutlet var transcript: NSTextView!
    @IBOutlet weak var input: NSTextField!
    @IBOutlet weak var sendButton: NSButton!

    var withWhom: String? {
        didSet {
            let hidden = self.withWhom == nil
            _ = [scrollView, input, sendButton].map({ view in view.isHidden = hidden })
            transcript.string = ""
        }
    }

    @IBAction func didClickSend(_ sender: Any) {
        let body = input.stringValue
        Backend.shared.sendText(body, to: self.withWhom!)
        input.stringValue = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        TextViewController.shared = self

        Model.shared.addListener(about: .text) { notification in
            if let haber = notification.userInfo?[Haber.Which.text] as? Haber,
                (self.withWhom == haber.from || Model.shared.username == haber.from) {
                self.addLine(line: haber.text.body, from:haber.from)
            }
        }
    }

    func addLine(line: String, from: String = Model.shared.username ?? "You") {
        let report = from + ": " + line
        let newline = (self.transcript.string?.characters.count ?? 0) > 0 ? "\n" : ""
        self.transcript.string = (self.transcript.string ?? "") + newline + report
    }
}
