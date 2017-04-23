import UIKit

class MasterViewController: UITableViewController {

    static let usernameKey = "username"
    static let address = "ws://107.170.4.248:8000/ws"

    var detailViewController: DetailViewController? = nil
    var names = [String]()

    func login(username: String) {
        Backend.shared.connect(withUsername: username, address: MasterViewController.address)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.leftBarButtonItem = self.editButtonItem

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(askContact(_:)))
        self.navigationItem.rightBarButtonItem = addButton
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            self.detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }

        Model.shared.addListener(about: .roster) { notification in
            self.names = Array(Model.shared.roster.values).map({ contact in return contact.name })
            self.tableView.reloadData()
        }

        Model.shared.addListener(about: .presence) { notification in
            self.tableView.reloadData()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        self.clearsSelectionOnViewWillAppear = self.splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        if let username = UserDefaults.standard.string(forKey: MasterViewController.usernameKey) {
            self.login(username: username)
        } else {
            askName()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let controller = (segue.destination as? UINavigationController)?.topViewController as? DetailViewController,
            let indexPath = self.tableView.indexPathForSelectedRow {
            controller.withWhom = self.names[indexPath.row]
            controller.navigationItem.leftBarButtonItem = self.splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }

    // modals

    func ask(title: String, cancellable: Bool, done:@escaping (String)->Void) {
        let alertController = UIAlertController(title: nil,
                                                message: title,
                                                preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { (action) in
            if let text = alertController.textFields?[0].text {
                done(text)
            }
        }
        alertController.addAction(okAction)

        if cancellable {
            let cancelAction = UIAlertAction(title: "CANCEL", style: .cancel)
            alertController.addAction(cancelAction)
        }

        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = "New contact name"
        }
        self.present(alertController, animated: true, completion: nil)
    }

    func askName() {
        self.ask(title:"Enter your username", cancellable: false) { username in
            UserDefaults.standard.set(username, forKey:MasterViewController.usernameKey)
            self.login(username: username)
        }
    }

    func askContact(_ sender: Any) {
        self.ask(title:"Add a contact", cancellable: true) { username in
            self.addContact(username)
        }
    }

    // table

    func addContact(_ username:String) {
        self.names.insert(username, at: 0)
        self.updateNames()
    }

    func updateNames() {
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
        let name = names[indexPath.row]
        cell.textLabel?.text = names[indexPath.row]
        let online = Model.shared.roster[name]?.online ?? false
        cell.textLabel?.textColor = online ? UIColor.blue : UIColor.gray
        return cell
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
