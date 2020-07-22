//
//  Reset.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 14.07.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import GRPC

extension ET {
    /**
        Reset provides the following maintenance functions:
        - Restart Skyles internal services including eyetracking, calibration and API
        - Restart Skyle itself
        - Reset all user data
     */
    public class Reset: ObservableObject {
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        internal var client: Skyle_SkyleClient?
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }

        private var call: UnaryCall<Skyle_ResetMessage, Skyle_StatusMessage>?

        private func run(options: Skyle_ResetMessage,
                         completion: @escaping (_ message: Skyle_StatusMessage?, _ state: ET.States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.call = client.reset(options)
                self?.call!.response.whenComplete({ response in
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

extension ET.Reset {
    /// Restarts the eyetracking, calibration and API services of Skyle.
    public func services() {
        self.run(options: Skyle_ResetMessage.with {
            $0.services = true
        })
    }
    /// Restarts Skyle.
    public func device() {
        self.run(options: Skyle_ResetMessage.with {
            $0.device = true
        })
    }
    /// Deletes all `Profile`s on Skyle and all user settings including calibrations,
    /// auto standby and auto pause.
    public func data() {
        self.run(options: Skyle_ResetMessage.with {
            $0.data = true
        })
    }
}
