//
//  Gaze.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import GRPC
import SwiftProtobuf

extension ET {
    /**
        The Gaze class provides a stream of gaze data directly from Skyle.
     */
    public class Gaze: ObservableObject {
        
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        internal var client: Skyle_SkyleClient?
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        /// The `state` property exposes a `Publisher` which indicates the state of the stream of gaze data.
        @Published private(set) public var state: States = .finished
        /// The `point` property exposes a `Publisher` which indicates the point of gaze.
        @Published private(set) public var point = Point(x: 0, y: 0)
        
        private var call: ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Point>?
        
        private func run() {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.call = client.gaze(Google_Protobuf_Empty()) { point in
                    DispatchQueue.main.async { [weak self] in
                        if self?.state != .running {
                            self?.state = .running
                        }
                        self?.point = Point(x: Double(point.x), y: Double(point.y))
                    }
                }
                
                self?.call?.status.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        DispatchQueue.main.async { [weak self] in
                            self?.state = .error(error)
                        }
                    case .success(let status):
                        if status.code != .ok && status.code != .cancelled {
                            DispatchQueue.main.async { [weak self] in
                                self?.state = .failed(status)
                            }
                        }
                        DispatchQueue.main.async { [weak self] in
                            if self?.state != .finished {
                                self?.state = .finished
                            }
                        }
                    }
                }
            }
        }
        
        private func kill() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                _ = self?.call?.cancel(promise: nil)
                do {
                    _ = try self?.call?.status.wait()
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.state = .error(error)
                    }
                }
            }
        }
        /// Simple cleanup stops the gRPC call by killing it.
        deinit {
            self.stop()
        }
    }
}

extension ET.Gaze {
    /// Starts a gaze stream asyncronously, updating the `state` and `point` properties.
    public func start() {
        guard self.state != .running && self.state != .connecting else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.state = .connecting
            self?.run()
        }
    }
    /// Stops a gaze stream asyncronously, updating the `state` property.
    public func stop() {
        guard self.state != .finished else {
            return
        }
        self.kill()
    }
}
