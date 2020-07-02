//
//  Gaze.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import CombineGRPC
import GRPC
import SwiftProtobuf

extension ET {
    public class Gaze: ObservableObject {
        
        var client: Skyle_SkyleClient? = nil
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        @Published private(set) public var state: State = .none
        @Published private(set) public var point = Point(x: 0, y: 0)
        
        private var call: ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Point>?
        
        private func run() {
            guard let client = self.client else {
                return
            }
            self.call = client.gaze(Google_Protobuf_Empty()) { point in
                DispatchQueue.main.async {
                    if self.state != .running {
                        self.state = .running
                    }
                    self.point = Point(x: Double(point.x), y: Double(point.y))
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

extension ET.Gaze {
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
