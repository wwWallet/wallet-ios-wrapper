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
To fullly enjoy this application, you need to interact with an external Wallet Reader (verifier) to present the identity to the requesting verifier over Bluetooth Low Energy (BLE). There are two "Verifier" apps that you can interact with:

**Mattr GO Verifier** (iOS App Store) -- Download directly to another iOS device via the Apple App Store
https://apps.apple.com/us/app/mattr-go-verify/id6670461328

**mDOC Verifier** by EU Digital Identity Wallet (Android .apk) -- This requires an Android device and side-loading this [Android apk](https://install.appcenter.ms/orgs/eu-digital-identity-wallet/apps/mdoc-verifier-testing/distribution_groups/eudi%20verifier%20(testing)%20public)

Wrapping
--------

This iOS application "wraps" the https://funke.wwwallet.org/ website, providing direct interaction with Apple passkeys and BLE communication with a external Wallet Reader (verifier). The wrapping happens by loading the website inside an iOS
native `WKWebView` and utilizes native Bluetooth libraries to perform local proximity presentment following ISO/IEC 18013-5:2021 specifications.

Presentment
-----------

Presentment is the process of presenting a document to a verifying party: Think of it as presenting your eID at a police
checkup, a bar tender verifying your age, or to show your university diploma to a potential new employer. The web-based Funke wwwallet
already provided online presentment. The new additions and the purpose of this app was to add offline and local in-person presentment of our identity between a Wallet and a Wallet Reader (verifier). That communication is achieved using Bluetooth.

#### ISO/IEC 18013-5:2021 Bluetooth Libraries

This app utilizes the [EUDI iOS Data Transfer, Model, and Security libraries](https://github.com/eu-digital-identity-wallet/eudi-lib-ios-iso18013-data-transfer) that also follow the ISO/IEC 18013-5 standard.
