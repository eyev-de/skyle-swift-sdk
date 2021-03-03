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

extension ET {
    /**
        The calibration class provides `Publisher` and functions to perform a calibration of Skyle.
     */
    public class Calibration: ObservableObject {
        
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        internal var client: Skyle_SkyleClient?
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        /// A simple struct containing the possible calibrations represented as array of ids.
        // swiftlint:disable nesting
        public struct Points {
            public static let Five = [0, 2, 4, 6, 8]
            public static let Nine = [0, 1, 2, 3, 4, 5, 6, 7, 8]
        }
        
        /// The `type` property exposes a `Publisher` which indicates the type of calibration.
        /// Currently not actively used. Should be set to either value in `ET.Calibration.Points`
        @Published private(set) public var type: [Int] = []
        /// The `state` property exposes a `Publisher` which indicates the state of the calibration.
        @Published private(set) public var state: States = .none
        /// The `control` property exposes a `Publisher` which holds the control messages fot the calibration.
        /// This can be used to send a control message to the calibration to abort the calibration for example. See `Calibration.stop()`.
        @Published private(set) public var control: Skyle_calibControlMessages?
        /// The `point` property exposes a `Publisher` which indicates the calibration point as coordinates on the screen.
        @Published private(set) public var point = Point(x: 0, y: 0)
        /// The `currentPoint` property exposes a `Publisher` which indicates the calibration point count (0, 1, 2, 3, ...).
        @Published private(set) public var currentPoint = 0
        /// The `quality` property exposes a `Publisher` which indicates the overall quality of the calibration.
        @Published private(set) public var quality = 0.0
        /// The `qualities` property exposes a `Publisher` which indicates the quality of each point of the calibration.
        @Published private(set) public var qualities: [Double] = []
        
        private var call: BidirectionalStreamingCall<Skyle_calibControlMessages, Skyle_CalibMessages>?
        private var cancellable: AnyCancellable?
                
        private func run(recalibrate: Bool = false) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let client = self?.client else {
                    return
                }
                self?.call = client.calibrate { calib in
                    switch calib.message {
                    case .calibControl(let control):
                        DispatchQueue.main.async { [weak self] in
                            if !control.calibrate {
                                if self?.state != .finished {
                                    self?.state = .finished
                                }
                            }
                        }
                    case .calibPoint(let point):
                        DispatchQueue.main.async { [weak self] in
                            self?.currentPoint = Int(point.count)
                            self?.point = SkyleSwiftSDK.Point(x: Double(point.currentPoint.x), y: Double(point.currentPoint.y))
                        }
                    case.calibQuality(let quality):
                        DispatchQueue.main.async { [weak self] in
                            self?.quality = quality.quality
                            self?.qualities = quality.qualitys
                            if !recalibrate {
                                self?.kill()
                            }
                        }
                    case .none:
                        break
                    }
                }
                
            }
            
