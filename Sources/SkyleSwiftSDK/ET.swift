//
//  Skyle.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import GRPC
import NIO
import Logging
import Alamofire
import NetUtils
import SystemConfiguration

/**
    Simple Point structure used to pass Gaze points and Position around
 */
public struct Point: Hashable {
    // swiftlint:disable identifier_name
    public var x: Double = 0
    public var y: Double = 0
    public init (x: Double, y: Double) {
        self.x = x
        self.y = y
    }
    // swiftlint:enable identifier_name
}

/**
    Main class of the SDK, which takes care of the connection to Skyle and exposes all parts of the API.
 */
public class ET: ObservableObject {
    
    /**
        Defenition of States that are used by all members of the SDK, indicating the connection and lifecycle of gRPC calls
     */
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
        /// No state or disposed
        case none
        /// There is an ongoing gRPC call
        case running
        /// The gRPC call has not started yet, but is about to
        case connecting
        /// The gRPC call has finished and the object shall be disposed
        case finished
        /// The gRPC call has failed with a status
        case failed(_ status: GRPCStatus)
        /// The gRPC call has thrown an error
        case error(_ error: Error)
    }
    
    /// The client is generated by the proto files
    private(set) public var client: Skyle_SkyleClient?
    /// The channel builder holds the configuration of the connection
    private(set) public var channelBuilder: ClientConnection.Builder
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    
    /// Reference to the current calibration. After each calibration please call `makeCalibration()`.
    private(set) public var calibration = Calibration()
    /// Creates a new calibration and sets `calibration` to the new instance.
    public func makeCalibration() -> Calibration {
        self.calibration = Calibration(self.client)
        return self.calibration
    }
    
    /// Reference to the current `control` instance. You can create a new instance by calling `makeControl()`.
    private(set) public var control: Control = Control()
    /// Creates a new `control` instance and sets `control` to the new instance.
    public func makeControl() -> Control {
        self.control = Control(self.client)
        return self.control
    }
    /// Reference to the current `gaze` instance. You can create a new instance by calling `makeGaze()`.
    private(set) public var gaze: Gaze = Gaze()
    /// Creates a new `gaze` instance and sets `gaze` to the new instance.
    public func makeGaze() -> Gaze {
        self.gaze = Gaze(self.client)
        return self.gaze
    }
    /// Reference to the current `positioning` instance. You can create a new instance by calling `makePositioning()`.
    private(set) public var positioning: Positioning = Positioning()
    /// Creates a new `positioning` instance and sets `positioning` to the new instance.
    public func makePositioning() -> Positioning {
        self.positioning = Positioning(self.client)
        return self.positioning
    }
    /// Reference to the current `profiles` instance. You can create a new instance by calling `makeProfiles()`.
    private(set) public var profiles: Profiles = Profiles()
    /// Creates a new `profiles` instance and sets `profiles` to the new instance.
    public func makeProfiles() -> Profiles {
        self.profiles = Profiles(self.client)
        return self.profiles
    }
    /// Reference to the current `reset` instance. You can create a new instance by calling `makeReset()`.
    private(set) public var reset: Reset = Reset()
    /// Creates a new `reset` instance and sets `reset` to the new instance.
    public func makeReset() -> Reset {
        self.reset = Reset(self.client)
        return self.reset
    }
    /// Reference to the current `version` instance. You can create a new instance by calling `makeVersion()`.
    private(set) public var version: Version = Version()
    /// Creates a new `version` instance and sets `version` to the new instance.
    public func makeVersion() -> Version {
        self.version = Version(self.client)
        return self.version
    }
    /// Reference to the current `stream` instance.
    private(set) public var stream: MjpegStream = MjpegStream()
    
    // swiftlint:disable weak_delegate
    private let delegate: Delegate = Delegate()
    
    /// The `connectivity` property exposes a `Publisher` which indicates the `ConnectivityState` of the API of Skyle.
    /// This is normaly updated by the gRPC library but will also be updated when a Legacy eyetracker is connected.
    @Published private(set) public var connectivity: ConnectivityState = .idle
    /// The `hardConnectivity` property exposes a `Publisher` which indicates the connection state of the interface of Skyle.
    /// This is `true` when the ethernet interface with Skyle is available. It is normaly available before the API is available.
    @Published private(set) public var hardConnectivity: Bool = false
    /// The `legacyConnectivity` property exposes a `Publisher` which indicates the connection state of the `http` API of Skyle.
    /// This is only used to detect `Legacy` devices and will be removed when all devices are updated to a firmware version >=  3.0
    @Published private(set) public var legacyConnectivity: Bool = false
    /// The `grpcError` property exposes a `Publisher` which provides all errors coming from the grpc library.
    @Published private(set) public var grpcError: GRPCErrorProvider?
    
    private var cancellables: Set<AnyCancellable> = []
    
    private var timeoutGRPC: Timer?
    
    private var legacy = Legacy()
    
    /**
            Initializes a new `ET` with the provided host and port to connect to.
            - Parameters:
                - host: The host to connect to. Defaults to `skyle.local`
                - port: The port to connect to. Defaults to `50052`
     
            - Returns: A brand new `ET` which is setup to be connected to.
     */
    public init(host: String = "skyle.local", port: Int = 50052) {
        self.channelBuilder = ClientConnection
            .insecure(group: self.group)
            .withConnectionIdleTimeout(.hours(24))
            .withConnectionBackoff(maximum: .seconds(1))
            .withErrorDelegate(self.delegate)
            .withConnectivityStateDelegate(self.delegate)
        
        self.setupLegacy()
        self.setupHardConnectivity(host: host, port: port)
        self.setupSoftConnectivity()
        
        self.delegate.error.sink(receiveValue: { error in
            guard let error = error else { return }
            DispatchQueue.main.async { [weak self] in
                self?.grpcError = error
            }
        })
            .store(in: &self.cancellables)
    }
    
    private func setupLegacy() {
        self.legacy.connectivity.sink(receiveValue: { connected in
            DispatchQueue.main.async {
                self.connectivity = connected ? .ready : .idle
                self.legacyConnectivity = connected
                if connected {
                    ET.Version.Legacy.get(completion: { info in
                        guard let info = info else {
                            return
                        }
                        var ver = Skyle_DeviceVersions()
                        ver.firmware = info.fW_version
                        ver.eyetracker = info.eT_version
                        ver.calib = info.calib_version
                        ver.base = info.base_version
                        ver.serial = info.serial
                        ver.skyleType = info.skyle_type
                        ver.isDemo = info.isDemo ?? false
                        self.version.version = ver
                    })
                }
            }
        })
            .store(in: &self.cancellables)
    }
    
    private func setupHardConnectivity(host: String, port: Int) {
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
                self.version.get()
                self.control.get()
                DispatchQueue.global(qos: .background).async {
                    self.timeoutGRPC = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { _ in
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
    }
    
    private func setupSoftConnectivity() {
        self.delegate.softConnectivity.sink(receiveValue: { newState in
            if newState == .ready {
                self.timeoutGRPC?.invalidate()
                self.legacy.stop()
                self.version.get()
                self.control.get()
            } else if (newState == .idle || newState == .shutdown || newState == .transientFailure) && !self.legacyConnectivity {
                DispatchQueue.main.async { [weak self] in
                    self?.version.version = Skyle_DeviceVersions()
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.connectivity = newState
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
    /// Simple cleanup cancels the gRPC calls, invalidates timer and shuts down the EventLoopGroup.
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
    /// A simple struct to provide error information thrown by the gRPC library.
    public struct GRPCErrorProvider {
        public let error: Error
        public let file: StaticString
        public let line: Int
    }
    
    internal class Delegate: ConnectivityStateDelegate, ClientErrorDelegate {
        /// A simple struct representing a hardware interface.
        // swiftlint:disable nesting
        internal struct HardInterface {
            let connected: Bool
            let ip: String?
        }
        /// The `hardConnectivity` property exposes a `CurrentValueSubject`-`Publisher`
        /// which indicates if a network interface is connected and whith which ip address.
        internal var hardConnectivity = CurrentValueSubject<HardInterface, Never>(HardInterface(connected: false, ip: nil))
        /// The `softConnectivity` property exposes a `CurrentValueSubject`-`Publisher` which indicates the gRPC connectivity.
        internal var softConnectivity = CurrentValueSubject<ConnectivityState, Never>(.idle)
        /// The `error` property exposes a `CurrentValueSubject`-`Publisher` which indicates if the gRPC library has encountered an error.
        internal var error = CurrentValueSubject<GRPCErrorProvider?, Never>(nil)
        private var timer: Timer?
        /// Initialize hardware connectivity polling mechanism by checking if an interface with ip address
        /// `10.0.0.1` or `192.168.137.1` has connected.
        internal init() {
            DispatchQueue.global(qos: .background).async {
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    var connected = false
                    var ip: String?
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
                runLoop.add(self.timer!, forMode: .default)
                runLoop.run()
            }
        }
        /// Implementation of `ConnectivityStateDelegate`.
        func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
            self.softConnectivity.value = newState
        }
        /// Implementation of `ConnectivityStateDelegate`.
        func didCatchError(_ error: Error, logger: Logger, file: StaticString, line: Int) {
            self.error.value = GRPCErrorProvider(error: error, file: file, line: line)
        }
        /// Simple cleanup invalidates timer.
        deinit {
            self.timer?.invalidate()
        }
    }
    
//    struct Connectivity {
//        static let sharedInstance = NetworkReachabilityManager()!
//        static var isConnectedToInternet: Bool {
//            return self.sharedInstance.isReachable
//        }
//    }
    
}

extension ET {
    /// Legacy connectivity provider via the http API.
    /// - Warning: This is not to be used since the API is deprecated.
    internal class Legacy {
        
        private var timer: Timer?
        
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
        /// Defines a `CurrentValueSubject` `Publisher`, which indicates if Skyle is connected via the deprecated http API.
        internal var connectivity = CurrentValueSubject<Bool, Never>(false)
        /// Starts the timer, polling the deprecated http API.
        internal func start() {
            DispatchQueue.global(qos: .background).async {
                self.timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
                    self.isAvailable()
                }
                let runLoop = RunLoop.current
                runLoop.add(self.timer!, forMode: .default)
                runLoop.run()
            }
        }
        /// Stops the timer, polling the deprecated http API.
        internal func stop() {
            self.timer?.invalidate()
        }
        
        private func isAvailable() {
            self.session.resume()
        }
        /// Simple cleanup by calling `stop()`.
        deinit {
            self.stop()
        }
    }
}
