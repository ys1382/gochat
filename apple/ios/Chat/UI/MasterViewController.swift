import UIKit

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    private var names = [String]()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem = self.editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(askContact(_:)))
        self.navigationItem.rightBarButtonItems!.append(addButton)

        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }

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

    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = (segue.destination as? UINavigationController)?.topViewController as? DetailViewController,
            let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.reloadData()
            Model.shared.watching = self.names[indexPath.row]
            controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }

    func askContact(_ sender: Any) {
        SplitViewController.askString(title:"Add a contact", cancellable: true) { username in
            self.addContact(username)
        }
    }

    // table

    private func addContact(_ username:String) {
        self.names.insert(username, at: 0)
        self.updateNames()
    }

    private func updateNames() {
        self.names.sort()
        self.tableView.reloadData()
        Model.shared.setContacts(self.names)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return names.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let name = self.names[indexPath.row]
        cell.textLabel?.text = self.cellTextFor(name)
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
            self.names.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
            self.updateNames()
        }
    }
}
