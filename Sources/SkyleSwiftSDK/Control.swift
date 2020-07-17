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
        @Published public var stream: Bool = false {
            willSet {
                self.stream(on: newValue)
            }
        }
        
        @Published private(set) public var isOldiOs: Bool = false
        
        @Published private(set) public var isNotZoomed: Bool = false
        
        @Published private(set) public var fixationFilter: Int = 20
        
        @Published private(set) public var gazeFilter: Int = 11
        
        @Published private(set) public var options: Skyle_Options? = nil
        
        private var cancellables: Set<AnyCancellable> = []
        private let grpc = GRPCExecutor()
        
        private func run(options: Skyle_OptionMessage, completion: @escaping (Skyle_Options?, States) -> () = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                self.grpc.call(client.configure)(options)
                    .sink(receiveCompletion: {
                        switch $0 {
                        case .failure(let status):
                            completion(nil, .failed(status))
                            break
                        case .finished:
                            break
                        }
                    }, receiveValue: { control in
                        DispatchQueue.main.async {
                            self.enablePause = control.enablePause
                            self.enableStandby = control.enableStandby
                            self.guidance = control.guidance
                            self.pause = control.pause
                            self.stream = control.stream
                            if control.hasFilter {
                                if control.filter.gazeFilter >= 3 {
                                    self.gazeFilter = Int(control.filter.gazeFilter)
                                }
                                if control.filter.fixationFilter >= 3 {
                                    self.fixationFilter = Int(control.filter.fixationFilter)
                                }
                            }
                            if control.hasIPadOptions {
                                self.isOldiOs = control.iPadOptions.isOldiOs
                                self.isNotZoomed = control.iPadOptions.isNotZommed
                            }
                            self.options = control
                            completion(control, .finished)
                        }
                    }).store(in: &self.cancellables)
            }
        }
        
        deinit {
            self.cancellables.removeAll()
        }
        
    }
}

extension ET.Control {
    public func get(completion: @escaping (Skyle_Options?, ET.States) -> () = {_, _ in}) {
        self.run(options: Skyle_OptionMessage(), completion: completion)
    }
    
    private func stream(on: Bool, guided: Bool = false) {
        guard self.stream != on else {
            return
        }
        self.run(options: Skyle_OptionMessage.with {
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
        self.run(options: Skyle_OptionMessage.with {
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
        self.run(options: Skyle_OptionMessage.with {
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
        self.run(options: Skyle_OptionMessage.with {
            $0.options = Skyle_Options.with {
                $0.enablePause = on
                $0.enableStandby = self.enableStandby
                $0.pause = self.pause
                $0.stream = self.stream
            }
        })
    }
    
    public func setiPadOptions(isOldiOs: Bool, isNotZoomed: Bool) {
        guard self.isNotZoomed != isNotZoomed || self.isOldiOs != isOldiOs else {
            return
        }
        self.run(options: Skyle_OptionMessage.with {
            $0.options.iPadOptions.isNotZommed = isNotZoomed
            $0.options.iPadOptions.isOldiOs = isOldiOs
        })
    }
    
    public func setGazeFilter(_ value: Int, completion: @escaping (Skyle_Options?, ET.States) -> () = {_, _ in}) {
        self.run(options: Skyle_OptionMessage.with {
            $0.options.filter.gazeFilter = ET.Control.filterBoundaries(value)
            $0.options.filter.fixationFilter = ET.Control.filterBoundaries(self.fixationFilter)
        }) { options, state in
            completion(options, state)
        }
    }
    
    public func setFixationFilter(_ value: Int, completion: @escaping (Skyle_Options?, ET.States) -> () = {_, _ in}) {
        self.run(options: Skyle_OptionMessage.with {
            $0.options.filter.gazeFilter = ET.Control.filterBoundaries(self.gazeFilter)
            $0.options.filter.fixationFilter = ET.Control.filterBoundaries(value)
        }) { options, state in
            completion(options, state)
        }
    }
    
    public static func filterBoundaries(_ value: Int) -> Int32 {
        return Int32(min(max(value, 3), 33))
    }
    
}
