import UIKit
import SwiftUI
import WebKit
//import EudiWalletKit
import MdocDataTransfer18013
import MdocDataModel18013

var webView: WKWebView! = nil

class ViewController: UIViewController, WKNavigationDelegate, UIDocumentInteractionControllerDelegate, MdocOfflineDelegate, DocumentsToShareViewDelegate {
    
    var requestedItems = RequestItems()
    
    // DocumentsToShareViewDelegate delegate functions
    func didTapShareButton(selectedItems: [String]) {
        print("Share tapped with items: \(selectedItems)")
        requestedItems = (["org.iso.18013.5.1.mDL": ["org.iso.18013.5.1": selectedItems]] as RequestItems?)!
        handleSelected(readerAuthValidated: true, requestedItems: requestedItems)
    }

    func didTapCancelButton() {
        print("Cancel tapped")
    }

    private var proximityPresentationViewModel = ProximityPresentationViewModel()
    var documentController: UIDocumentInteractionController?
    var bleServerTransfer: MdocGattServer?
    
    // MdocOfflineDelegate - 1 of 3
    // These three delegate objects must be an instance of a class conforming to the MdocOfflineDelegate protocol
    func didChangeStatus(_ newStatus: MdocDataTransfer18013.TransferStatus) {
        print("FUNKE-VC-MdocOfflineDelegate TransferStatus:didChangeStatus: \(newStatus)")
        
        switch newStatus {
            case .connected:
                print("BLEState: connected")
            case .qrEngagementReady:
                print("BLEState: qrEngagementReady")
                proximityPresentationViewModel.getQRCodePayload(contentStr: (bleServerTransfer?.qrCodePayload)!)
                print("QRCode Payload: \(bleServerTransfer?.qrCodePayload ?? "")")
            case .initializing:
                print("BLEState: initializing")
            case .initialized:
                print("BLEState: initialized")
            case .started:
                print("BLEState: started")
            case .requestReceived: // handle the request by parsing it and presenting to user for consent
                print("BLEState: requestReceived")
            case .userSelected: // user consent?
                print("BLEState: userSelected")
                //handleSelected(readerAuthValidated: true, requestedItems: requestedItems)
                //bleServerTransfer?.userSelected(true, requestedItems)
            case .responseSent:
                print("BLEState: responseSent")
            case .disconnected:
                print("BLEState: disconnected")
            case .error:
                print("BLEState: error")
        }
    }
    
    // MdocOfflineDelegate - 2 of 3
    // Triggered by .requestReceived status change
    func didReceiveRequest(_ request: UserRequestInfo, handleSelected: @escaping (Bool, RequestItems?) -> Void) {
        print("FUNKE-VC-MdocOfflineDelegate didReceiveRequest -> UserRequestInfo:handleSelected: \(request.validItemsRequested)")
        
        qrCodeImageView.isHidden.toggle() // HIDE qr code image visibility
        showRequestedAttributes(request.validItemsRequested)
        //let reqItems = ["org.iso.18013.5.1.mDL": ["org.iso.18013.5.1": ["portrait", "portrait", "age_over_18"]]] as RequestItems?
        //handleSelected(false, requestedItems)
        //bleServerTransfer?.userSelected(true, reqItems)
    }
    
