/*
 * Copyright (c) 2023 European Commission
 *
 * Licensed under the EUPL, Version 1.2 or - as soon they will be approved by the European
 * Commission - subsequent versions of the EUPL (the "Licence"); You may not use this work
 * except in compliance with the Licence.
 *
 * You may obtain a copy of the Licence at:
 * https://joinup.ec.europa.eu/software/page/eupl
 *
 * Unless required by applicable law or agreed to in writing, software distributed under
 * the Licence is distributed on an "AS IS" basis, WITHOUT WARRANTIES OR CONDITIONS OF
 * ANY KIND, either express or implied. See the Licence for the specific language
 * governing permissions and limitations under the Licence.
 */

import Foundation
import Combine
import UIKit
import EudiWalletKit
import MdocDataModel18013

public protocol ProximitySessionCoordinator: Sendable {

  var sendableCurrentValueSubject: SendableCurrentValueSubject<PresentationState> { get }

  init(session: PresentationSession)

  func initialize() async
  func startQrEngagement() async throws -> UIImage
  func requestReceived() async throws -> PresentationRequest
  func sendResponse(response: RequestItemConvertible) async

  func getState() async -> PresentationState
  func setState(presentationState: PresentationState)
  func getStream() -> AsyncStream<PresentationState>
  func stopPresentation()

}

final class ProximitySessionCoordinatorImpl: ProximitySessionCoordinator {

  let sendableCurrentValueSubject: SendableCurrentValueSubject<PresentationState> = .init(.loading)

  private let session: PresentationSession

  private let sendableAnyCancellable: SendableAnyCancellable = .init()

  init(session: PresentationSession) {
    self.session = session
    self.session.$status
      .sink { [weak self] status in
        guard let self else { return }
        switch status {
        case .qrEngagementReady:
          self.sendableCurrentValueSubject.setValue(.prepareQr)
        case .requestReceived:
          self.sendableCurrentValueSubject.setValue(.requestReceived(self.createRequest()))
        case .responseSent:
          self.sendableCurrentValueSubject.setValue(.responseSent(nil))
        case .error:
          if let error = session.uiError?.errorDescription {
            self.sendableCurrentValueSubject.setValue(.error(RuntimeError.customError(error)))
          } else {
            self.sendableCurrentValueSubject.setValue(.error(WalletCoreError.unableToPresentAndShare))
          }

        default:
          ()
        }
      }
      .store(in: &sendableAnyCancellable.cancellables)
  }

  deinit {
    stopPresentation()
  }

  public func initialize() async {
    await session.startQrEngagement()
    _ = await session.receiveRequest()
  }

  public func startQrEngagement() async throws -> UIImage {
    guard
      let deviceEngagement = session.deviceEngagement,
      let qrImage = DeviceEngagement.getQrCodeImage(qrCode: deviceEngagement),
      let qrImageData = qrImage.pngData()
    else {
      throw session.uiError ?? .init(description: "Failed To Generate QR Code")
    }
    self.sendableCurrentValueSubject.setValue(.qrReady(imageData: qrImageData))
    return qrImage
  }

  public func requestReceived() async throws -> PresentationRequest {
    guard session.disclosedDocuments.isEmpty == false else {
      throw session.uiError ?? .init(description: "Failed to Find knonw documents to send")
    }
    return createRequest()
  }

  public func sendResponse(response: RequestItemConvertible) async {
    await session.sendResponse(userAccepted: true, itemsToSend: response.asRequestItems())
  }

  public func getState() async -> PresentationState {
    self.sendableCurrentValueSubject.getValue()
  }

  public func setState(presentationState: PresentationState) {
    self.sendableCurrentValueSubject.setValue(presentationState)
  }

  func getStream() -> AsyncStream<PresentationState> {
    return sendableCurrentValueSubject.getSubject().toAsyncStream()
  }

  public func stopPresentation() {
    self.sendableCurrentValueSubject.getSubject().send(completion: .finished)
    sendableAnyCancellable.cancel()
  }

