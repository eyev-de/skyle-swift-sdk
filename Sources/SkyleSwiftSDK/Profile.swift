//
//  Profile.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 14.07.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import GRPC

extension Skyle_Profile {
    func profile() -> ET.Profile {
        return ET.Profile(self)
    }
}

extension ET {
    /**
        Profile exposes `Publisher` which hold information about a profile.
     */
    public class Profile: ObservableObject {
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established by `Profiles`.
        internal var client: Skyle_SkyleClient?

        /// The `id` property exposes a `Publisher` which indicates the id of the profile. -1 is just a placeholder.
        @Published internal(set) public var id: Int = -1
        /// The `skill` property exposes a `Publisher` which indicates the `Skyle_Profile.Skill` of the profile.
        @Published public var skill: Skyle_Profile.Skill = .medium
        /// The `name` property exposes a `Publisher` which indicates the name of the profile. An empty `String` is the placeholder.
        @Published public var name: String = ""

        private var call: UnaryCall<Skyle_Profile, Skyle_StatusMessage>?

        public init() {}

        public init(_ profile: Skyle_Profile) {
            self.id = Int(profile.id)
            self.name = profile.name
            self.skill = profile.skill
        }
        /**
            This function transforms the profile to a `Skyle_Profile`.
            - returns: A `Skyle_profile` generated from `self`.
         */
        public func profile() -> Skyle_Profile {
            return Skyle_Profile.with({
                $0.id = Int32(self.id)
                $0.name = self.name
                $0.skill = self.skill
            })
        }
        /**
            This function selects the current profile.
            - Parameters:
                - completion: A completion handler.
                - message: A `Skyle_StatusMessage` indicating the success = true | false of the call, or nil
                - state: A `ET.States` containing possible errors.
         */
        public func select(completion: @escaping (_ message: Skyle_StatusMessage?, _ state: ET.States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.call = client.setProfile(self.profile())
                self.call!.response.whenComplete({ response in
                    switch response {
                    case .success(let result):
                        completion(result, .finished)
                    case .failure(let error):
                        completion(nil, .error(error))
                    }
                })
            }
        }
    }
}
