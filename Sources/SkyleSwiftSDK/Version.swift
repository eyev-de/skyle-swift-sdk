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
import CombineGRPC
import SwiftProtobuf
import Alamofire

extension ET {
    public class Version: ObservableObject {
        
        var client: Skyle_SkyleClient? = nil
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        @Published private(set) internal var version = Skyle_DeviceVersions()
        
        @Published internal(set) public var firmware: String = ""
        @Published internal(set) public var eyetracker: String = ""
        @Published internal(set) public var calib: String = ""
        @Published internal(set) public var base: String = ""
        @Published internal(set) public var skyleType: Int32 = 0
        @Published internal(set) public var serial: UInt64 = 0
        @Published internal(set) public var isDemo: Bool? = false
        
        private let grpc = GRPCExecutor()
        private var cancellable: AnyCancellable?
        
        public func get(completion: @escaping (Skyle_DeviceVersions?, States) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            self.cancellable = self.grpc.call(client.getVersions)(Google_Protobuf_Empty())
            .sink(receiveCompletion: {
                switch $0 {
                case .failure(let status):
                    completion(nil, .failed(status))
                    break
                case .finished:
                    break
                }
            }, receiveValue: { versions in
                completion(versions, .finished)
                self.setVersions(versions: versions)
            })
        }
        
        func setVersions(versions: Skyle_DeviceVersions) {
            DispatchQueue.main.async {
                self.version = versions
                self.firmware = versions.firmware
                self.base = versions.base
                self.calib = versions.calib
                self.eyetracker = versions.eyetracker
                self.skyleType = versions.skyleType
                self.isDemo = versions.isDemo
                self.serial = versions.serial
            }
        }
        
        deinit {
            self.cancellable?.cancel()
        }
    }
}

extension ET.Version {
    class Legacy {
        
        private static let url = URL(string: "http://skyle.local/api/update/")!
        
        struct UpdateInfo: Decodable {
            var fW_version: String = ""
            var eT_version: String = ""
            var calib_version: String = ""
            var base_version: String = ""
            var skyle_type: Int32 = 0
            var serial: UInt64 = 0
            var isDemo: Bool? = false
        }
        
        static func get(completion: @escaping (UpdateInfo?) -> Void) {
            AF.request(Legacy.url).validate().responseJSON { response in
                guard response.error == nil else {
                    print(response.error!)
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
                    print(error)
                    completion(nil)
                }
            }
        }
        
    }
}
