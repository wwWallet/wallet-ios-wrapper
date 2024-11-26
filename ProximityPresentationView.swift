//
//  MySwiftUIView.swift
//  Funke Wallet
//
//  Created by Dennis Hills on 11/18/24.
//
import SwiftUI
import MdocDataTransfer18013
import MdocDataModel18013
import Foundation
import CoreImage.CIFilterBuiltins // for QR Code

struct ProximityPresentationView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var proximityPresentationViewModel: ProximityPresentationViewModel
    
    var body: some View {
        VStack {
            Text("18013-5 BLE Presentation")
                .font(.title)
                .padding()
            
            QRCodeView(qrCodeText: proximityPresentationViewModel.payloadStr)
            
            Button(action: {
                presentationMode.wrappedValue.dismiss() // Dismiss the view
            }) {
                Text("Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .task {
            beginEngagement()
            //await performAsyncTask()
        }
    }
    
    /*
     
     mdoc:owBjMS4wAYIB2BhYS6QgAQECIVggSxiiGTKv45GbVHYryfKjPBnMhqazZf5zyZo1pe_J3VQiWCBnqqjnag2w0rWzkuYYmnlfVIc5jtOKtYl2m5_AfQDRLgKBgwIBowD1AfQKUAAArfsAABAAgAAAgF-bNPs
    */
    func generateQRCodePayload() -> String {
        
        // isBLeServer: True --> BLE mdoc peripheral server mode
        // crv: .p256 --> The EC curve type used in the mdoc ephemeral private key
        var de = DeviceEngagement(isBleServer: true, crv: .p256)
        return de.getQrCodePayload()
    }
    
    ////
    ///document_data --> Array of documents Base64-serialized
    ///trusted_certificates --> Array of trusted certificates of reader (verifier) authentication
    ///require_user_accept --> True if holder acceptance is required to send the requested data to verifier
    func beginEngagement() {
        
        //var de = DeviceEngagement(isBleServer: true, crv: .p256)
        
//        do {
//            
//            let gattServer = try MdocGattServer(parameters: getMdocGattServerParams())
//            gattServer.performDeviceEngagement()
//            print("isBlePermitted:")
//            print(gattServer.isBlePermissionDenied)
//            //gattServer.performDeviceEngagement(rfus: [de.getQrCodePayload()])
//            
//            
//            } catch {
//                print("error engaging")
//            }
//        }
        
    }
    
    /// Called when the view loads.
    func performAsyncTask() async {
        // let deviceEngagement = session.deviceEngagement
        
        do {
            //let eudiWallet = try EudiWallet.init()
            var de = DeviceEngagement(isBleServer: true, crv: .p256)
            // get a string payload
            var qrCodePayload = de.getQrCodePayload()
            // get a UIKit image
            
            
            //let docs = try await eudiWallet.loadAllDocuments()
            var dd = DeviceEngagement(isBleServer: true)
            print(dd.getQrCodePayload())
            
            //            let bleSession = await eudiWallet.beginPresentation(flow: .ble)
            //let xxx = try await bleSession.presentationService.startQrEngagement()
            
            //let proxy = ProximitySessionCoordinatorImpl(session: bleSession)
            //let xxx = try await proxy.startQrEngagement()
            //            let qrImageData = xxx.pngData()
            //print(bleSession)
            //            let blePresentationSession = await eudiWallet.beginPresentation(flow: .ble)
            //            guard let deviceEngagement = blePresentationSession.deviceEngagement else {
            //                print("deviceEngagement is nil")
            //                return
            //            }
            //            let qrImage = DeviceEngagement.getQrCodeImage(qrCode: deviceEngagement)
            //            let qrImageData = qrImage?.pngData()
            //let xxx = await blePresentationSession.startQrEngagement()
            //let xxx = try await blePresentationSession.presentationService.startQrEngagement()
            //print(xxx)
            //await bleSession.startQrEngagement()
        } catch {
            // catch something here
        }
    }
}

struct QRCodeView: View {
   let qrCodeText: String
   let qrCodeSize: CGFloat = 200

   var body: some View {
       if let qrCodeImage = generateQRCode(from: qrCodeText) {
           Image(uiImage: qrCodeImage)
               .interpolation(.none) // Ensure sharp rendering
               .resizable()
               .frame(width: qrCodeSize, height: qrCodeSize)
               .background(Color.white) // Optional: Background for better visibility
       } else {
           Text("Unable to generate QR Code")
               .foregroundColor(.red)
       }
   }

   private func generateQRCode(from string: String) -> UIImage? {
       let filter = CIFilter.qrCodeGenerator()
       filter.message = Data(string.utf8)

       if let outputImage = filter.outputImage {
           let transform = CGAffineTransform(scaleX: 10, y: 10) // Scale to make it high-res
           let scaledImage = outputImage.transformed(by: transform)

           let context = CIContext()
           if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
               return UIImage(cgImage: cgImage)
           }
       }
       return nil
   }
}
                       
// Optional: Preview
struct ProximityPresentationView_Previews: PreviewProvider {
    static var previews: some View {
        
        // Create a sample view model for the preview
        let sampleProximityPresentationViewModel = ProximityPresentationViewModel()
        ProximityPresentationView(proximityPresentationViewModel: sampleProximityPresentationViewModel)
    }
}

class ProximityPresentationViewModel: ObservableObject {
    @Published private(set) var bleServer: MdocGattServer?
    
    var payloadStr: String = ""
    
    @discardableResult
    func getQRCodePayload(contentStr: String) {
        self.payloadStr = contentStr
    }
    
    @discardableResult
    func generateQRCode(from string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10) // Scale to make it high-res
            let scaledImage = outputImage.transformed(by: transform)

            let context = CIContext()
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }
        return nil
    }
}
