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
    /**
        Control exposes `Publisher` which hold information about Skyles settings.
        These are partially user specific and should be pulled after a user is selected via `Profile.select`,
        `Profiles.set` or `Profiles.delete`.
     */
    public class Control: ObservableObject {
        
        /// A reference to the current client, which represents the gRPC connection.
        /// This is automatically updated by `ET` when a new connection is established.
        internal var client: Skyle_SkyleClient?
        /// Internal empty constructor
        internal init() {}
        /// Internal constructor passing a possible client
        internal init(_ client: Skyle_SkyleClient?) {
            self.client = client
        }
        /// The `enablePause` property exposes a `Publisher` which enables / disables the automatic pause mode.
        /// This mode allows a user to pause the cursor movement by looking into the camera (center of Skyle) for a couple of seconds.
        @Published public var enablePause: Bool = false {
            willSet {
                self.autoPause(on: newValue)
            }
        }
        /// The `enableStandby` property exposes a `Publisher` which enables / disables the automatic standby mode.
        /// This mode allows Skyle to go into a standby mode when the iPad's sceen is locked by pressing the power button for example.
        /// Skyle in standby should save some power and let the iPad live longer on battery power.
        @Published public var enableStandby: Bool = false {
            willSet {
                self.autoStandby(on: newValue)
            }
        }
        /// The `guidance` property exposes a `Publisher` which indicates the deprecated guidance stream.
        @Published private(set) public var guidance: Bool = false
        /// The `pause` property exposes a `Publisher` which indicates if mouse movement is paused. It can also be set explicitely.
        @Published public var pause: Bool = false {
            willSet {
                self.pause(on: newValue)
            }
        }
        /// The `stream` property exposes a `Publisher` which indicates if the video stream is enabled or disabled.
        /// This can be set explicitely.
        @Published public var stream: Bool = false {
            willSet {
                self.stream(on: newValue)
            }
        }
        /// The `isOldiOs` property exposes a `Publisher` which indicates if the iOS version is old `<` iOS version 13.4.
        @Published private(set) public var isOldiOs: Bool = false
        /// The `isNotZoomed` property exposes a `Publisher` which indicates if the iPad is using the zoomed UI.
        /// Determined by UIScreen.main.nativeScale > 2 means zoomed, UIScreen.main.nativeScale == 2 means not zoomed
        @Published private(set) public var isNotZoomed: Bool = false
        /// The `fixationFilter` property exposes a `Publisher` which indicates the currently active user's fixation filter setting.
        /// This is enabled when the currently active user's skill is set to `Skyle_Profile.Skill.high`.
        /// minimum value is 3, maximum value is 33
        @Published private(set) public var fixationFilter: Int = 20
        /// The `gazeFilter` property exposes a `Publisher` which indicates the currently active user's gaze filter setting.
        /// This is enabled when the currently active user's skill is set to `Skyle_Profile.Skill.high`.
        /// minimum value is 3, maximum value is 33
        @Published private(set) public var gazeFilter: Int = 11
        /// The `options` property exposes a `Publisher` which holds the full set of options.
        /// This is just for convenience. Please use the `Publishers` obove.
        @Published private(set) public var options: Skyle_Options?
        
        private var cancellables: Set<AnyCancellable> = []
        private let grpc = GRPCExecutor()
        
        private func run(options: Skyle_OptionMessage, completion: @escaping (Skyle_Options?, States) -> Void = {_, _ in}) {
            guard let client = self.client else {
                return
            }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                self.grpc.call(client.configure)(options)
                    .sink(receiveCompletion: {
                        switch $0 {
                        case .failure(let status):
                            completion(nil, .failed(status))
                        case .finished:
                            break
                        }
                    }, receiveValue: { control in
                        DispatchQueue.main.async { [weak self] in
                            self?.enablePause = control.enablePause
                            self?.enableStandby = control.enableStandby
                            self?.guidance = control.guidance
                            self?.pause = control.pause
                            self?.stream = control.stream
                            if control.hasFilter {
                                if control.filter.gazeFilter >= 3 {
                                    self?.gazeFilter = Int(control.filter.gazeFilter)
                                }
                                if control.filter.fixationFilter >= 3 {
                                    self?.fixationFilter = Int(control.filter.fixationFilter)
                                }
                            }
                            if control.hasIPadOptions {
                                self?.isOldiOs = control.iPadOptions.isOldiOs
                                self?.isNotZoomed = control.iPadOptions.isNotZommed
                            }
                            self?.options = control
                            completion(control, .finished)
                        }
                    }).store(in: &self.cancellables)
            }
        }
        /// Simple cleanup cancels all gRPC calls
        deinit {
            self.cancellables.removeAll()
        }
        
    }
}

