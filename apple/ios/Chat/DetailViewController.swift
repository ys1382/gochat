import UIKit
import Starscream

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var input: UITextField!
    @IBOutlet weak var transcript: UITextView!

    @IBAction func sendClicked(_ sender: Any) {
        guard let body = input.text, let whom = Model.shared.watching else {
            print("could not create Text")
            return
        }
        Backend.shared.sendText(body, to: whom)
        input.text = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = Model.shared.watching
        self.updateTranscript()
        Model.shared.addListener(about: .text) { notification in
            self.updateTranscript()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        Model.shared.watching = nil
    }

    private func updateTranscript() {
        if let whom = Model.shared.watching {
            self.transcript.text = Model.shared.texts
                .filter({ haber in haber.from == Model.shared.username || haber.from == whom })
                .reduce("", { text,haber in text + "\n" + haber.from + ": " + haber.text.body} )
        }
    }
}
