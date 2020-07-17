//
//  Skyle.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import CombineGRPC
import GRPC
import NIO
import Logging
import Alamofire
import NetUtils
import SystemConfiguration

public struct Point: Hashable {
    public var x: Double = 0
    public var y: Double = 0
    public init (x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public class ET: ObservableObject {
    
    public enum States: Equatable {
        public static func == (lhs: ET.States, rhs: ET.States) -> Bool {
            switch (lhs, rhs) {
            case (.none, .none):
                return true
            case (.running, .running):
                return true
            case (.connecting, .connecting):
                return true
            case (.finished, .finished):
                return true
            case (.failed, .failed):
                return true
            case (.error, .error):
                return true
            case (.none, _), (.running, _), (.connecting, _), (.finished, _), (.failed, _), (.error, _):
              return false
            }
        }
        case none, running, connecting, finished, failed(_ status: GRPCStatus), error(_ error: Error)
    }
    
    private(set) public var client: Skyle_SkyleClient?
    private(set) public var channelBuilder: ClientConnection.Builder
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    private(set) public var calibration = Calibration()
    public func makeCalibration() -> Calibration {
        self.calibration = Calibration(self.client)
        return self.calibration
    }
    
    private(set) public var control: Control = Control()
    public func makeControl() -> Control {
        self.control = Control(self.client)
        return self.control
    }
    
    private(set) public var gaze: Gaze = Gaze()
    public func makeGaze() -> Gaze {
        self.gaze = Gaze(self.client)
        return self.gaze
    }
    
    private(set) public var positioning: Positioning = Positioning()
    public func makePositioning() -> Positioning {
        self.positioning = Positioning(self.client)
        return self.positioning
    }
    
    private(set) public var profiles: Profiles = Profiles()
    public func makeProfiles() -> Profiles {
        self.profiles = Profiles(self.client)
        return self.profiles
    }
    
    private(set) public var reset: Reset = Reset()
    public func makeReset() -> Reset {
        self.reset = Reset(self.client)
        return self.reset
    }
    
    private(set) public var version: Version = Version()
    public func makeVersion() -> Version {
        self.version = Version(self.client)
        return self.version
    }
    
    private(set) public var stream: MjpegStream = MjpegStream()
    
    private let delegate: Delegate = Delegate()
    
    @Published private(set) public var connectivity: ConnectivityState = .idle
    @Published private(set) public var hardConnectivity: Bool = false
    @Published private(set) public var legacyConnectivity: Bool = false
    @Published private(set) public var grpcError: GRPCErrorProvider? = nil
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var timeoutGRPC: Timer?
    
    private var legacy = Legacy()
    
    public init(host: String = "skyle.local", port: Int = 50052) {
        self.channelBuilder = ClientConnection
            .insecure(group: self.group)
            .withConnectionIdleTimeout(.hours(24))
            .withConnectionBackoff(maximum: .seconds(1))
            .withErrorDelegate(self.delegate)
            .withConnectivityStateDelegate(self.delegate)
        
        self.legacy.connectivity.sink(receiveValue: { connected in
            DispatchQueue.main.async {
                self.connectivity = connected ? .ready : .idle
                self.legacyConnectivity = connected
                if connected {
                    ET.Version.Legacy.get(completion: { info in
                        guard let info = info else {
                            return
                        }
                        self.version.firmware = info.fW_version
                        self.version.eyetracker = info.eT_version
                        self.version.calib = info.calib_version
                        self.version.base = info.base_version
                        self.version.serial = info.serial
                        self.version.skyleType = info.skyle_type
                        self.version.isDemo = info.isDemo
                    })
                }
            }
        })
            .store(in: &self.cancellables)
        
        self.delegate.hardConnectivity.sink(receiveValue: { interface in
            DispatchQueue.main.async {
                self.hardConnectivity = interface.connected
            }
            if !interface.connected {
                do {
                    try self.client?.channel.close().wait()
                } catch {
                    
                }
                self.client = nil
                self.updateClient()
                self.timeoutGRPC?.invalidate()
                DispatchQueue.main.async {
                    self.connectivity = .idle
                }
            } else {
                guard var ip = interface.ip else {
                    return
                }
                ip.removeLast()
                ip += "2"
                let channel = self.channelBuilder.connect(host: host, port: port)
                self.client = Skyle_SkyleClient(channel: channel)
                self.updateClient()
                _ = self.version.get()
                self.control.get()
                DispatchQueue.global(qos: .background).async {
                    self.timeoutGRPC = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { timer in
                        if self.connectivity != .ready {
                            self.legacy.start()
                        }
                    }
                    let runLoop = RunLoop.current
                    runLoop.add(self.timeoutGRPC!, forMode: .default)
                    runLoop.run()
                }
            }
        })
            .store(in: &self.cancellables)
        
        self.delegate.softConnectivity.sink(receiveValue: { newState in
            DispatchQueue.main.async {
                self.connectivity = newState
            }
            if newState == .ready {
                self.timeoutGRPC?.invalidate()
                self.legacy.stop()
                _ = self.version.get()
                self.control.get()
            } else if (newState == .idle || newState == .shutdown || newState == .transientFailure) && !self.legacyConnectivity {
                self.version.setVersions(versions: Skyle_DeviceVersions())
            }
        })
            .store(in: &self.cancellables)
        
        self.delegate.error.sink(receiveValue: { error in
            guard let error = error else { return }
            DispatchQueue.main.async {
                self.grpcError = error
            }
        })
            .store(in: &self.cancellables)
    }
    
    private func updateClient() {
        self.calibration.client = self.client
        self.control.client = self.client
        self.gaze.client = self.client
        self.positioning.client = self.client
        self.profiles.client = self.client
        self.reset.client = self.client
        self.version.client = self.client
    }
    
    deinit {
        self.cancellables.removeAll()
        self.timeoutGRPC?.invalidate()
        do {
            try self.client?.channel.close().wait()
            try self.group.syncShutdownGracefully()
        } catch {
            
        }
    }
}


extension ET {
    public struct GRPCErrorProvider {
        public let error: Error
        public let file: StaticString
        public let line: Int
    }
    
    internal class Delegate: ConnectivityStateDelegate, ClientErrorDelegate {
        internal struct HardInterface {
            let connected: Bool
            let ip: String?
        }
        internal var hardConnectivity = CurrentValueSubject<HardInterface, Never>(HardInterface(connected: false, ip: nil))
        internal var softConnectivity = CurrentValueSubject<ConnectivityState, Never>(.idle)
        internal var error = CurrentValueSubject<GRPCErrorProvider?, Never>(nil)
        private var t: Timer?
        
        internal init() {
            DispatchQueue.global(qos: .background).async {
                self.t = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    var connected = false
                    var ip: String? = nil
                    for interface in Interface.allInterfaces() {
                        if interface.address != nil && (interface.address == "10.0.0.1" || interface.address == "192.168.137.1" ) {
                            ip = interface.address
                            connected = true
                        }
                    }
                    
                    if self.hardConnectivity.value.connected != connected {
                        self.hardConnectivity.value = HardInterface(connected: connected, ip: ip)
                    }
                }
                let runLoop = RunLoop.current
                runLoop.add(self.t!, forMode: .default)
                runLoop.run()
            }
        }
        
        func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
            self.softConnectivity.value = newState
        }
        
        func didCatchError(_ error: Error, logger: Logger, file: StaticString, line: Int) {
            self.error.value = GRPCErrorProvider(error: error, file: file, line: line)
        }
        
        deinit {
            self.t?.invalidate()
        }
    }
    
