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


    // MARK: Private Properties

    private var privateKeys = [Passkey]()

    private var relyingPartyId = ""
    private var clientDataHash = Data()
    private var forceUserVerification = false

    private var identity: ASPasskeyCredentialIdentity?


    // MARK: ASCredentialProviderViewController

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark
    }


    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the list.
     */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        privateKeys = serviceIdentifiers.flatMap {
            Passkeys.shared.getPasskeys(for: $0.identifier)
        }
    }

    override func prepareInterface(forPasskeyRegistration registrationRequest: any ASCredentialRequest) {
        do {
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
            forceUserVerification = request.userVerificationPreference == .required
            self.identity = identity

            headlineLb.text = NSLocalizedString("Create Passkey for", comment: "")
            relyingPartyLb.text = relyingPartyId
            registrationContainer.isHidden = false
            nameTf.text = identity.userName
            textFieldDidChange(nameTf)
            attestationContainer.isHidden = true
        }
        catch {
            extensionContext.cancelRequest(withError: getError(original: error))
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        do {
            guard credentialRequest.type == .passkeyAssertion,
                  let request = credentialRequest as? ASPasskeyCredentialRequest,
                  let identity = request.credentialIdentity as? ASPasskeyCredentialIdentity,
                  request.supportedAlgorithms.contains(.ES256)
            else {
                throw getError()
            }

            relyingPartyId = identity.relyingPartyIdentifier
            clientDataHash = request.clientDataHash
            forceUserVerification = request.userVerificationPreference == .required
            self.identity = identity

            headlineLb.text = NSLocalizedString("Log In to", comment: "")
            relyingPartyLb.text = relyingPartyId
            registrationContainer.isHidden = true
            attestationContainer.isHidden = false

            if !privateKeys.contains(where: { $0.keyId == identity.credentialID }) {
                privateKeys.append(contentsOf: Passkeys.shared.getPasskeys(for: relyingPartyId))
            }

            privateKeys.removeAll { it in
                request.excludedCredentials?.contains(where: {
                    $0.credentialID == it.keyId
                }) ?? false
            }
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
                userVerification: forceUserVerification)

            let credential: ASPasskeyRegistrationCredential

            do {
                try Passkeys.shared.storePasskey(
                    relyingPartyId: relyingPartyId,
                    label: nameTf.text ?? "Unnamed Key for \(relyingPartyId)",
                    keyId: credentialId.data)

                var flags = try AuthenticatorDataFlags()
                flags.BE = true

                if forceUserVerification {
                    flags.UV = true
                }

                credential = try Attestation.shared.createRegistrationCredential(
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
        let key = privateKeys[indexPath.row]

        let passkey = ASPasskeyAssertionCredential(
            userHandle: identity?.userHandle ?? Data(),
            relyingParty: relyingPartyId,
            signature: .init(),
            clientDataHash: clientDataHash,
            authenticatorData: .init(),
            credentialID: key.keyId)

        extensionContext.completeAssertionRequest(using: passkey)
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
