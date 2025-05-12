//
//  NativeWrapper.js
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-13.
//

window.nativeWrapper = (function (nativeWrapper) {
    console.log("Initializing nativeWrapper");

    function createBluetoothMethod(funcName) {
        nativeWrapper[funcName] = function (arg) {
            console.log("NativeWrapper, ", funcName, arg);

            return window.webkit.messageHandlers['__' + funcName + '__']
            .postMessage(stringify(arg))
            .then(function (msg) {
                console.log(funcName, "raw result:", msg);

                var reply = JSON.parse(msg);
                console.log(funcName, "result:", reply);

                return reply;
              })
              .catch(
                  function (err) {
                      console.log("error: ", err);
                      throw err;
                  }
              );
        };
    }

    createBluetoothMethod('bluetoothStatus');
    createBluetoothMethod('bluetoothTerminate');
    createBluetoothMethod('bluetoothCreateServer');
    createBluetoothMethod('bluetoothCreateClient');
    createBluetoothMethod('bluetoothSendToServer');
    createBluetoothMethod('bluetoothSendToClient');
    createBluetoothMethod('bluetoothReceiveFromClient');
    createBluetoothMethod('bluetoothReceiveFromServer');

    console.log("nativeWrapper initialized");

    return nativeWrapper;
})({});
