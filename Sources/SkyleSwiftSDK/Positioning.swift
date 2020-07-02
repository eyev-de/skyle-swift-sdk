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
        
        @Published private(set) public var state: State = .finished
        @Published private(set) public var position: (left: Point, right: Point) = (Point(x: 0, y: 0), Point(x: 0, y: 0))
        @Published private(set) public var isPresent: Bool = false
        
        private var timer: Timer!
        
        private var call: ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_PositioningMessage>?
        
        private func run() {
            DispatchQueue.global().async {
                guard let client = self.client else {
                    return
                }
                self.call = client.positioning(Google_Protobuf_Empty()) { position in
                    DispatchQueue.main.async {
                        if self.state != .running {
                            self.state = .running
                        }
                        self.isPresent = true
                        if self.timer != nil {
                            self.timer.invalidate()
                        }
                        self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
                            self.isPresent = false
                        }
                        let leftEye = position.hasLeftEye ? Point(x: Double(position.leftEye.x), y: Double(position.leftEye.y)) : Point(x: 0, y: 0)
                        let rightEye = position.hasRightEye ? Point(x: Double(position.rightEye.x), y: Double(position.rightEye.y)) : Point(x: 0, y: 0)
                        self.position = (leftEye, rightEye)
                    }
                }
                
                self.call?.status.whenSuccess { status in
                    if status.code == .ok {
                    } else {
                        DispatchQueue.main.async {
                            self.state = .failed(status)
                        }
                    }
                    DispatchQueue.main.async {
                        self.state = .finished
                    }
                }
            }
        }
        
        private func kill() {
            DispatchQueue.global().async {
                _ = self.call?.cancel()
                do {
                    _ = try self.call?.status.wait()
                } catch {
                    print(error)
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
        if self.state != .running && self.state != .connecting {
            DispatchQueue.main.async {
                self.state = .connecting
            }
            DispatchQueue.global().async {
                self.run()
            }
        }
    }
    public func stop() {
        if self.state != .finished {
            self.kill()
            DispatchQueue.main.async {
                self.state = .finished
            }
        }
    }
}
