//
//  MjpegStream.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import CoreGraphics
import Combine
import GRPC
#if targetEnvironment(macCatalyst) || os(iOS)
import UIKit
#endif

extension ET {
    /**
        MjpegStream serves the video stream of Skyle.
     */
    public class MjpegStream: NSObject, URLSessionDelegate, URLSessionDataDelegate, ObservableObject {
        /// Empty initilizer
        public override init() {}
        /// Enum describing MjpegError
        // swiftlint:disable nesting
        internal enum MjpegStreamError: Error {
            case badResponse, parseImage
        }
        #if targetEnvironment(macCatalyst) || os(iOS)
        /// The `image` property exposes a `Publisher` which holds the current stream image.
        /// This is updated whenever a new image is available.
        @Published public var image: UIImage?
        #endif
        /// The `cgimage` property exposes a `Publisher` which holds the current stream image.
        /// This is updated whenever a new image is available.
        @Published public var cgimage: CGImage?
        
        private let startMarker: Data = Data([0xFF, 0xD8])
        private let endMarker: Data = Data([0xFF, 0xD9])
        
        private var buffer: Data = Data()
        
        private var session: URLSession {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 1
            return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        }
        private var task: URLSessionDataTask?
        /// The `state` property exposes a `Publisher` which indicates the state of the stream of gaze data.
        @Published private(set) public var state: States = .finished
        
        private var retry: Int = 10
        private let maxRetries: Int = 10
        /// This function is called when a retry occurs. `continue` needs to be called to actually continue with the retry.
        /// This is reset after each successful connection.
        /// Please set this before calling `start()`
        public var doBeforeRetry: ((_ continue: @escaping () -> Void) -> Void)?
        private var url = URL(string: "http://skyle.local:8080/?action=stream")!
        /**
            Starts a video stream by calling on the provided URL.
            - Parameters:
                - url: A `URL` pointing to the streams origin.
                - retries: Maximum of retries.
         */
        public func start(_ url: URL = URL(string: "http://skyle.local:8080/?action=stream")!) {
            guard self.state != .running else {
                return
            }
            self.url = url
            self.retry = self.maxRetries
            DispatchQueue.main.async {
                self.state = .connecting
            }
            DispatchQueue.global(qos: .utility).async {
                self.task = self.session.dataTask(with: url)
                self.task?.resume()
            }
        }
        /// Stops the video stream and updating `state`.
        public func stop() {
            guard self.state != .finished else {
                return
            }
            self.task?.cancel()
            self.task = nil
            
            self.buffer = Data()
            
            self.session.invalidateAndCancel()
            
            DispatchQueue.main.async {
                self.state = .finished
                #if targetEnvironment(macCatalyst) || os(iOS)
                self.image = nil
                #endif
                self.cgimage = nil
            }
        }
        
        // MARK: Session Delegates
        /// Session Delegate implementation.
        public func urlSession(_ session: URLSession,
                               dataTask: URLSessionDataTask,
                               didReceive response: URLResponse,
                               completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                completionHandler(.cancel)
                return
            }
            completionHandler(.allow)
        }
        /// Session Delegate implementation.
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let response = dataTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                return
            }
            if self.doBeforeRetry != nil {
                self.doBeforeRetry = nil
            }
            if data.range(of: self.startMarker) != nil {
                self.buffer = Data()
            }
            self.buffer.append(data)
            
            if data.range(of: self.endMarker) != nil {
                self.parseFrame(self.buffer)
            }
        }
        /// Session Delegate implementation.
        public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            // THIS IS CALLED WHEN CANCELLING THE SESSION
            //print("Did become invalid with error")
        }
        /// Session Delegate implementation.
        public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
            // THIS MIGHT BE USED BUT NOT CURRENTLY SINCE I DON'T REALLY KNOW HOW TO CONFIGURE THIS CORRECTLY
            // ALSO THE MANUAL RETRY WORKS I GUESS
            //print("Task is waiting for connectivity")
        }
        /// Session Delegate implementation.
        public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                if let nserror = error as NSError? {
                    if nserror.domain == URLError.errorDomain {
                        if nserror.code == URLError.timedOut.rawValue || nserror.code == URLError.cannotConnectToHost.rawValue {
                            if self.retry == 0 {
                                self.retry = self.maxRetries
                                DispatchQueue.main.async {
                                    self.state = .failed(GRPCStatus(code: .unavailable, message: nil))
                                }
                                self.stop()
                                return
                            }
                            self.retry -= 1
                            if let doBeforeRetry = self.doBeforeRetry {
                                doBeforeRetry() {
                                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                                        task.cancel()
                                        self.task = self.session.dataTask(with: self.url)
                                        self.task?.resume()
                                    }
                                }
                            } else {
                                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.3) {
                                    task.cancel()
                                    self.task = self.session.dataTask(with: self.url)
                                    self.task?.resume()
                                }
                            }
                            return
                        } else if nserror.code == URLError.cancelled.rawValue {
                            // Stopped manually
                            return
                        } else {
                            // Stopped by unplugging Skyle for example
                            self.stop()
                            return
                        }
                    }
                }
            } else {
                // error == nil -> reset everything.
                self.stop()
            }
        }
        
        private func parseFrame(_ data: Data) {
            guard let imgProvider = CGDataProvider.init(data: data as CFData) else {
                return
            }
            guard let image = CGImage.init(jpegDataProviderSource: imgProvider,
                                           decode: nil,
                                           shouldInterpolate: true,
                                           intent: CGColorRenderingIntent.defaultIntent) else {
                return
            }
            #if targetEnvironment(macCatalyst) || os(iOS)
            let uiimage = UIImage(cgImage: image)
            #endif
            DispatchQueue.main.async {
                #if targetEnvironment(macCatalyst) || os(iOS)
                self.image = uiimage
                #endif
                self.cgimage = image
                if self.state != .running {
                    self.state = .running
                }
            }
        }
    }
}
