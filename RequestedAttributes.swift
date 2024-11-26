//
//  RequestedAttributes.swift
//  Funke Wallet
//
//  Created by Dennis Hills on 11/24/24.
//
import Foundation

class RequestedAttributes {
    
    public static func parseData(_ data: [String: [String: [String]]]) -> [RequestedDocsFromVerifier] {
        var result: [RequestedDocsFromVerifier] = []
        
        for (docType, nameSpace) in data {
            for (nameSpace, attributes) in nameSpace {
                let parserObject = RequestedDocsFromVerifier(docType: docType, nameSpace: nameSpace, attributes: attributes)
                result.append(parserObject)
            }
        }
        
        return result
    }
}

struct RequestedDocsFromVerifier {
    let docType: String
    let nameSpace: String
    let attributes: [String]
}
