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

extension Skyle_Profile {
    func profile() -> ET.Profile {
        return ET.Profile(self)
    }
}

public class ObservableArray<T: ObservableObject>: ObservableObject {
    @Published public var array:[T] = []
    private var cancellables = [AnyCancellable]()

    public init() {}
    
    public init(array: [T]) {
        self.array = array
        self.observeChildrenChanges()
    }
    
    public func append(_ e: T) {
        e.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() }).store(in: &self.cancellables)
        self.array.append(e)
    }
    
    public var isEmpty: Bool {
        return self.array.isEmpty
    }

    private func observeChildrenChanges() {
        self.array.forEach({
            $0.objectWillChange.sink(receiveValue: { _ in self.objectWillChange.send() }).store(in: &self.cancellables)
        })
    }

    deinit {
        self.cancellables.removeAll()
    }

}

extension ET {
    
    public class Profile: ObservableObject {
        
        var client: Skyle_SkyleClient? = nil
        
        @Published private(set) public var id: Int = -1
        @Published public var skill: Skyle_Profile.Skill = .medium
        @Published public var name: String = ""
        
        private var call: UnaryCall<Skyle_Profile, Skyle_StatusMessage>?
        
        public init() {}
        
        public init(_ profile: Skyle_Profile) {
            self.id = Int(profile.id)
            self.name = profile.name
            self.skill = profile.skill
        }
        
        public func profile() -> Skyle_Profile {
            return Skyle_Profile.with({
                $0.id = Int32(self.id)
                $0.name = self.name
                $0.skill = self.skill
            })
        }
        
        public func select(completion: @escaping (Skyle_StatusMessage?, Error?) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            self.call = client.setProfile(self.profile())
            self.call!.response.whenComplete({ response in
                switch response {
                case .success(let result):
                    completion(result, nil)
                    break
                case .failure(let error):
                    completion(nil, error)
                }
            })
        }
    }
    
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
        @Published private(set) public var state: State = .none

//        @Published private(set) public var profiles: ObservableArray<Profile> = ObservableArray()
        @Published private(set) public var profiles: [Profile] = []
        @Published private(set) public var currentProfile: Profile = Profile()
        
        private let grpc = GRPCExecutor()
        private var cancellables: Set<AnyCancellable> = []
        
        private var call: ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Profile>?
        private var deleteCall: UnaryCall<Skyle_Profile, Skyle_StatusMessage>?
        
        private func run() {
            guard let client = self.client else {
                return
            }
            self.call = client.getProfiles(Google_Protobuf_Empty()) { profile in
                DispatchQueue.main.async {
                    if self.state != .running {
                        self.state = .running
                    }
                    if self.profiles.first(where: { $0.id == profile.id}) == nil {
                        let p = Profile(profile)
                        p.client = self.client
                        self.profiles.append(p)
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
        
        private func getCurrent() {
            guard let client = self.client else {
                return
            }
            self.grpc.call(client.currentProfile)(Google_Protobuf_Empty())
            .sink(receiveCompletion: {
                switch $0 {
                case .failure(let status):
                    DispatchQueue.main.async {
                        self.state = .failed(status)
                    }
                    break
                case .finished:
                    DispatchQueue.main.async {
                        if self.state != .none {
                            self.state = .none
                        }
                    }
                    break
                }
            }, receiveValue: { profile in
                DispatchQueue.main.async {
                    self.currentProfile = profile.profile()
                }
            }).store(in: &self.cancellables)
        }
        
        private func deleteProfile(_ profile: Profile, completion: @escaping (Skyle_StatusMessage?, Error?) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            self.deleteCall = client.deleteProfile(profile.profile())
            self.deleteCall!.response.whenComplete({ response in
                switch response {
                case .success(let result):
                    DispatchQueue.main.async {
                        self.profiles = self.profiles.filter { $0 !== profile }
                        completion(result, nil)
                    }
                case .failure(let error):
                    completion(nil, error)
                }
            })
        }
        
        deinit {
            self.cancellables.removeAll()
        }
    }
}

extension ET.Profiles {
    public func get() {
        if self.state != .running && self.state != .connecting {
            DispatchQueue.main.async {
                self.state = .connecting
            }
            DispatchQueue.global(qos: .userInteractive).async {
                self.run()
                self.getCurrent()
            }
        }
    }
    
    public func set(_ profile: ET.Profile) {
        DispatchQueue.global(qos: .userInteractive).async {
            profile.client = self.client
            profile.select() { _, error in
                guard error == nil else {
                    return
                }
                self.get()
            }
        }
    }
    
    public func delete(_ profile: ET.Profile, completion: @escaping (Skyle_StatusMessage?, Error?) -> () = {_, _ in}) {
        DispatchQueue.global(qos: .userInteractive).async {
            self.deleteProfile(profile) { message, error in
                completion(message, error)
            }
        }
    }
}
