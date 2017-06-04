import UIKit
import Fabric
import Crashlytics
import CoreMedia

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        Fabric.with([Crashlytics.self])

        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let last = splitViewController.viewControllers.count-1
        let navigationController = splitViewController.viewControllers[last] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        AV.shared.setupDefaultNetworkInputAudio(ChatAudioSession())
        
        if AV.shared.defaultVideoDimention != nil {
            let k = 160.0 / Double(AV.shared.defaultVideoDimention!.width)
            let w = Double(AV.shared.defaultVideoDimention!.width) * k
            let h = Double(AV.shared.defaultVideoDimention!.height) * k
            AV.shared.defaultVideoDimention = CMVideoDimensions(width: Int32(w),
                                                                height: Int32(h))
        }

        return true
    }

    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController:UIViewController,
                             onto primaryViewController:UIViewController) -> Bool {
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else {
            return false
        }
        guard let _ = secondaryAsNavController.topViewController as? DetailViewController else {
            return false
        }
        if Model.shared.watching == nil {
            // Return true to indicate that we have handled the collapse by doing nothing
            // the secondary controller will be discarded.
            return true
        }
        return false
    }
}