extension ET.Control {
    /**
        Gets the current settings of the eyetracker Skyle and the currently active user selected via `Profile.select`,
        `Profiles.set` or `Profiles.delete`.
        This is managed by `ET` whenever a connection is established or lost. But needs to be done when ever a user profile is selected.
        - Parameters:
            - completion: A completion handler
            - options: A `Skyle_Options` instance containing the current settings Skyle and the currently active user or nil
            - state: A `ET.States` containing possible errors.
     */
    public func get(completion: @escaping (_ options: Skyle_Options?, _ state: ET.States) -> Void = {_, _ in}) {
        self.run(options: Skyle_OptionMessage(), completion: completion)
    }
    /**
        Sets the iPad options `isOldiOs` and `isNotZoomed`.
        - Parameters:
            - isOldiOs: Old means iOS version `<` 13.4.
            - isNotZoomed: Determined by UIScreen.main.nativeScale `>` 2 means zoomed, UIScreen.main.nativeScale == 2 means not zoomed
            - completion: A completion handler
            - options: A `Skyle_Options` instance containing the current settings Skyle and the currently active user or nil
            - state: A `ET.States` containing possible errors.
     */
    public func setiPadOptions(isOldiOs: Bool,
                               isNotZoomed: Bool,
                               completion: @escaping (_ options: Skyle_Options?, _ state: ET.States) -> Void = {_, _ in}) {
        guard self.isNotZoomed != isNotZoomed || self.isOldiOs != isOldiOs else {
            return
        }
        self.run(options: Skyle_OptionMessage.with {
            $0.options.iPadOptions.isNotZommed = isNotZoomed
            $0.options.iPadOptions.isOldiOs = isOldiOs
        }) { options, state in
            completion(options, state)
        }
    }
    /**
        Sets the gaze filter setting.
        - Parameters:
            - value: min value = 3, max value 33, the higher the more lag.
            - completion: A completion handler
            - options: A `Skyle_Options` instance containing the current settings Skyle and the currently active user or nil
            - state: A `ET.States` containing possible errors.
     */
    public func setGazeFilter(_ value: Int, completion: @escaping (_ options: Skyle_Options?, _ state: ET.States) -> Void = {_, _ in}) {
        self.run(options: Skyle_OptionMessage.with {
            $0.options.filter.gazeFilter = ET.Control.filterBoundaries(value)
            $0.options.filter.fixationFilter = ET.Control.filterBoundaries(self.fixationFilter)
        }) { options, state in
            completion(options, state)
        }
    }
    /**
        Sets the fixation filter setting.
        - Parameters:
            - value: min value = 3, max value 33, the higher the slower the cursor moves when a fixation has been detected internally.
                    Higher could mean more accurate when closing in on a target.
            - completion: A completion handler
            - options: A `Skyle_Options` instance containing the current settings Skyle and the currently active user or nil
            - state: A `ET.States` containing possible errors.
     */
    public func setFixationFilter(_ value: Int, completion: @escaping (_ options: Skyle_Options?, _ state: ET.States) -> Void = {_, _ in}) {
        self.run(options: Skyle_OptionMessage.with {
            $0.options.filter.gazeFilter = ET.Control.filterBoundaries(self.gazeFilter)
            $0.options.filter.fixationFilter = ET.Control.filterBoundaries(value)
        }) { options, state in
            completion(options, state)
        }
    }
    /**
        Makes sure the input of a filter setting is between 3 and 33.
        - Parameters:
            - value: Integer input.
        - returns: A value between 3 and 33.
     */
    public static func filterBoundaries(_ value: Int) -> Int32 {
        return Int32(min(max(value, 3), 33))
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
}
