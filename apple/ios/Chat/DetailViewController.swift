import UIKit
import Starscream

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var input: UITextField!
    @IBOutlet weak var transcript: UITextView!

    @IBAction func sendClicked(_ sender: Any) {
        guard let body = input.text, let whom = self.withWhom else {
            print("could not create Text")
            return
        }
        Backend.shared.sendText(body, to: whom)
        input.text = ""
    }

    var withWhom: String? {
        didSet {
            self.title = withWhom
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Model.shared.addListener(about: .text) { notification in
            if let haber = notification.userInfo?[Haber.Which.text] as? Haber,
                (self.withWhom == haber.from || Model.shared.username == haber.from) {
                self.addLine(line: haber.text.body, from:haber.from)
            }
        }
    }

    func addLine(line: String, from: String = Model.shared.username ?? "You") {
        let report = from + ": " + line
        let newline = (self.transcript.text?.characters.count ?? 0) > 0 ? "\n" : ""
        self.transcript.text = (self.transcript.text ?? "") + newline + report
    }
}
