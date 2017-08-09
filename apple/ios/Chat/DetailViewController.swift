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
        VoipBackend.sendText(body, peerId: whom)
        input.text = ""
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = Model.shared.watching
        updateTranscript()
        EventBus.addListener(about: .text) { notification in
            self.updateTranscript()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        Model.shared.watching = nil
    }

    private func updateTranscript() {

        if let whom = Model.shared.watching {
            transcript.text = Model.shared.texts
                .filter({ text in text.to == whom || text.from == whom })
                .reduce("", { sum, text in
                    sum! + text.from + ": " + String(data: text.body, encoding: .utf8)!  + "\n"} )
        }

//        if let whom = Model.shared.watching {
//            transcript.text = Model.shared.texts
//                .filter({ haber in haber.from == Backend.shared.credential?.username || haber.from == whom })
//                .reduce("", { text,haber in text + "\n" + haber.from + ": " + String(data: haber.payload, encoding: .utf8)!} )
//        }
    }
}
