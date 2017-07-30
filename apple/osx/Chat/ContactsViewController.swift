import Cocoa

class ContactsViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    var ids = [String]()

    @IBOutlet weak var tableView: NSTableView!

    @IBAction func didClickAdd(_ sender: Any) {
        let alert = NSAlert()

        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        alert.messageText = "Add New Contact"
        alert.informativeText = "Enter contact's username"

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        if alert.runModal() == NSAlertFirstButtonReturn {
            addContact(textField.stringValue)
        }
    }

    @IBAction func didClickDel(_ sender: Any) {
        let row = tableView.selectedRow
        if row >= 0 {
            Model.shared.roster.removeValue(forKey: ids[row])
            updateNames()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self

        EventBus.addListener(about: .contacts) { notification in
            self.ids = Array(Model.shared.roster.values).map({ contact in return contact.id })
            self.tableView.reloadData()
        }

        EventBus.addListener(about: .presence) { notification in
            self.tableView.reloadData()
        }

        EventBus.addListener(about: .text) { notification in
            self.tableView.reloadData()
        }
    }

    func addContact(_ username:String) {
        ids.append(username)
        updateNames()
    }

    func updateNames() {
        tableView.reloadData()
        Model.shared.setContacts(ids)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return ids.count
    }

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let cellView = tableView.make(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView
        let id = ids[row]
        cellView.textField?.stringValue = cellTextFor(id)
        cellView.textField?.textColor = Model.shared.roster[id]?.online == true ? .blue : .gray
        return cellView
    }

    func cellTextFor(_ id: String) -> String {
        let unreads = Model.shared.unreads[id] ?? 0
        let showUnreads = unreads > 0 ? " (\(unreads))" : ""
        return id + showUnreads
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let table = notification.object as! NSTableView
        Model.shared.watching = table.selectedRow >= 0 ? ids[table.selectedRow] : nil
        TextViewController.shared?.reload()
    }
}