            if self.cancellable == nil {
                self.cancellable = self.$control.sink(receiveValue: { control in
                    guard let control = control else { return }
                    _ = self.call?.sendMessage(control)
                })
            }
        }
        
        private func kill() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let end = self?.call?.sendEnd()
                end?.whenComplete({ result in
                    switch result {
                    case .failure(let error):
                        DispatchQueue.main.async { [weak self] in
                            self?.state = .error(error)
                        }
                    case .success:
                        DispatchQueue.main.async { [weak self] in
                            if self?.state != ET.States.none {
                                self?.state = .none
                            }
                        }
                    }
                })
                do {
                    try end?.wait()
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.state = .error(error)
                    }
                }
                self?.cancellable?.cancel()
            }
        }
        /// Simple cleanup by killing the calibration gRPC call.
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
    /**
        Starts a calibration asyncronously, updating the `state`, `point`, `currentPoint`, `quality` and `qualities` properties.
        - Parameters:
            - points: Amount of calibration points. Pass one of `ET.Calibration.Points`.
            - stopHID: Tells Skyle to stop HID (Mouse positioning updates) during the calibration.
                        Resets after the calibration has finished.
            - recalibrate: Tells the calibration to keep the connection open after the calibration has finished
                            to perform a possible recalibration of certain points.
            - width: Screen width in pixels.
            - height: Screen height in pixels.
            - stepped: Indicating if the user wants to manually step through the calibration points. Need to call next()
     */
    public func start(points: [Int] = Points.Nine,
                      stopHID: Bool = true,
                      recalibrate: Bool = false,
                      width: Int32 = ET.Calibration.width,
                      height: Int32 = ET.Calibration.height,
                      stepped: Bool = false) {
        guard self.state != .running, self.state != .connecting else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            if self?.state != .running {
                self?.state = .running
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.run(recalibrate: recalibrate)
                DispatchQueue.main.async { [weak self] in
                    self?.type = points
                    self?.control = Skyle_calibControlMessages.with {
                        $0.calibControl.calibrate = true
                        $0.calibControl.stopHid = stopHID
                        $0.calibControl.stepByStep = stepped
                        $0.calibControl.numberOfPoints = Int32(points.count)
                        var res = Skyle_ScreenResolution()
                        res.width = width
                        res.height = height
                        $0.calibControl.res = res
                    }
                }
            }
        }
    }
    /// Stops a calibration asyncronously, updating the `state` and `control` properties.
    public func stop() {
        guard self.state == .running || self.state == .connecting else {
            return
        }
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
    /// When stepByStep is true this will request the next calibration point
    public func next() {
        guard self.state == .running || self.state == .connecting else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.control = Skyle_calibControlMessages.with {
                $0.calibConfirm.confirmed = true
            }
        }
    }
    
    /// The width in pixels of the iPad Pro 12,9
    public static let width: Int32 = 2732
    /// The height in pixels of the iPad Pro 12,9
    public static let height: Int32 = 2048
    /// Calculates the x position in pixel of a calibration point by providing a value from `Points.<Value>`
    /// and the width of the screen in pixel.
    public static func calcX(_ id: Int, _ width: Float) -> Float {
        let offset = width * 0.08
        let temp = width * 0.84
        let ret = Float((id % 3)) *  temp / 2.0 + offset
        return ret - width / 2.0
    }
    /// Calculates the y position in pixel of a calibration point by providing a value from `Points.<Value>`
    /// and the width and height of the screen in pixel.
    public static func calcY(_ id: Int, width: Float, height: Float) -> Float {
        let offset = width * 0.08 * 3.0 / 4.0
        let temp = height - offset * 2
        let ret = Float((id / 3) as Int) * temp / 2.0 + offset
        return ret - height / 2.0
    }
    
    public func fakeCalibration(points: [Int] = Points.Nine) {
        var calibrationPoints: [SkyleSwiftSDK.Point] = []
        var qualities: [Double] = []
        if points == Points.Nine {
            qualities = [5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0, 5.0]
            calibrationPoints = [
                SkyleSwiftSDK.Point(x: 218.53436547032607, y: 218.51314142678348),
                SkyleSwiftSDK.Point(x: 1366.3204316209242, y: 218.51314142678348),
                SkyleSwiftSDK.Point(x: 2513.465634529674, y: 218.51314142678348),
                SkyleSwiftSDK.Point(x: 218.53436547032607, y: 1024.0),
                SkyleSwiftSDK.Point(x: 1366.3204316209242, y: 1024.0),
                SkyleSwiftSDK.Point(x: 2513.465634529674, y: 1024.0),
                SkyleSwiftSDK.Point(x: 218.53436547032607, y: 1829.4868585732165),
                SkyleSwiftSDK.Point(x: 1366.3204316209242, y: 1829.4868585732165),
                SkyleSwiftSDK.Point(x: 2513.465634529674, y: 1829.4868585732165),
            ]
        } else if points == Points.Five {
            qualities = [5.0, 5.0, 5.0, 5.0, 5.0]
            calibrationPoints = [
                SkyleSwiftSDK.Point(x: 218.53436547032607, y: 218.51314142678348),
                SkyleSwiftSDK.Point(x: 2513.465634529674, y: 218.51314142678348),
                SkyleSwiftSDK.Point(x: 1366.3204316209242, y: 1024.0),
                SkyleSwiftSDK.Point(x: 218.53436547032607, y: 1829.4868585732165),
                SkyleSwiftSDK.Point(x: 2513.465634529674, y: 1829.4868585732165),
            ]
        }
        let queue = DispatchQueue(label: "fakeCalibration")
        queue.async {
            DispatchQueue.main.async { [weak self] in
                self?.state = .running
            }
            for (index, point) in calibrationPoints.enumerated() {
                Thread.sleep(forTimeInterval: 1)
                DispatchQueue.main.async { [weak self] in
                    self?.currentPoint = index
                    self?.point = point
                }
            }
            Thread.sleep(forTimeInterval: 1)
            DispatchQueue.main.async { [weak self] in
                self?.quality = 5.0
                self?.qualities = qualities
                self?.state = .finished
            }
        }
    }
    
}
