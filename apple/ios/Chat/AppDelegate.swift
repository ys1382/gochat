import UIKit
import Fabric
import Crashlytics
import CoreMedia

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // fabric
        
        Fabric.with([Crashlytics.self])

        // enable for Video capture
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()

        // UI
        
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let last = splitViewController.viewControllers.count-1
        let navigationController = splitViewController.viewControllers[last] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self
        
        // Audio
        
        AV.shared.setupDefaultNetworkInputAudio(ChatAudioSession())
        
        // Video low res hardcoded
        
        if AV.shared.defaultVideoDimention != nil {
            let k = 640.0 / Double(AV.shared.defaultVideoDimention!.width)
            let w = Double(AV.shared.defaultVideoDimention!.width) * k
            let h = Double(AV.shared.defaultVideoDimention!.height) * k
            AV.shared.defaultVideoDimention = CMVideoDimensions(width: Int32(w),
                                                                height: Int32(h))
        }
        
        // done

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
