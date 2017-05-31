
import Cocoa

class MainViewController : NSSplitViewController {
    
    @IBOutlet weak var masterSplitViewItem: NSSplitViewItem!
    @IBOutlet weak var detailSplitViewItem: NSSplitViewItem!
 
    private var contactsViewController: ContactsViewController? {
        get {
            return masterSplitViewItem.viewController as? ContactsViewController
        }
    }

    private var videoViewController: VideoViewController? {
        get {
            return detailSplitViewItem.viewController as? VideoViewController
        }
    }
    
    override func viewWillAppear() {
        contactsViewController?.watchingListener = videoViewController?.watchingListener
    }
}