  private func createRequest() -> PresentationRequest {
    PresentationRequest(
      items: session.disclosedDocuments,
      relyingParty: session.readerCertIssuer ?? LocalizableString.shared.get(with: .unknownVerifier),
      dataRequestInfo: session.readerCertValidationMessage ?? LocalizableString.shared.get(with: .requestDataInfoNotice),
      isTrusted: session.readerCertIssuerValid == true
    )
  }
    
    
}

public struct PresentationRequest: Sendable {
  public let items: [DocElementsViewModel]
  public let relyingParty: String
  public let dataRequestInfo: String
  public let isTrusted: Bool
}

public enum PresentationState: Sendable {
  case loading
  case prepareQr
  case qrReady(imageData: Data)
  case requestReceived(PresentationRequest)
  case responseToSend(RequestItemConvertible)
  case responseSent(URL?)
  case error(Error)
}

public typealias RequestConvertibleItems = [String: [String: [String]]]

public protocol RequestItemConvertible: Sendable {
  func asRequestItems() -> RequestConvertibleItems
}

public struct RequestItemsWrapper: RequestItemConvertible {

  public var requestItems: RequestConvertibleItems

  public init() {
    requestItems = RequestConvertibleItems()
  }

  public init(dictionary: RequestConvertibleItems) {
    self.requestItems = dictionary
  }

  public func asRequestItems() -> RequestConvertibleItems {
    requestItems
  }
}

extension RequestItems: RequestItemConvertible {
  public func asRequestItems() -> RequestConvertibleItems {
    return self
  }
}

public final class SendableCurrentValueSubject<T: Sendable>: @unchecked Sendable {

  private let subject: CurrentValueSubject<T, Never>

  public init(_ defaultValue: T) {
    subject = .init(defaultValue)
  }

  public func getSubject() -> CurrentValueSubject<T, Never> {
    subject
  }

  public func setValue(_ value: T) {
    subject.value = value
  }

  public func getValue() -> T {
    subject.value
  }
}

public final class SendableAnyCancellable: @unchecked Sendable {

  public var cancellables: [AnyCancellable] = []

  public init() {}

  public func cancel() {
    cancellables.forEach { $0.cancel() }
  }
}

public enum RuntimeError: LocalizedError {

  case customError(String)
  case genericError

  public var errorDescription: String? {
    return switch self {
    case .customError(let message):
      message
    case .genericError:
      "genericError"
      //LocalizableString.shared.get(with: .genericErrorDesc)
    }
  }
}

public enum WalletCoreError: LocalizedError {
  case unableFetchDocuments
  case unableFetchDocument
  case missingPid
  case unableToIssueAndStore
  case transactionCodeFormat([String])
  case unableToPresentAndShare

  public var errorDescription: String? {
    return switch self {
    case .unableFetchDocuments:
      LocalizableString.shared.get(with: .errorUnableFetchDocuments)
    case .unableFetchDocument:
      LocalizableString.shared.get(with: .errorUnableFetchDocument)
    case .missingPid:
      LocalizableString.shared.get(with: .missingPid)
    case .unableToIssueAndStore:
      LocalizableString.shared.get(with: .unableToIssueAndStore)
    case .transactionCodeFormat(let args):
      LocalizableString.shared.get(with: .transactionCodeFormatError(args))
    case .unableToPresentAndShare:
      LocalizableString.shared.get(with: .unableToPresentAndShare)
    }
  }
}

public extension Publisher where Self.Failure == Never, Self.Output: Sendable {
  func toAsyncStream() -> AsyncStream<Self.Output> {
    return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in

      let cancellable = self.sink(
        receiveCompletion: { _ in
          Task {
            continuation.finish()
          }
        },
        receiveValue: { value in
          Task {
            _ = continuation.yield(value)
          }
        }
      )
      continuation.onTermination = { _ in
        cancellable.cancel()
      }
    }
  }
}