    // Show the requested attributes from verifier and ask for consent
    func showRequestedAttributes(_ items: RequestItems) {
        var attributeItems = [String]()

        for item in RequestedAttributes.parseData(items) {
            attributeItems = item.attributes
        }
        
        let listView = DocumentsToShareView(items: attributeItems)
        listView.translatesAutoresizingMaskIntoConstraints = false
        listView.delegate = self
        view.addSubview(listView)
            
        NSLayoutConstraint.activate([
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.topAnchor.constraint(equalTo: view.topAnchor),
            listView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MdocOfflineDelegate - 3 of 3
    func didFinishedWithError(_ error: any Error) {
        print("FUNKE-VC-MdocOfflineDelegate Error:didFinishedWithError: \(error)")
    }
    
    // Callback function from didReceiveRequest to handle the requestedItems
    func handleSelected(readerAuthValidated: Bool, requestedItems: RequestItems?) {
        print("ENTERED handleSelected callback")
        bleServerTransfer?.userSelected(true, requestedItems)
    }

    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    @IBOutlet weak var loadingView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var connectionProblemView: UIImageView!
    @IBOutlet weak var webviewView: UIView!
    var toolbarView: UIToolbar!
    
    var htmlIsLoaded = false;
    
    private var themeObservation: NSKeyValueObservation?
    var currentWebViewTheme: UIUserInterfaceStyle = .unspecified
    override var preferredStatusBarStyle : UIStatusBarStyle {
        if #available(iOS 13, *), overrideStatusBar{
            if #available(iOS 15, *) {
                return .default
            } else {
                return statusBarTheme == "dark" ? .lightContent : .darkContent
            }
        }
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    
        view.addSubview(qrCodeButton)
        
        // QR Code button to trigger QR Code driven ble engagement
        if let qrCodeImage = generateQRCode(from: "FunkeWallet") {
            qrCodeButton.setBackgroundImage(qrCodeImage, for: .normal)
        } else {
            qrCodeButton.setTitle("", for: .normal)
        }
        
        // This places the faux QR code image button just over the FUNKE PWA qr/camera button
        // on an iPhone Xr (similar in screen size to the an iPhone 11 pro, I believe)
        NSLayoutConstraint.activate([
            qrCodeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            qrCodeButton.centerYAnchor.constraint(equalTo: view.bottomAnchor, constant: -46),
            qrCodeButton.widthAnchor.constraint(equalToConstant: 44),
            qrCodeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Add target for qrCodeButton press
        qrCodeButton.addTarget(self, action: #selector(toggleQrCode), for: .touchUpInside)
        
        initWebView()
        initToolbarView()
        loadRootUrl()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification , object: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        FunkeWallet.webView.frame = calcWebviewFrame(webviewView: webviewView, toolbarView: nil)
    }
    
    @objc func keyboardWillHide(_ notification: NSNotification) {
        FunkeWallet.webView.setNeedsLayout()
    }
    
    // Create an image view
    let qrCodeImageView: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 70, y: 500, width: 300, height: 300))
        imageView.isHidden = true // Initially hidden
        
        return imageView
    }()
    
    // QR Code button to trigger QR Code BLE engagement
    let qrCodeButton: UIButton = {
        let button = UIButton(type: .system)
        // Add target for button press
        //button.addTarget(ViewController.self, action: #selector(showBLEView), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false

        return button
    }()
    
    // QR Code button action to trigger the BLE proximity server and show QR Code
    @objc func toggleQrCode() {
        
        if (qrCodeImageView.isHidden) {
            // Initialize the BLE server with a dictionary
            do {
                bleServerTransfer = try MdocGattServer(parameters: getMdocGattServerParams())
                
            } catch {
                print("Error initializing MdocGattServer")
            }
            
            // https://github.com/eu-digital-identity-wallet/eudi-lib-ios-iso18013-data-transfer/tree/main
            bleServerTransfer?.delegate = self
            bleServerTransfer!.performDeviceEngagement()
            
            // Start BLE advertising and show Qr code
            showQrCode()
            
        } else {
            bleServerTransfer?.stop() // stop ble advertising
            qrCodeImageView.isHidden.toggle() // Toggle qr code image visibility
        }
        
//        let bleView = ProximityPresentationView(proximityPresentationViewModel: ProximityPresentationViewModel())
//        let hostingController = UIHostingController(rootView: bleView)
//        
//        // Present the SwiftUI view modally
//        hostingController.modalPresentationStyle = .automatic
//        present(hostingController, animated: true, completion: nil)
    }
    
    // 18013-5
    func showQrCode() {
        
        qrCodeImageView.image = generateQRCode(from: (bleServerTransfer?.qrCodePayload)!)
        view.addSubview(qrCodeImageView)
        
        // Toggle qr code image visibility
        qrCodeImageView.isHidden.toggle()
    }
    
    // 18013-5
    func loadIssuerCertifcateData() -> Data? {
        // Locate the sample file in the app bundle
        guard let certificateURL = Bundle.main.url(forResource: "eudi_pid_issuer_ut", withExtension: "der") else {
            print("Certificate file not found.")
            return nil
        }
        
        do {
            // Load the file as Data
            let certificateData = try Data(contentsOf: certificateURL)
            return certificateData
        } catch {
            print("Error reading issuer certificate data: \(error)")
            return nil
        }
    }
    
    // https://github.com/eu-digital-identity-wallet/eudi-lib-ios-iso18013-data-transfer/tree/main
    func getMdocGattServerParams() -> [String: Any] {
        let params: [String: Any] = [
            InitializeKeys.document_json_data.rawValue: [readDataRepresentationFromFile(resource: "mdoc_sample_data", type: "json")],
            InitializeKeys.document_signup_issuer_signed_obj.rawValue: "",
            InitializeKeys.device_private_key_obj.rawValue: "",
            InitializeKeys.document_signup_issuer_signed_data.rawValue: "",
            InitializeKeys.device_private_key_data.rawValue: "pQECIAEhWCBoHIiBQnDRMLUT4yOLqJ1l8mrfNIgrjNnFq4RyZgxSmiJYIGD/Sabu6GejaR4eTiym1JkyjnBNcJ+f59pN+lCEyhVyI1ggC6EPCKyGci++LGWUX3fXpPFW6pYO8pyyKLMKs1qF0jo=",
            InitializeKeys.trusted_certificates.rawValue: [loadIssuerCertifcateData()],
            InitializeKeys.device_auth_method.rawValue: "mac"
        ]
        return params as [String : Any]
    }

    // Read the sample mDoc from resources and use this present proximity over BLE
    // TODO: Get the real mDoc from FUNKE Wallet
    func readDataRepresentationFromFile(resource: String, type: String) -> Data {
        let filePath = Bundle.main.path(forResource: resource, ofType: type)
        var docData: Data
        if let path = filePath {
            docData = FileManager.default.contents(atPath: path)!
            return docData
        }
        return Data()
    }
    
    // Function to generate QR code IMAGE to replace button background
    func generateQRCode(from string: String) -> UIImage? {
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            filter.setValue("Q", forKey: "inputCorrectionLevel")

            if let outputImage = filter.outputImage {
                let scaledImage = UIImage(ciImage: outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10)))
                return scaledImage
            }
        }
        return nil
    }
    
    func initWebView() {
        FunkeWallet.webView = createWebView(container: webviewView, WKSMH: self, WKND: self, NSO: self, VC: self)
        webviewView.addSubview(FunkeWallet.webView);
        
        FunkeWallet.webView.uiDelegate = self;
        
        FunkeWallet.webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)

        if(pullToRefresh){
            let refreshControl = UIRefreshControl()
            refreshControl.addTarget(self, action: #selector(refreshWebView(_:)), for: UIControl.Event.valueChanged)
            FunkeWallet.webView.scrollView.addSubview(refreshControl)
            FunkeWallet.webView.scrollView.bounces = true
        }

        if #available(iOS 15.0, *), adaptiveUIStyle {
            themeObservation = FunkeWallet.webView.observe(\.underPageBackgroundColor) { [unowned self] webView, _ in
                currentWebViewTheme = FunkeWallet.webView.underPageBackgroundColor.isLight() ?? true ? .light : .dark
                self.overrideUIStyle()
            }
        }
    }

    @objc func refreshWebView(_ sender: UIRefreshControl) {
        FunkeWallet.webView?.reload()
        sender.endRefreshing()
    }

    func createToolbarView() -> UIToolbar{
        let winScene = UIApplication.shared.connectedScenes.first
        let windowScene = winScene as! UIWindowScene
        var statusBarHeight = windowScene.statusBarManager?.statusBarFrame.height ?? 60
        
        #if targetEnvironment(macCatalyst)
        if (statusBarHeight == 0){
            statusBarHeight = 30
        }
        #endif
        
        let toolbarView = UIToolbar(frame: CGRect(x: 0, y: 0, width: webviewView.frame.width, height: 0))
        toolbarView.sizeToFit()
        toolbarView.frame = CGRect(x: 0, y: 0, width: webviewView.frame.width, height: toolbarView.frame.height + statusBarHeight)
//        toolbarView.autoresizingMask = [.flexibleTopMargin, .flexibleRightMargin, .flexibleWidth]
        
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let close = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(loadRootUrl))
        toolbarView.setItems([close,flex], animated: true)
        
        toolbarView.isHidden = true
        
        return toolbarView
    }
    
    func overrideUIStyle(toDefault: Bool = false) {
        if #available(iOS 15.0, *), adaptiveUIStyle {
            if (((htmlIsLoaded && !FunkeWallet.webView.isHidden) || toDefault) && self.currentWebViewTheme != .unspecified) {
                UIApplication
                    .shared
                    .connectedScenes
                    .flatMap { ($0 as? UIWindowScene)?.windows ?? [] }
                    .first { $0.isKeyWindow }?.overrideUserInterfaceStyle = toDefault ? .unspecified : self.currentWebViewTheme;
            }
        }
    }
    
    func initToolbarView() {
        toolbarView =  createToolbarView()
        
        webviewView.addSubview(toolbarView)
    }
    
    @objc func loadRootUrl() {
        FunkeWallet.webView.load(URLRequest(url: SceneDelegate.universalLinkToLaunch ?? SceneDelegate.shortcutLinkToLaunch ?? rootUrl))
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!){
        htmlIsLoaded = true
        
        self.setProgress(1.0, true)
        self.animateConnectionProblem(false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            FunkeWallet.webView.isHidden = false
            self.loadingView.isHidden = true
           
            self.setProgress(0.0, false)
            
            self.overrideUIStyle()
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        htmlIsLoaded = false;
        
        if (error as NSError)._code != (-999) {
            self.overrideUIStyle(toDefault: true);

            webView.isHidden = true;
            loadingView.isHidden = false;
            animateConnectionProblem(true);
            
            setProgress(0.05, true);

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.setProgress(0.1, true);
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.loadRootUrl();
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if (keyPath == #keyPath(WKWebView.estimatedProgress) &&
                FunkeWallet.webView.isLoading &&
                !self.loadingView.isHidden &&
                !self.htmlIsLoaded) {
                    var progress = Float(FunkeWallet.webView.estimatedProgress);
                    
                    if (progress >= 0.8) { progress = 1.0; };
                    if (progress >= 0.3) { self.animateConnectionProblem(false); }
                    
                    self.setProgress(progress, true);
        }
    }
    
    func setProgress(_ progress: Float, _ animated: Bool) {
        self.progressView.setProgress(progress, animated: animated);
    }
    
    
    func animateConnectionProblem(_ show: Bool) {
        if (show) {
            self.connectionProblemView.isHidden = false;
            self.connectionProblemView.alpha = 0
            UIView.animate(withDuration: 0.7, delay: 0, options: [.repeat, .autoreverse], animations: {
                self.connectionProblemView.alpha = 1
            })
        }
        else {
            UIView.animate(withDuration: 0.3, delay: 0, options: [], animations: {
                self.connectionProblemView.alpha = 0 // Here you will get the animation you want
            }, completion: { _ in
                self.connectionProblemView.isHidden = true;
                self.connectionProblemView.layer.removeAllAnimations();
            })
        }
    }
        
    deinit {
        FunkeWallet.webView.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
    }
}

extension UIColor {
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}

extension ViewController: WKScriptMessageHandler {
  func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "print" {
            printView(webView: FunkeWallet.webView)
        }
  }
}
