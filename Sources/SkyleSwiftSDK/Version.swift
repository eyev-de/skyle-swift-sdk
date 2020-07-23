//
//  Version.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import GRPC
import SwiftProtobuf
import Alamofire

extension ET {
    /**
        Version provides `Publisher` with information about the software versions of Skyle.
     */
    public class Version: ObservableObject {
        
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        internal var client: Skyle_SkyleClient?
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        /// The `version` property exposes a `Publisher` which indicates the software versions of Skyle.
        /// This is managed by `ET` whenever a connection is established or lost.
        @Published internal var version = Skyle_DeviceVersions() {
            willSet {
                self.setVersions(versions: newValue)
            }
        }
        
        /// The `firmware` property exposes a `Publisher` which indicates the version of the firmware.
        @Published private(set) public var firmware: String = ""
        /// The `eyetracker` property exposes a `Publisher` which indicates the version of the eyetracker service.
        @Published private(set) public var eyetracker: String = ""
        /// The `calib` property exposes a `Publisher` which indicates the version of the calibration service.
        @Published private(set) public var calib: String = ""
        /// The `base` property exposes a `Publisher` which indicates the version of the base image.
        @Published private(set) public var base: String = ""
        /// The `skyleType` property exposes a `Publisher` which indicates the type of Skyle usually 4 or 5.
        @Published private(set) public var skyleType: Int32 = 0
        /// The `serial` property exposes a `Publisher` which indicates the serial number of this Skyle.
        @Published private(set) public var serial: UInt64 = 0
        /// The `isDemo` property exposes a `Publisher` which indicates if the device is a demo device.
        @Published private(set) public var isDemo: Bool? = false
        
        private var call: UnaryCall<Google_Protobuf_Empty, Skyle_DeviceVersions>?
        
        /**
            Gets the current versions of software and other info from the eyetracker Skyle.
            - Parameters:
                - completion: A completion handler
                - versions: A `Skyle_DeviceVersion` instance containing the versions of the software running
                            on the device and other information or nil
                - state: A `ET.States` containing possible errors.
         */
        public func get(completion: @escaping (_ versions: Skyle_DeviceVersions?, _ state: ET.States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.call = client.getVersions(Google_Protobuf_Empty())
                self.call?.response.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        completion(nil, .error(error))
                    case.success(let versions):
                        DispatchQueue.main.async { [weak self] in
                            self?.setVersions(versions: versions)
                            DispatchQueue.global(qos: .userInitiated).async {
                                completion(versions, .finished)
                            }
                        }
                    }
                }
            }
        }
        
        private func setVersions(versions: Skyle_DeviceVersions) {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.firmware = versions.firmware
                self.base = versions.base
                self.calib = versions.calib
                self.eyetracker = versions.eyetracker
                self.skyleType = versions.skyleType
                self.isDemo = versions.isDemo
                self.serial = versions.serial
            }
        }
    }
}

extension ET.Version {
    /// Legacy version provider via the http API.
    /// - Warning: This is not to be used since the API is deprecated.
    internal class Legacy {
        
        private static let url = URL(string: "http://skyle.local/api/update/")!
        /// Simple struct holding information about firmware versions and more.
        // swiftlint:disable nesting
        internal struct UpdateInfo: Decodable {
            // swiftlint:disable identifier_name
            internal var fW_version: String = ""
            // swiftlint:disable identifier_name
            internal var eT_version: String = ""
            // swiftlint:disable identifier_name
            internal var calib_version: String = ""
            // swiftlint:disable identifier_name
            internal var base_version: String = ""
            // swiftlint:disable identifier_name
            internal var skyle_type: Int32 = 0
            internal var serial: UInt64 = 0
            internal var isDemo: Bool? = false
        }
        /**
            Gets the software versions and information about Skyle via the deprecated http API.
            - Parameters:
                - completion: A completion handler.
                - info: A `UpdateInfo` containing information about the firmware version and more or nil
         */
        static func get(completion: @escaping (_ info: UpdateInfo?) -> Void) {
            AF.request(Legacy.url).validate().responseJSON { response in
                guard response.error == nil else {
                    completion(nil)
                    return
                }
                guard let data = response.data else {
                    completion(nil)
                    return
                }
                do {
                    let decoder = JSONDecoder()
                    let info = try decoder.decode(UpdateInfo.self, from: data)
                    completion(info)
                } catch {
                    completion(nil)
                }
            }
        }
        
    }
}
