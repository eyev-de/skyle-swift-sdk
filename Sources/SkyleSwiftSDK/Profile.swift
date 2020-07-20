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
    public class Profile: ObservableObject {
        
        var client: Skyle_SkyleClient? = nil
        
        @Published internal(set) public var id: Int = -1
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
        
        public func select(completion: @escaping (Skyle_StatusMessage?, States) -> () = {_, _ in}) {
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
                        break
                    case .failure(let error):
                        completion(nil, .error(error))
                    }
                })
            }
        }
    }
}
