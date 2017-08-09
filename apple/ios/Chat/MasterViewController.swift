import UIKit

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    private var ids = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.leftBarButtonItem = editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(askContact(_:)))
        navigationItem.rightBarButtonItem = addButton
        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }

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

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = (segue.destination as? UINavigationController)?.topViewController as? DetailViewController,
            let indexPath = tableView.indexPathForSelectedRow {
            tableView.reloadData()
            Model.shared.watching = ids[indexPath.row]
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }

    @objc func askContact(_ sender: Any) {
        let alertController = UIAlertController(title: nil,
                                                message: "Add a Contact",
                                                preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
            if let text = alertController.textFields?[0].text {
                self.addContact(text)
            }
        }
        alertController.addAction(okAction)

        let cancelAction = UIAlertAction(title: "CANCEL", style: .cancel)
        alertController.addAction(cancelAction)

        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "New contact name"
        }
        present(alertController, animated: true, completion: nil)
    }

    // table

    private func addContact(_ username:String) {
        ids.insert(username, at: 0)
        updateNames()
    }

    private func updateNames() {
        ids.sort()
        tableView.reloadData()
        Model.shared.setContacts(ids)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ids.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let name = ids[indexPath.row]
        cell.textLabel?.text = cellTextFor(name)
        cell.textLabel?.textColor = Model.shared.roster[name]?.online == true ? .blue : .gray
        return cell
    }

    func cellTextFor(_ name: String) -> String {
        let unreads = Model.shared.unreads[name] ?? 0
        let showUnreads = unreads > 0 ? " (\(unreads))" : ""
        return name + showUnreads
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCellEditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            ids.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            updateNames()
        }
    }
}
