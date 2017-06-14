import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        self.setupUI()
        return true
    }

    private func setupUI() {
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let last = splitViewController.viewControllers.count-1
        let navigationController = splitViewController.viewControllers[last] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
    }

    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController:UIViewController,
                             onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController,
            let _ = secondaryAsNavController.topViewController as? DetailViewController else {
            return false
        }
        if Model.shared.watching == nil {
            // Return true to indicate that we have handled the collapse by doing nothing.
            // The secondary controller will be discarded.
            return true
        }
        return false
    }
}
