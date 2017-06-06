import UIKit
import Starscream

class DetailViewController: UIViewController {

    @IBOutlet weak var detailDescriptionLabel: UILabel!
    @IBOutlet weak var input: UITextField!
    @IBOutlet weak var transcript: UITextView!
    @IBOutlet weak var cameraBarButtonItem: UIBarButtonItem!

    @IBAction func sendClicked(_ sender: Any) {
        guard let body = input.text, let whom = Model.shared.watching else {
            print("could not create Text")
            return
        }
        Backend.shared.sendText(body, to: whom)
        input.text = ""
    }

    @IBAction func cameraBarButtonItemAction(_ sender: UIBarButtonItem) {
        userMediaViewController = showMedia(Model.shared.watching)
    }

    var userMediaViewController: MediaViewController?
    var videoSessionStart: ((_ to: String, _ sid: String, _ format: VideoFormat) throws ->IODataProtocol?)?
    var videoSessionStop: ((_ sid: String)->Void)?

    func showMedia(_ watching: String?) -> MediaViewController {
        let mediaID = String(describing: MediaViewController.self)
        let media = self.storyboard?.instantiateViewController(withIdentifier: mediaID) as! MediaViewController
        
        userMediaViewController = nil
        media.setWatching(watching!)
        self.navigationController?.pushViewController(media,
                                                      animated: true)
        
        return media
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = Model.shared.watching
        self.updateTranscript()
        Model.shared.addListener(about: .text) { notification in
            self.updateTranscript()
        }
        
        // setup video output
        
        videoSessionStart = { (_ to: String, _ sid: String, _ format: VideoFormat) throws -> IODataProtocol? in
            
            var media: MediaViewController?
            
            dispatch_sync_on_main {
                self.title = to
                Model.shared.watching = to
                
                media = self.navigationController?.topViewController as? MediaViewController
                
                if media == self.userMediaViewController && sid == self.userMediaViewController?.sessionID {
                    return
                }
                
                if media != nil && (media?.sessionID == sid  || media?.sessionID == String()) {
                    return
                }
                
                if media != nil {
                    self.navigationController?.popViewController(animated: true)
                }
                
                media = self.showMedia(to)
                _ = media?.view
            }
            
            return try media?.videoSessionStart?(to, sid, format)
        }
        
        videoSessionStop = { (_ sid: String) in
            
            var media: MediaViewController?

            dispatch_sync_on_main {
                guard let media_ = self.navigationController?.topViewController as? MediaViewController else { return }
                guard media_.sessionID == sid else { return }

                self.navigationController?.popViewController(animated: true)
                media = media_
            }
            
            media?.videoSessionStop?(sid)
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        if self.navigationController?.viewControllers.contains(self) == false {
            Model.shared.watching = nil
        }
    }

    private func updateTranscript() {
        if let whom = Model.shared.watching {
            self.transcript.text = Model.shared.texts
                .filter({ haber in haber.from == Model.shared.username || haber.from == whom })
                .reduce("", { text,haber in text + "\n" + haber.from + ": " + haber.text.body} )
        }
    }
}
