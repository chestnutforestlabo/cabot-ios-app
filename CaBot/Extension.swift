import Foundation

// https://stackoverflow.com/questions/11197509/how-to-get-device-make-and-model-on-ios/11197770#11197770
extension UIDevice {
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}

// https://stackoverflow.com/a/21848247
public extension UIWindow {
    var visibleViewController: UIViewController? {
        return UIWindow.getVisibleViewControllerFrom(self.rootViewController)
    }

    static func getVisibleViewControllerFrom(_ vc: UIViewController?) -> UIViewController? {
        if let nc = vc as? UINavigationController {
            return UIWindow.getVisibleViewControllerFrom(nc.visibleViewController)
        } else if let tc = vc as? UITabBarController {
            return UIWindow.getVisibleViewControllerFrom(tc.selectedViewController)
        } else {
            if let pvc = vc?.presentedViewController {
                return UIWindow.getVisibleViewControllerFrom(pvc)
            } else {
                return vc
            }
        }
    }
}

// https://stackoverflow.com/a/67495147/15421301
struct NavigationUtil {
  static func popToRootView() {
    findNavigationController(viewController: UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.rootViewController)?
      .popToRootViewController(animated: true)
  }

  static func findNavigationController(viewController: UIViewController?) -> UINavigationController? {
    guard let viewController = viewController else {
      return nil
    }

    if let navigationController = viewController as? UINavigationController {
      return navigationController
    }

    for childViewController in viewController.children {
      return findNavigationController(viewController: childViewController)
    }

    return nil
  }
}


func CustomLocalizedString(_ key:String, lang:String, tableName:String = "Localizable", bundle:Bundle = Bundle.main, returnKeyIfNotFound:Bool = true) -> String {
    if let path = bundle.path(forResource: lang, ofType: "lproj") {
        let bundle = Bundle(path: path)
        if let string = bundle?.localizedString(forKey: key, value: nil, table: tableName) {
            return string
        }
    }

    let langCode = String(lang.prefix(2))
    if let path = bundle.path(forResource: langCode, ofType: "lproj") {
        let bundle = Bundle(path: path)
        if let string = bundle?.localizedString(forKey: key, value: nil, table: tableName) {
            return string
        }
    }
    if returnKeyIfNotFound {
        return "<<\(key)>>"
    } else {
        return ""
    }
}
