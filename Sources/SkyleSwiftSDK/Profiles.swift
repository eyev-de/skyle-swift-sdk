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
import SwiftProtobuf

extension ET {
    /**
        Profiles exposes Skyles User Profiles API which makes it possible to create, update, select and delete profiles.
        It also provides `Publisher` which hold the currently selected profile and a list of all profiles.
     */
    public class Profiles: ObservableObject {
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        /// In this case all `Profile`s are updated when this is updated.
        internal var client: Skyle_SkyleClient? {
            willSet {
                for profile in self.profiles {
                    profile.client = newValue
                }
            }
        }
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        /// The `state` property exposes a `Publisher` which indicates the state of streaming of profiles.
        @Published private(set) public var state: States = .finished
        /// The `profiles` property exposes a `Publisher` which holds an array of `Profile` objects pulled from Skyle.
        @Published private(set) public var profiles: [Profile] = []
        /// The `currentProfile` property exposes a `Publisher` which indicates the currently active `Profile`.
        @Published private(set) public var currentProfile: Profile?
        
        private var getAllCall: ServerStreamingCall<Google_Protobuf_Empty, Skyle_Profile>?
        private var getCurrentCall: UnaryCall<Google_Protobuf_Empty, Skyle_Profile>?
        private var deleteCall: UnaryCall<Skyle_Profile, Skyle_StatusMessage>?
        
        private func run(completion: @escaping (_ profiles: [ET.Profile]?, _ state: ET.States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                var tempProfiles: [ET.Profile] = []
                self?.getAllCall = client.getProfiles(Google_Protobuf_Empty()) { profile in
                    DispatchQueue.main.async { [weak self] in
                        if self?.state != .running {
                            self?.state = .running
                        }
                    }
                    let temp = ET.Profile(profile)
                    temp.client = self?.client
                    tempProfiles.append(temp)
                }
                
                self?.getAllCall?.status.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        completion(nil, .error(error))
                        DispatchQueue.main.async { [weak self] in
                            self?.state = .error(error)
                        }
                    case .success(let status):
                        completion(self?.profiles, .finished)
                        if status.code != .ok && status.code != .cancelled {
                            DispatchQueue.main.async { [weak self] in
                                self?.state = .failed(status)
                            }
                        }
                        DispatchQueue.main.async { [weak self] in
                            if self?.state != .finished {
                                self?.state = .finished
                            }
                            if !(self?.profiles.elementsEqual(tempProfiles, by: { $0.id == $1.id && $0.name == $1.name && $0.skill == $1.skill }) ?? false) {
                                self?.profiles.removeAll(keepingCapacity: true)
                                self?.profiles = tempProfiles
                            }
                            
                        }
                    }
                }
            }
        }
        
        private func kill() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                _ = self?.getAllCall?.cancel(promise: nil)
                do {
                    _ = try self?.getAllCall?.status.wait()
                } catch {
                    print(error)
                }
            }
        }
        
        private func getCurrent(completion: @escaping (_ profile: ET.Profile?, _ state: ET.States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {  [weak self] in
                guard let self = self else { return }
                self.getCurrentCall = client.currentProfile(Google_Protobuf_Empty())
                self.getCurrentCall?.response.whenComplete { result in
                    switch result {
                    case .failure(let error):
                        completion(nil, .error(error))
                    case .success(let profile):
                        completion(profile.profile(), .finished)
                        DispatchQueue.main.async {  [weak self] in
                            self?.currentProfile = profile.profile()
                        }
                    }
                }
            }
        }
        
        private func deleteProfile(_ profile: ET.Profile,
                                   completion: @escaping (_ message: Skyle_StatusMessage?, _ state: ET.States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {  [weak self] in
                self?.deleteCall = client.deleteProfile(profile.profile())
                self?.deleteCall!.response.whenComplete({ response in
                    switch response {
                    case .success(let result):
                        DispatchQueue.main.async {  [weak self] in
                            guard let self = self else { return }
                            self.profiles = self.profiles.filter { $0.id != profile.id }
                        }
                        completion(result, .finished)
                    case .failure(let error):
                        completion(nil, .error(error))
                    }
                })
            }
        }
    }
}

extension ET.Profiles {
    /**
        Gets all profiles and the currently active `Profile` stored on Skyle asyncronously, updating the `state`,
        `profiles` and `currentProfile` properties.
        - Parameters:
             - completion: A completion handler
             - profile: The currently active `Profile`.
             - state: A `ET.States` containing possible errors.
     */
    public func get(completion: @escaping (_ profile: ET.Profile?, _ state: ET.States) -> Void = {_, _ in}) {
        guard self.state != .running && self.state != .connecting else { return }
        DispatchQueue.main.async {  [weak self] in
            self?.state = .connecting
            self?.run { _, state in
                self?.getCurrent { profile, state in
                    completion(profile, state)
                }
            }
        }
    }
    /**
        Creates or updates a `Profile` and sets it to the currently active one.
        - Parameters:
            - profile: The profile to be created, updated and set to currently active.
            - completion: A completion handler
            - profile: The new, active `Profile`.
            - state: A `ET.States` containing possible errors.
     */
    public func set(_ profile: ET.Profile, completion: @escaping (_ profile: ET.Profile?, _ state: ET.States) -> Void = {_, _ in}) {
        profile.client = self.client
        profile.select { _, state in
            guard state == .finished else {
                completion(nil, state)
                return
            }
            self.get { profile, state in
                completion(profile, state)
            }
        }
    }
    /**
        Deletes a `Profile`.
        - Parameters:
            - profile: The profile to be deleted.
            - completion: A completion handler.
            - profile: The currently active `Profile`.
            - state: A `ET.States` containing possible errors.
     */
    public func delete(_ profile: ET.Profile, completion: @escaping (_ profile: ET.Profile?, _ state: ET.States) -> Void = {_, _ in}) {
        self.deleteProfile(profile) { message, state in
            if message?.success ?? false {
                self.getCurrent { profile, state in
                    completion(profile, state)
                }
            } else {
                completion(nil, state)
            }
        }
    }
}
