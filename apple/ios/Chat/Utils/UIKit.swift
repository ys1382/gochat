
import UIKit

extension UIViewController {
    
    func presentExplicitly(_ vc: UIViewController, animated: Bool, completion: FuncVV? = nil) {
        let show: FuncVV = { self.present(vc, animated: animated, completion: completion) }
        
        if presentedViewController != nil {
            presentedViewController!.dismiss(animated: animated, completion: show)
        }
        else {
            show()
            
        }
    }
    
}
