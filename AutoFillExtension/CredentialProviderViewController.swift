//
//  CredentialProviderViewController.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 12.05.25.
//

import AuthenticationServices

class CredentialProviderViewController: ASCredentialProviderViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: Outlets

    @IBOutlet weak var headlineLb: UILabel!
    @IBOutlet weak var relyingPartyLb: UILabel!

    @IBOutlet weak var registrationContainer: UIView!
    @IBOutlet weak var nameTf: UITextField!
    @IBOutlet weak var createBt: UIButton!

    @IBOutlet weak var attestationContainer: UIView!
    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var lockedContainer: UIView!
    @IBOutlet weak var lockedMessage: UILabel! {
        didSet {
            lockedMessage.text = NSLocalizedString("Please unlock wallet first!", comment: "")
        }
    }


    // MARK: Private Properties

    private var privateKeys = [Passkey]()

    private var relyingPartyId = ""
    private var clientDataHash = Data()
    private var wantsUserVerification = false

    private var identity: ASPasskeyCredentialIdentity?


    // MARK: ASCredentialProviderViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier], requestParameters: ASPasskeyCredentialRequestParameters) {
        headlineLb.text = NSLocalizedString("Log In to", comment: "")
        relyingPartyLb.text = relyingPartyId

        if Lock.isLocked {
            attestationContainer.isHidden = true
            registrationContainer.isHidden = true
            lockedContainer.isHidden = false

            return
        }

        relyingPartyId = requestParameters.relyingPartyIdentifier
        clientDataHash = requestParameters.clientDataHash
        wantsUserVerification = requestParameters.userVerificationPreference != .discouraged

        privateKeys = serviceIdentifiers.flatMap {
            Passkeys.shared.getPasskeys(for: $0.identifier)
        }

        privateKeys.append(contentsOf: Passkeys.shared.getPasskeys(for: relyingPartyId))

        privateKeys.removeAll { !requestParameters.allowedCredentials.contains($0.keyId) }

        attestationContainer.isHidden = false
        registrationContainer.isHidden = true
        lockedContainer.isHidden = true

        tableView.reloadData()
    }

    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        do {
            headlineLb.text = NSLocalizedString("Create Passkey for", comment: "")
            relyingPartyLb.text = relyingPartyId

            if Lock.isLocked {
                attestationContainer.isHidden = true
                registrationContainer.isHidden = true
                lockedContainer.isHidden = false

                return
            }

            guard registrationRequest.type == .passkeyRegistration,
                  let request = registrationRequest as? ASPasskeyCredentialRequest,
                  let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity,
                  request.supportedAlgorithms.contains(.ES256)
            else {
                throw getError()
            }

            for id in request.excludedCredentials ?? [] {
                do {
                    _ = try SecureEnclave.loadPrivateKey(tag: id.credentialID)
                }
                catch {
                    throw getError(code: .matchedExcludedCredential)
                }
            }

            relyingPartyId = identity.relyingPartyIdentifier
            clientDataHash = request.clientDataHash
            wantsUserVerification = request.userVerificationPreference != .discouraged
            self.identity = identity

            registrationContainer.isHidden = false
            nameTf.text = identity.userName
            textFieldDidChange(nameTf)
            attestationContainer.isHidden = true
            lockedContainer.isHidden = true

//            try SecureEnclave.removeAllPrivateKeys()
        }
        catch {
            extensionContext.cancelRequest(withError: getError(original: error))
        }
    }


    // MARK: Actions

    @IBAction func cancel(_ sender: AnyObject?) {
        extensionContext.cancelRequest(withError: getError(code: .userCanceled))
    }

    @IBAction func create() {
        guard createBt.isEnabled else {
            return
        }

        do {
            let credentialId = UUID()

            let privateKey = try SecureEnclave.createPrivateKey(
                tag: credentialId,
                userVerification: wantsUserVerification)

            let credential: ASPasskeyRegistrationCredential

            do {
                try Passkeys.shared.storePasskey(
                    relyingPartyId: relyingPartyId,
                    label: nameTf.text ?? "Unnamed Key for \(relyingPartyId)",
                    keyId: credentialId.data,
                    userHandle: identity?.userHandle ?? .init(),
                    userVerified: wantsUserVerification)

                var flags = try AuthenticatorDataFlags()
                flags.BE = true // Creation will fail if this flag is not set.
                flags.BS = true // Creation will fail if this flag is not set.
                flags.UV = wantsUserVerification

                credential = try Attestation.createRegistrationCredential(
                    credentialId: credentialId.data,
                    privateKey: privateKey,
                    rpId: relyingPartyId, clientDataHash: clientDataHash, flags: flags)

            }
            catch {
                try? SecureEnclave.removePrivateKey(tag: credentialId.data)

                throw error
            }

            let fb2 = credential.attestationObject.base64EncodedString()
            print("[\(String(describing: type(of: self)))] attestationObject=\(fb2)")

            extensionContext.completeRegistrationRequest(using: credential)
        }
        catch {
            extensionContext.cancelRequest(withError: getError(original: error))
        }
    }

    @IBAction func textFieldDidChange(_ textField: UITextField) {
        createBt.isEnabled = !(nameTf.text?.isEmpty ?? true)
    }


    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        privateKeys.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "keyCell") ?? .init(style: .subtitle, reuseIdentifier: "keyCell")

        let key = privateKeys[indexPath.row]

        cell.textLabel?.text = key.label
        cell.detailTextLabel?.text = "\(relyingPartyId) \(key.keyIdString ?? "")"

        return cell
    }


    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let passkey = privateKeys[indexPath.row]

        do {
            var flags = try AuthenticatorDataFlags()
            flags.BE = true
            flags.BS = true
            flags.UV = passkey.userVerified

            let assertion = try Assertion.makeAssertionCredential(
                rpId: relyingPartyId,
                flags: flags,
                passkey: passkey,
                clientDataHash: clientDataHash)

            extensionContext.completeAssertionRequest(using: assertion)
        }
        catch {
            extensionContext.cancelRequest(withError: getError(original: error))
        }
    }


    // MARK: Private Methods

    /**
     As per docs, the returned error should be of domain ASExtensionErrorDomain
     */
    private func getError(code: ASExtensionError.Code = .failed, original error: Error? = nil) -> NSError {
        // As per docs, the returned error should be of domain ASExtensionErrorDomain
        if let error = error as? NSError, error.domain == ASExtensionErrorDomain {
            return error
        }

        return NSError(domain: ASExtensionErrorDomain, code: code.rawValue)
    }
}
