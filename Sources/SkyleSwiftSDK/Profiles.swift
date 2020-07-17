//
//  Profiles.swift
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

extension ET {
    public class Profiles: ObservableObject {
        var client: Skyle_SkyleClient? = nil {
            willSet {
                for profile in self.profiles {
                    profile.client = newValue
                }
            }
        }
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        @Published private(set) public var state: States = .none
        
        @Published private(set) public var profiles: [Profile] = []
        @Published private(set) public var currentProfile: Profile = Profile()
        
        private let grpc = GRPCExecutor()
        private var cancellables: Set<AnyCancellable> = []
        
        private var call: ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Profile>?
        private var deleteCall: UnaryCall<Skyle_Profile, Skyle_StatusMessage>?
        
        private func run(completion: @escaping ([Profile]?, States) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.main.async {
                self.profiles.removeAll(keepingCapacity: true)
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.call = client.getProfiles(Google_Protobuf_Empty()) { profile in
                    DispatchQueue.main.async {
                        if self.state != .running {
                            self.state = .running
                        }
                        let p = Profile(profile)
                        p.client = self.client
                        self.profiles.append(p)
                    }
                }
                
                self.call?.status.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        completion(nil, .error(error))
                        DispatchQueue.main.async {
                            self.state = .error(error)
                        }
                        break
                    case .success(let status):
                        completion(self.profiles, .finished)
                        if status.code != .ok {
                            DispatchQueue.main.async {
                                self.state = .failed(status)
                            }
                        }
                        DispatchQueue.main.async {
                            if self.state != .none {
                                self.state = .none
                            }
                        }
                        break
                    }
                }
            }
        }
        
        private func kill() {
            DispatchQueue.global(qos: .userInitiated).async {
                _ = self.call?.cancel()
                do {
                    _ = try self.call?.status.wait()
                } catch {
                    print(error)
                }
            }
        }
        
        private func getCurrent(completion: @escaping (Profile?, States) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.grpc.call(client.currentProfile)(Google_Protobuf_Empty())
                    .sink(receiveCompletion: {
                        switch $0 {
                        case .failure(let status):
                            completion(nil, .failed(status))
                            break
                        case .finished:
                            break
                        }
                    }, receiveValue: { profile in
                        completion(profile.profile(), .finished)
                        DispatchQueue.main.async {
                            self.currentProfile = profile.profile()
                        }
                    }).store(in: &self.cancellables)
            }
        }
        
        private func deleteProfile(_ profile: Profile, completion: @escaping (Skyle_StatusMessage?, States) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.deleteCall = client.deleteProfile(profile.profile())
                self.deleteCall!.response.whenComplete({ response in
                    switch response {
                    case .success(let result):
                        DispatchQueue.main.async {
                            self.profiles = self.profiles.filter { $0 !== profile }
                        }
                        completion(result, .finished)
                    case .failure(let error):
                        completion(nil, .error(error))
                    }
                })
            }
        }
        
        deinit {
            self.cancellables.removeAll()
        }
    }
}

extension ET.Profiles {
    public func get(completion: @escaping (ET.Profile?, ET.States) -> () = {_, _ in}) {
        if self.state != .running && self.state != .connecting {
            DispatchQueue.main.async {
                self.state = .connecting
            }
            self.run() { profiles, state in
                self.getCurrent() { profile, state in
                    completion(profile, state)
                }
            }
        }
    }
    
    public func set(_ profile: ET.Profile, completion: @escaping (ET.Profile?, ET.States) -> () = {_, _ in}) {
        profile.client = self.client
        profile.select() { _, state in
            guard state == .finished else {
                completion(nil, state)
                return
            }
            self.get() { profile, state in
                completion(profile, state)
            }
        }
    }
    
    public func delete(_ profile: ET.Profile, completion: @escaping (Skyle_StatusMessage?, ET.States) -> () = {_, _ in}) {
        self.deleteProfile(profile) { message, state in
            self.getCurrent() { profile, state in
                completion(message, state)
            }
        }
    }
}
