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
        
        @Published private(set) public var state: States = .finished
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

extension ET.Gaze {
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
        if self.state != .finished {
            self.kill()
            DispatchQueue.main.async {
                self.state = .finished
            }
        }
    }
}
