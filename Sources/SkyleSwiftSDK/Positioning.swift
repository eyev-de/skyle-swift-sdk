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
    public class Positioning: ObservableObject {
        
        public static let Width: Double = 1280
        public static let Height: Double = 720
        
        var client: Skyle_SkyleClient? = nil
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        @Published private(set) public var state: States = .finished
        @Published private(set) public var position: (left: Point, right: Point) = (Point(x: 0, y: 0), Point(x: 0, y: 0))
        @Published private(set) public var isPresent: Bool = false
        @Published private(set) public var qualityDepth: Int = 0
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
                        self?.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
                            self?.isPresent = false
                        }
                        self?.qualityDepth = Int(position.qualityDepth)
                        self?.qualitySides = Int(position.qualitySides)
                        let leftEye = position.hasLeftEye ? Point(x: Double(position.leftEye.x), y: Double(position.leftEye.y)) : Point(x: 0, y: 0)
                        let rightEye = position.hasRightEye ? Point(x: Double(position.rightEye.x), y: Double(position.rightEye.y)) : Point(x: 0, y: 0)
                        self?.position = (leftEye, rightEye)
                    }
                }
                
                self?.call?.status.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        DispatchQueue.main.async { [weak self] in
                            self?.state = .error(error)
                        }
                        break
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
                        break
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
        
        deinit {
            self.stop()
        }
        
    }
}

extension ET.Positioning {
    public func start() {
        guard self.state != .running && self.state != .connecting else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.state = .connecting
            self?.run()
        }
    }
    
    public func stop() {
        guard self.state != .finished else {
            return
        }
        self.kill()
    }
}
