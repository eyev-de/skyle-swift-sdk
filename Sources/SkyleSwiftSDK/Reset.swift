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
    public class Reset: ObservableObject {
        var client: Skyle_SkyleClient? = nil
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        private var call: UnaryCall<Skyle_ResetMessage, Skyle_StatusMessage>?
        
        private func run(options: Skyle_ResetMessage, completion: @escaping (Skyle_StatusMessage?, States) -> () = {_, _ in}) {
            DispatchQueue.global(qos: .background).async {
                guard let client = self.client else {
                    return
                }
                self.call = client.reset(options)
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

extension ET.Reset {
    public func services() {
        self.run(options: Skyle_ResetMessage.with {
            $0.services = true
        })
    }
    
    public func device() {
        self.run(options: Skyle_ResetMessage.with {
            $0.device = true
        })
    }
    
    public func data() {
        self.run(options: Skyle_ResetMessage.with {
            $0.data = true
        })
    }
}
