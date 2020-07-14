//
//  Calibration.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import GRPC

//extension Skyle_calibControlMessages: Codable {
//    private enum CodingKeys: String, CodingKey {
//        case id, name, skill
//    }
//
//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        self.id = try container.decode(Int32.self, forKey: .id)
//        self.name = try container.decode(String.self, forKey: .name)
//        self.skill = try container.decode(Skyle_calibControlMessages.Skill.self, forKey: .skill)
//    }
//
//    public func encode(to encoder: Encoder) throws {
//
//    }
//}

extension ET {
    public class Calibration: ObservableObject {
        
        var client: Skyle_SkyleClient? = nil
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }

        public struct Points {
            public static let Five = [0, 2, 4, 6, 8]
            public static let Nine = [0, 1, 2, 3, 4, 5, 6, 7, 8]
        }
        
        @Published private(set) public var type: [Int] = Points.Nine
        @Published private(set) public var state: State = .none
        @Published private(set) public var control: Skyle_calibControlMessages = Skyle_calibControlMessages()
        @Published private(set) public var point = Point(x: 0, y: 0)
        @Published private(set) public var currentPoint = 0
        @Published private(set) public var quality = 0.0
        @Published private(set) public var qualities: [Double] = []
        
        private var call: BidirectionalStreamingCall<Skyle_calibControlMessages, Skyle_CalibMessages>?
        private var cancellable: AnyCancellable?
                
        private func run() {
            DispatchQueue.global().async {
                guard let client = self.client else {
                    return
                }
                self.call = client.calibrate { calib in
                    switch calib.message {
                    case .calibControl(let control):
                        DispatchQueue.main.async {
                            if !control.calibrate {
                                if self.state != .finished {
                                    self.state = .finished
                                }
                            }
                        }
                        break
                    case .calibPoint(let point):
                        DispatchQueue.main.async {
                            self.currentPoint = Int(point.count)
                            self.point = SkyleSwiftSDK.Point(x: Double(point.currentPoint.x), y: Double(point.currentPoint.y))
                        }
                        break
                    case.calibQuality(let quality):
                        DispatchQueue.main.async {
                            self.quality = quality.quality
                            self.qualities = quality.qualitys
                        }
                        break
                    case .none:
                        break
                    }
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
                    if self.state != .none {
                        self.state = .none
                    }
                }
            }
            
            self.cancellable = self.$control.sink(receiveValue: { control in
                _ = self.call?.sendMessage(control)
            })
        }
        
        private func kill() {
            DispatchQueue.global().async { [weak self] in
                _ = self?.call?.sendEnd()
                _ = self?.call?.cancel()
                do {
                    _ = try self?.call?.status.wait()
                } catch {
                    print(error)
                }
                self?.cancellable?.cancel()
            }
        }
        
        deinit {
            if self.state != .finished {
                self.kill()
                DispatchQueue.main.async { [weak self] in
                    self?.state = .finished
                }
            }
        }
        
    }
}


extension ET.Calibration {
    public func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.control = Skyle_calibControlMessages.with {
                $0.calibControl.abort = true
            }
            if self?.state != .finished {
                self?.state = .finished
            }
            self?.kill()
        }
    }
    
    public func start(points: [Int] = Points.Nine, stopHID: Bool = true, width: Int32 = ET.Calibration.width, height: Int32 = ET.Calibration.height) {
        guard self.state != .running, self.state != .connecting else {
            return
        }
        DispatchQueue.main.async {
            if self.state != .running {
                self.state = .running
            }
            self.type = points
            self.control = Skyle_calibControlMessages.with {
                $0.calibControl.calibrate = true
                $0.calibControl.stopHid = stopHID
                $0.calibControl.numberOfPoints = Int32(points.count)
                var res = Skyle_ScreenResolution()
                res.width = width
                res.height = height
                $0.calibControl.res = res
            }
        }
        self.run()
    }
    
    public static let width: Int32 = 2732
    public static let height: Int32 = 2048
    
    public static func calcX(_ id: Int, _ width: Float) -> Float {
        let offset = width * 0.08
        let w = width * 0.84
        let ret = Float((id % 3)) *  w / 2.0 + offset
        return ret - width / 2.0
    }
    
    public static func calcY(_ id: Int, width: Float, height: Float) -> Float {
        let offset = width * 0.08 * 3.0 / 4.0
        let h = height - offset * 2
        let ret = Float((id / 3) as Int) * h / 2.0 + offset
        return ret - height / 2.0
    }
    
}