    struct Connectivity {
        static let sharedInstance = NetworkReachabilityManager()!
        static var isConnectedToInternet:Bool {
            return self.sharedInstance.isReachable
        }
    }
    
}

extension ET {
    internal class Legacy {
        
        private var t: Timer?
        
        private let url = URL(string: "http://skyle.local/api/update/")!
        
        private lazy var request = { () -> URLRequest in
            var request = URLRequest(url: self.url)
            request.timeoutInterval = 1
            request.httpMethod = "GET"
            return request
        }
        
        private lazy var urlconfig = { () -> URLSessionConfiguration in
            let urlconfig = URLSessionConfiguration.default
            urlconfig.timeoutIntervalForRequest = 1
            urlconfig.timeoutIntervalForResource = 1
            return urlconfig
        }
        
        private var session: URLSessionDataTask {
            URLSession(configuration: self.urlconfig()).dataTask(with: self.request()) { (_, response, error) -> Void in
                guard error == nil,
                    (response as? HTTPURLResponse)?.statusCode == 200
                    else {
                        DispatchQueue.main.async {
                            if self.connectivity.value {
                                self.connectivity.value = false
                            }
                        }
                        return
                }
                DispatchQueue.main.async {
                    if !self.connectivity.value {
                        self.connectivity.value = true
                    }
                }
            }
        }
        
        internal var connectivity = CurrentValueSubject<Bool, Never>(false)
        
        internal func start() {
            DispatchQueue.global(qos: .background).async {
                self.t = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
                    self.isAvailable()
                }
                let runLoop = RunLoop.current
                runLoop.add(self.t!, forMode: .default)
                runLoop.run()
            }
        }
        
        internal func stop() {
            self.t?.invalidate()
        }
        
        private func isAvailable() {
            self.session.resume()
        }
        
        deinit {
            self.stop()
        }
    }
}
