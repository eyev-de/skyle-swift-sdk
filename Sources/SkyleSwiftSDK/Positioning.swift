//
//  Positioning.swift
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
        Positioning exposes `Publisher` which stream the current position of the users eyes,
        quality indicators and if the user is present.
     */
    public class Positioning: ObservableObject {
        /// The width in pixels of the delivered image (guidance)
        public static let Width: Double = 1280
        /// The height in pixels of the delivered image (guidance)
        public static let Height: Double = 720
        
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        internal var client: Skyle_SkyleClient?
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        /// The `state` property exposes a `Publisher` which indicates the state of the stream of positioning data.
        @Published private(set) public var state: States = .finished
        /// The `position` property exposes a `Publisher` which indicates the position of the users eyes.
        @Published private(set) public var position: (left: Point, right: Point) = (Point(x: 0, y: 0), Point(x: 0, y: 0))
        /// The `isPresent` property exposes a `Publisher` which indicates if a user is present.
        /// This is updated with one second of delay to smooth out small detection errors.
        @Published private(set) public var isPresent: Bool = false
        /// The `qualityDepth` property exposes a `Publisher` which indicates the quality of the distance of the user.
        /// Ranges from `-50` to `50` with `0` indicating the optimal value.
        @Published private(set) public var qualityDepth: Int = 0
        /// The `qualityDepth` property exposes a `Publisher` which indicates the quality of the horizontal
        /// and vertical position of the user.
        /// Ranges from `-50` to `50` with `0` indicating the optimal value.
        @Published private(set) public var qualitySides: Int = 0
        
        private var timer: Timer!
        
        private var call: ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_PositioningMessage>?
        
        private func run() {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.call = client.positioning(Google_Protobuf_Empty()) { position in
                    DispatchQueue.main.async { [weak self] in
                        if self?.state != .running {
                            self?.state = .running
                        }
                        self?.isPresent = true
                        if self?.timer != nil {
                            self?.timer.invalidate()
                        }
                        self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                            self?.isPresent = false
                        }
                        self?.qualityDepth = Int(position.qualityDepth)
                        self?.qualitySides = Int(position.qualitySides)
                        let leftEye = position.hasLeftEye ?
                            Point(x: Double(position.leftEye.x), y: Double(position.leftEye.y)) : Point(x: 0, y: 0)
                        let rightEye = position.hasRightEye ?
                            Point(x: Double(position.rightEye.x), y: Double(position.rightEye.y)) : Point(x: 0, y: 0)
                        self?.position = (leftEye, rightEye)
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
                _ = self?.call?.cancel()
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

extension ET.Positioning {
    /// Starts a gaze stream asyncronously, updating the `state`, `position`, `qualitySides`, `qualityDepth` and `isPresent` properties.
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
