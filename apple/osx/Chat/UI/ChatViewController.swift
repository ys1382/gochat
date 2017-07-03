
import Cocoa

class ChatViewController : NSSplitViewController {
    
    @IBOutlet private weak var itemContacts: NSSplitViewItem!
    @IBOutlet private weak var itemConversation: NSSplitViewItem!

    private var contacts: ContactsViewController? {
        get {
            return itemContacts.viewController as? ContactsViewController
        }
    }

    private var conversation: ConversationViewController? {
        get {
            return itemConversation.viewController as? ConversationViewController
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        contacts?.watchingListener = { (watching: String?) in
            self.update(watching)
        }
    }
    
    func update(_ watching: String?) {
        conversation?.update(watching)
    }
}
