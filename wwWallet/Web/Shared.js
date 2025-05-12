//
//  Shared.js
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-13.
//

const stringifyBinary = (key, value) => {
    if (value instanceof Uint8Array) {
        return CM_base64url_encode(value);
    }
    else if (value instanceof ArrayBuffer) {
        return CM_base64url_encode(new Uint8Array(value));
    }
    else {
        return value;
    }
};

const stringify = (data) => {
    return JSON.stringify(data, stringifyBinary);
};

function CM_base64url_decode(value) {
    var m = value.length % 4;

    return Uint8Array.from(atob(value.replace(/-/g, '+')
                                .replace(/_/g, '/')
                                .padEnd(value.length + (m === 0 ? 0 : 4 - m), '=')),
                           function (c) { return c.charCodeAt(0); }).buffer;
}

function CM_base64url_encode(uint8array) {
    return btoa(Array.from(
                           uint8array,
                           function (b) { return String.fromCharCode(b); })
                .join(''))
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+${'$'}/, '');
}
