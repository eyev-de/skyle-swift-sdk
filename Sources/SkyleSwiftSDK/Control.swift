//
//  Control.swift
//  Skyle
//
//  Created by Konstantin Wachendorff on 24.06.20.
//  Copyright © 2020 eyeV GmbH.
//

import Foundation
import Combine
import CombineGRPC

extension ET {
    public class Control: ObservableObject {
        
        var client: Skyle_SkyleClient? = nil
        init() {}
        init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        
        @Published public var enablePause: Bool = false // pause modus in den ET schauen
        {
            willSet {
                self.autoPause(on: newValue)
            }
        }
        @Published public var enableStandby: Bool = false // iPad aus
        {
            willSet {
                self.autoStandby(on: newValue)
            }
        }
        @Published private(set) public var guidance: Bool = false // alter guidance stream
        @Published public var pause: Bool = false // jetzt pause oder nicht pause
        {
            willSet {
                self.pause(on: newValue)
            }
        }
        @Published public var stream: Bool = false
        {
            willSet {
                self.stream(on: newValue)
            }
        }
        
        private var cancellable: AnyCancellable?
        private let grpc = GRPCExecutor()
        
        private func call(options: Skyle_OptionMessage) {
            guard let client = self.client else {
                return
            }
            self.cancellable = self.grpc.call(client.configure)(options)
            .sink(receiveCompletion: {
                switch $0 {
                case .failure(let status):
                    print(status)
                case .finished:
                    print($0)
                }
            }, receiveValue: { control in
                DispatchQueue.main.async {
                    self.enablePause = control.enablePause
                    self.enableStandby = control.enableStandby
                    self.guidance = control.guidance
                    self.pause = control.pause
                    self.stream = control.stream
                }
            })
        }
        
        deinit {
            self.cancellable?.cancel()
        }
        
    }
}

extension ET.Control {
    public func get() {
        self.call(options: Skyle_OptionMessage())
    }
    
    private func stream(on: Bool, guided: Bool = false) {
        guard self.stream != on else {
            return
        }
        self.call(options: Skyle_OptionMessage.with {
            $0.options = Skyle_Options.with {
                $0.stream = on
                $0.enablePause = self.enablePause
                $0.enableStandby = self.enableStandby
                $0.pause = self.pause
            }
        })
    }
    
    private func pause(on: Bool) {
        guard self.pause != on else {
            return
        }
        self.call(options: Skyle_OptionMessage.with {
            $0.options = Skyle_Options.with {
                $0.pause = on
                $0.enablePause = self.enablePause
                $0.enableStandby = self.enableStandby
                $0.stream = self.stream
            }
        })
    }
    
    private func autoStandby(on: Bool) {
        guard self.enableStandby != on else {
            return
        }
        self.call(options: Skyle_OptionMessage.with {
            $0.options = Skyle_Options.with {
                $0.enableStandby = on
                $0.enablePause = self.enablePause
                $0.pause = self.pause
                $0.stream = self.stream
            }
        })
    }
    
    private func autoPause(on: Bool) {
        guard self.enablePause != on else {
            return
        }
        self.call(options: Skyle_OptionMessage.with {
            $0.options = Skyle_Options.with {
                $0.enablePause = on
                $0.enableStandby = self.enableStandby
                $0.pause = self.pause
                $0.stream = self.stream
            }
        })
    }
}