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
    public class MjpegStream: NSObject, URLSessionDelegate, URLSessionDataDelegate, ObservableObject {
        
        public override init() {}
        
        enum MjpegStreamError: Error {
            case badResponse, parseImage
        }
        #if targetEnvironment(macCatalyst) || os(iOS)
        @Published public var image: UIImage? = nil
        #endif
        
        @Published public var cgimage: CGImage? = nil
        
        let startMarker: Data = Data([0xFF, 0xD8])
        let endMarker: Data = Data([0xFF, 0xD9])
        
        var buffer: Data = Data()
        
        private var session: URLSession?
        var task: URLSessionDataTask?
        
        @Published private(set) public var state: State = .finished
        
        private var retry: Int = 3
        
        public func start(_ url: URL = URL(string: "http://skyle.local:8080/?action=stream")!) {
            guard self.state != .running else {
                return
            }
            self.retry = 3
            DispatchQueue.main.async {
                self.state = .connecting
            }
            DispatchQueue.global(qos: .utility).async {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 1
                self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.task = self.session?.dataTask(with: url)
                self.task?.resume()
            }
        }
        
        public func stop() {
            guard self.state != .finished else {
                return
            }
            self.task?.cancel()
            self.task = nil
            
            self.buffer = Data()
            
            self.session?.invalidateAndCancel()
            self.session = nil
            
            DispatchQueue.main.async {
                self.state = .finished
                #if targetEnvironment(macCatalyst) || os(iOS)
                self.image = nil
                #endif
                self.cgimage = nil
            }
        }
        
        // MARK: Session Delegates
        
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                completionHandler(.cancel)
                return
            }
            completionHandler(.allow)
        }
        
        public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            guard let response = dataTask.response as? HTTPURLResponse, response.statusCode == 200 else {
                return
            }
            if data.range(of: self.startMarker) != nil {
                self.buffer = Data()
            }
            self.buffer.append(data)
            
            if data.range(of: self.endMarker) != nil {
                self.parseFrame(self.buffer)
            }
        }
        
        public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
            //print("Did become invalid with error")
        }
        
        public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
            //print("Task is waiting for connectivity")
        }
        
        public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                if let nserror = error as NSError? {
                    if nserror.domain == URLError.errorDomain {
                        if nserror.code == URLError.timedOut.rawValue {
                            if self.retry < 0 {
                                self.retry = 3
                                DispatchQueue.main.async {
                                    self.state = .failed(GRPCStatus(code: .unavailable, message: nil))
                                }
                                return
                            }
                            self.retry -= 1
                            DispatchQueue.global(qos: .utility).async {
                                let configuration = URLSessionConfiguration.ephemeral
                                configuration.timeoutIntervalForRequest = 1
                                self.session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                                self.task?.cancel()
                                self.task = nil
                                self.task = self.session?.dataTask(with: (task.currentRequest?.url)!)
                                self.task?.resume()
                            }
                        } else if nserror.code == URLError.cancelled.rawValue {
                            // stopped manually
                        } else {
                            self.stop()
                        }
                    }
                }
            }
            
        }
        
        private func parseFrame(_ data: Data) {
            guard let imgProvider = CGDataProvider.init(data: data as CFData) else {
                return
            }
            guard let image = CGImage.init(jpegDataProviderSource: imgProvider, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent) else {
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