import UIKit
import Starscream

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var input: UITextField!
    @IBOutlet weak var transcript: UITextView!
    @IBOutlet weak var videoBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var audioBarButtonItem: UIBarButtonItem!
    
    var callInfo: NetworkCallInfo? {
        didSet {
            if callInfo == nil {
                audioBarButtonItem.tintColor = nil
                videoBarButtonItem.tintColor = nil
                audioBarButtonItem.isEnabled = true
                videoBarButtonItem.isEnabled = true
            } else if callInfo!.proposal.video {
                videoBarButtonItem.tintColor = UIColor.red
            } else if callInfo!.proposal.audio {
                audioBarButtonItem.tintColor = UIColor.red
            }
        }
    }

    @IBAction func sendClicked(_ sender: Any) {
        guard let body = input.text, let whom = Model.shared.watching else {
            print("could not create Text")
            return
        }
        //Backend.shared.sendText(body, to: whom)
        VoipBackend.sendText(body, peerId: whom)
        input.text = ""
    }

    @IBAction func videoBarButtonItemAction(_ sender: UIBarButtonItem) {
        if stopCallIfNeeded(videoBarButtonItem) == false {
            _ = callVideoAsync(Model.shared.watching!)
        }
    }

    @IBAction func audioBarButtonItemAction(_ sender: UIBarButtonItem) {
        if stopCallIfNeeded(audioBarButtonItem) == false {
            _ = callAudioAsync(Model.shared.watching!)
        }
    }
    
    private func stopCallIfNeeded(_ button: UIBarButtonItem) -> Bool {
        guard button.tintColor == UIColor.red else { return false }

        stopCallAsync(self.callInfo!)
        callInfo = nil
        
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = Model.shared.watching
        self.updateTranscript()
       
        EventBus.addListener(about: .text) { notification in
            self.updateTranscript()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        if self.navigationController?.viewControllers.contains(self) == false {
            Model.shared.watching = nil
        }
    }

    private func updateTranscript() {
        if let whom = Model.shared.watching {
            let textsFiltered = Model.shared.texts
                .filter({ text in text.to == whom || text.from == whom })
            let textsReduced = textsFiltered.reduce("", { sum, text in sum + lineOf(text) } )
            transcript.text = textsReduced
        }
    }
    
    private func lineOf(_ text: Text) -> String {
        return text.from + ": " + String(data: text.body, encoding: .utf8)!  + "\n"
    }
}
