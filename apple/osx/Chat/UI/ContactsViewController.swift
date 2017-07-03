import Cocoa

class ContactsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    var names = [String]()

    @IBOutlet weak var tableView: NSTableView!

    @IBAction func didClickAdd(_ sender: Any) {
        AppDelegate.ask(title: "Add New Contact", subtitle: "Enter contact's username", cancelable: true) { username in
            if let username = username {
                self.addContact(username)
            }
        }
    }

    @IBAction func didClickDel(_ sender: Any) {
        let row = self.tableView.selectedRow
        if row >= 0 {
            Model.shared.roster.removeValue(forKey: self.names[row])
            self.names.remove(at: row)
            self.updateNames()
        }
    }

    var watchingListener:((_ watching: String?)->Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self

        Model.shared.addListener(about: .contacts) { notification in
            self.names = Array(Model.shared.roster.values).map({ contact in return contact.name })
            self.tableView.reloadData()
        }

        Model.shared.addListener(about: .presence) { notification in
            self.tableView.reloadData()
        }

        Model.shared.addListener(about: .text) { notification in
            self.tableView.reloadData()
        }
    }

    func addContact(_ username:String) {
        self.names.append(username)
        self.updateNames()
    }

    func updateNames() {
        self.names.sort()
        self.tableView.reloadData()
        Model.shared.setContacts(self.names)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.names.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let cellView = tableView.make(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
        let name = self.names[row]
        cellView.textField?.stringValue = self.cellTextFor(name)
        cellView.textField?.textColor = Model.shared.roster[name]?.online == true ? .blue : .gray
        return cellView
    }

    func cellTextFor(_ name: String) -> String {
        let unreads = Model.shared.unreads[name] ?? 0
        let showUnreads = unreads > 0 ? " (\(unreads))" : ""
        return name + showUnreads
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let table = notification.object as! NSTableView
        Model.shared.watching = table.selectedRow >= 0 ? self.names[table.selectedRow] : nil
        watchingListener?(Model.shared.watching)
    }
}
