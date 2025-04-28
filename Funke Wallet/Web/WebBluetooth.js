//
//  WebBluetooth.js
//  Funke Wallet
//
//  Created by Benjamin Erhart on 28.04.25.
//


/**
 API definition:
 https://developer.mozilla.org/en-US/docs/Web/API/Web_Bluetooth_API

 Test page:
 https://webbluetoothcg.github.io/manual-tests/

 Interesting, but overly huge project to eventually copy stuff from:
 https://github.com/daphtdazz/WebBLE
 */
(function() {

    class BluetoothCharacteristicProperties {

        get authenticatedSignedWrites() {
            return false
        }

        get broadcast() {
            return false
        }

        get indicate() {
            return false
        }

        get notify() {
            return false
        }

        get read() {
            return false
        }

        get reliableWrite() {
            return false
        }

        get writableAuxiliaries() {
            return false
        }

        get write() {
            return false
        }

        get writeWithoutResponse() {
            return false
        }
    }

    class BluetoothRemoteGATTDescriptor {

        #characteristic;
        #value;

        constructor(characteristic) {
            this.#characteristic = characteristic;
            this.#value = undefined;
        }

        get characteristic() {
            return this.#characteristic
        }

        get uuid() {
            return this.#characteristic.uuid
        }

        get value() {
            return this.#value
        }

        async readValue() {
            return new ArrayBuffer(this.#value)
        }

        async writeValue(array) {
            this.#value = array
        }
    }

    class BluetoothRemoteGATTCharacteristic extends EventTarget {

        #service;
        #characteristic;
        #properties;
        #value;

        constructor(service, characteristic) {
            super();

            this.#service = service;
            this.#characteristic = characteristic;
            this.#properties = new BluetoothCharacteristicProperties();
            this.#value = new ArrayBuffer(16);
        }

        get service() {
            return this.#service
        }

        get uuid() {
            return this.#characteristic
        }

        get properties() {
            return this.#properties
        }

        get value() {
            return this.#value
        }

        async getDescriptor(bluetoothDescriptorUUID) {
            return new BluetoothRemoteGATTDescriptor(this)
        }

        async getDescriptors(bluetoothDescriptorUUID) {
            return [new BluetoothRemoteGATTDescriptor(this)]
        }

        async readValue() {
            return new DataView(this.value)
        }

        async writeValue(value) {
            if (Object.hasOwn(value, "buffer")) {
                this.#value = value.buffer
            }
            else {
                this.#value = value
            }
        }

        async writeValueWithResponse(value) {
            if (Object.hasOwn(value, "buffer")) {
                this.#value = value.buffer
            }
            else {
                this.#value = value
            }
        }

        async writeValueWithoutResponse(value) {
            if (Object.hasOwn(value, "buffer")) {
                this.#value = value.buffer
            }
            else {
                this.#value = value
            }
        }

        async startNotifications() {
            return this
        }

        async stopNotifications() {
            return this
        }
    }

    class BluetoothRemoteGATTService extends EventTarget {

        #device;
        #uuid;

        constructor(device, uuid) {
            super();

            this.#device = device;
            this.#uuid = uuid;
        }

        get device() {
            return this.#device
        }

        get isPrimary() {
            return true
        }

        get uuid() {
            return this.#uuid
        }

        async getCharacteristic(characteristic) {
            return new BluetoothRemoteGATTCharacteristic(this, characteristic)
        }

        async getCharacteristics(characteristics) {
            return [new BluetoothRemoteGATTCharacteristic(this, characteristics)]
        }
    }

    class BluetoothRemoteGATTServer {

        #device;
        #connected;

        constructor(device) {
            this.#device = device;
            this.#connected = false;
        }

        get connected() {
            return this.#connected
        }

        get device() {
            return this.#device
        }

        async connect() {
            this.#connected = true;

            return this
        }

        disconnect() {
            this.#connected = false
        }

        async getPrimaryService(bluetoothServiceUUID) {
            return new BluetoothRemoteGATTService(this.device, bluetoothServiceUUID)
        }

        async getPrimaryServices(bluetoothServiceUUID) {
            return [new BluetoothRemoteGATTService(this.device, bluetoothServiceUUID)]
        }
    }

    class BluetoothDevice extends EventTarget {

        get id() {
            return "" // UUID
        }

        get name() {
            return "todo" // Human-readable name
        }

        get gatt() {
            return new BluetoothRemoteGATTServer(this)
        }

        async watchAdvertisements() {
            return undefined
        }

        forget() {
        }
    }

    class Bluetooth extends EventTarget {

        async getAvailability() {
            return true
        }

        async getDevices() {
            return [new BluetoothDevice()]
        }

        async requestDevice(options) {
            return new BluetoothDevice()
        }
    }

    class BluetoothUUID {

        static canonicalUUID(alias) {
            return ""
        }

        static getCharacteristic(name) {
            throw new TypeError()
        }

        static getDescriptor(name) {
            throw new TypeError()
        }

        static getService(name) {
            throw new TypeError()
        }
    }

    navigator.bluetooth = new Bluetooth()

    window.BluetoothUUID = BluetoothUUID
})()
