Funke Wallet iOS Wrapper App
============================

An iOS native application wrapping `https://funke.wwwallet.org`. It is intended as a research project for the
SPRIND Funke competition for EUDI wallet prototypes.

Running
-------

You can install the iOS app by either [Building](#Building) it, or by requesting a TestFlight beta build.

Building
--------

To build the native iOS app, you'll need Xcode and an iOS18 device.

```shell
git clone git@github.com:gunet/wwwallet-ios-wrapper.git
```

```shell
cd wwwallet-ios-wrapper
```

```shell
xed .
```
Build and run the application on a physical iOS device

Demonstration
-------------
To fullly enjoy this application, you need to interact with an external Wallet Reader (verifier) to present the identity to the requesting verifier over BLE. There are two "Verifier" apps that you can interact with:

**Mattr GO Verifier** (iOS App Store) -- Download directly to another iOS device via the Apple App Store
https://apps.apple.com/us/app/mattr-go-verify/id6670461328

**mDOC Verifier** by EU Digital Identity Wallet (Android .apk) -- This requires an Android device and side-loading the downloaded apk
https://install.appcenter.ms/orgs/eu-digital-identity-wallet/apps/mdoc-verifier-testing/distribution_groups/eudi%20verifier%20(testing)%20public

Wrapping
--------

This iOS application "wraps" the https://funke.wwwallet.org/ website, providing direct interaction with Apple passkeys and Bluetooth communication with a external Wallet Reader (verifier). The wrapping happens by loading the website inside an iOS
native `WKWebView` and utilizes native Bluetooth libraries to perform local proximity presentment via Bluetooth Low Energy (BLE) following ISO/IEC 18013-5:2021 specifications.

Presentment
-----------

Presentment is the process of presenting a document to a verifying party: Think of it as presenting your eID at a police
checkup, a bar tender verifying your age, or to show your university diploma to a potential new employer. The wwwwalet
already provides online presentment. The following chapters are dedicated to explaining how the in person presentment works: How two phones can share
parts of documents securely while being close to each other.

### ISO-18013-5 - BLE Proximity

ISO-18013-5 allows several way how two mobile device can communicate: The verifying app ('Verifier') as the Bluetooth LE
server of the communication is called `MDoc Reader` and as contrast the `MDoc` mode establishes the Wallet as the server
of the Bluetooth LE server. Independently of the mode the communication is established in the server and the client
communicates through `Charactersitics` and `Services` in Bluetooth LE.

#### ISO/IEC 18013-5:2021 Libraries

This app utilizes the [EUDI iOS Data Transfer, Model, and Security libraries](https://github.com/eu-digital-identity-wallet/eudi-lib-ios-iso18013-data-transfer) that also follow the ISO/IEC 18013-5 standard.
