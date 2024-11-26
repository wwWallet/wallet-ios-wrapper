import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window : UIWindow?

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey : Any] = [:] ) -> Bool {

        // Determine who sent the URL.
        let sendingAppID = options[.sourceApplication]
        print("source application = \(sendingAppID ?? "Unknown")")

        // Process the URL.
        if url.scheme == "openid4vp" {
            print("FUNKE Wallet URL scheme opened with OpenID4VP URL:", url)
            // trigger a BLE scan and show the specific view
            // bleCentralManager.startScanning()
            return true
        }
        
        if url.scheme == "mdoc" {
            print("FUNKE Wallet URL scheme opened with mDoc URL:", url)
            // trigger a BLE scan and show the specific view
            // bleCentralManager.startScanning()
            return true
        }
        
        return true
        
    }

}

