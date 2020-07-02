//
// DO NOT EDIT.
//
// Generated by the protocol buffer compiler.
// Source: Skyle.proto
//

//
// Copyright 2018, gRPC Authors All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import Foundation
import GRPC
import NIO
import NIOHTTP1
import SwiftProtobuf


/// Usage: instantiate Skyle_SkyleClient, then call methods of this protocol to make API calls.
public protocol Skyle_SkyleClientProtocol {
  func calibrate(callOptions: CallOptions?, handler: @escaping (Skyle_CalibMessages) -> Void) -> BidirectionalStreamingCall<Skyle_calibControlMessages, Skyle_CalibMessages>
  func positioning(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions?, handler: @escaping (Skyle_PositioningMessage) -> Void) -> ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_PositioningMessage>
  func gaze(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions?, handler: @escaping (Skyle_Point) -> Void) -> ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Point>
  func getButton(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions?) -> UnaryCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Button>
  func setButton(_ request: Skyle_ButtonActions, callOptions: CallOptions?) -> UnaryCall<Skyle_ButtonActions, Skyle_ButtonActions>
  func configure(_ request: Skyle_OptionMessage, callOptions: CallOptions?) -> UnaryCall<Skyle_OptionMessage, Skyle_Options>
  func getVersions(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions?) -> UnaryCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_DeviceVersions>
  func getProfiles(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions?, handler: @escaping (Skyle_Profile) -> Void) -> ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Profile>
  func currentProfile(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions?) -> UnaryCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Profile>
  func setProfile(_ request: Skyle_Profile, callOptions: CallOptions?) -> UnaryCall<Skyle_Profile, Skyle_StatusMessage>
}

public final class Skyle_SkyleClient: GRPCClient, Skyle_SkyleClientProtocol {
  public let channel: GRPCChannel
  public var defaultCallOptions: CallOptions

  /// Creates a client for the Skyle.Skyle service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  public init(channel: GRPCChannel, defaultCallOptions: CallOptions = CallOptions()) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
  }

  /// Bidirectional streaming call to Calibrate
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata and status.
  public func calibrate(callOptions: CallOptions? = nil, handler: @escaping (Skyle_CalibMessages) -> Void) -> BidirectionalStreamingCall<Skyle_calibControlMessages, Skyle_CalibMessages> {
    return self.makeBidirectionalStreamingCall(path: "/Skyle.Skyle/Calibrate",
                                               callOptions: callOptions ?? self.defaultCallOptions,
                                               handler: handler)
  }

  /// Server streaming call to Positioning
  ///
  /// - Parameters:
  ///   - request: Request to send to Positioning.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ServerStreamingCall` with futures for the metadata and status.
  public func positioning(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions? = nil, handler: @escaping (Skyle_PositioningMessage) -> Void) -> ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_PositioningMessage> {
    return self.makeServerStreamingCall(path: "/Skyle.Skyle/Positioning",
                                        request: request,
                                        callOptions: callOptions ?? self.defaultCallOptions,
                                        handler: handler)
  }

  /// Server streaming call to Gaze
  ///
  /// - Parameters:
  ///   - request: Request to send to Gaze.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ServerStreamingCall` with futures for the metadata and status.
  public func gaze(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions? = nil, handler: @escaping (Skyle_Point) -> Void) -> ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Point> {
    return self.makeServerStreamingCall(path: "/Skyle.Skyle/Gaze",
                                        request: request,
                                        callOptions: callOptions ?? self.defaultCallOptions,
                                        handler: handler)
  }

  /// Unary call to GetButton
  ///
  /// - Parameters:
  ///   - request: Request to send to GetButton.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func getButton(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions? = nil) -> UnaryCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Button> {
    return self.makeUnaryCall(path: "/Skyle.Skyle/GetButton",
                              request: request,
                              callOptions: callOptions ?? self.defaultCallOptions)
  }

  /// Unary call to SetButton
  ///
  /// - Parameters:
  ///   - request: Request to send to SetButton.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func setButton(_ request: Skyle_ButtonActions, callOptions: CallOptions? = nil) -> UnaryCall<Skyle_ButtonActions, Skyle_ButtonActions> {
    return self.makeUnaryCall(path: "/Skyle.Skyle/SetButton",
                              request: request,
                              callOptions: callOptions ?? self.defaultCallOptions)
  }

  /// Unary call to Configure
  ///
  /// - Parameters:
  ///   - request: Request to send to Configure.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func configure(_ request: Skyle_OptionMessage, callOptions: CallOptions? = nil) -> UnaryCall<Skyle_OptionMessage, Skyle_Options> {
    return self.makeUnaryCall(path: "/Skyle.Skyle/Configure",
                              request: request,
                              callOptions: callOptions ?? self.defaultCallOptions)
  }

  /// Unary call to GetVersions
  ///
  /// - Parameters:
  ///   - request: Request to send to GetVersions.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func getVersions(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions? = nil) -> UnaryCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_DeviceVersions> {
    return self.makeUnaryCall(path: "/Skyle.Skyle/GetVersions",
                              request: request,
                              callOptions: callOptions ?? self.defaultCallOptions)
  }

  /// Server streaming call to GetProfiles
  ///
  /// - Parameters:
  ///   - request: Request to send to GetProfiles.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ServerStreamingCall` with futures for the metadata and status.
  public func getProfiles(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions? = nil, handler: @escaping (Skyle_Profile) -> Void) -> ServerStreamingCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Profile> {
    return self.makeServerStreamingCall(path: "/Skyle.Skyle/GetProfiles",
                                        request: request,
                                        callOptions: callOptions ?? self.defaultCallOptions,
                                        handler: handler)
  }

  /// Unary call to CurrentProfile
  ///
  /// - Parameters:
  ///   - request: Request to send to CurrentProfile.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func currentProfile(_ request: SwiftProtobuf.Google_Protobuf_Empty, callOptions: CallOptions? = nil) -> UnaryCall<SwiftProtobuf.Google_Protobuf_Empty, Skyle_Profile> {
    return self.makeUnaryCall(path: "/Skyle.Skyle/CurrentProfile",
                              request: request,
                              callOptions: callOptions ?? self.defaultCallOptions)
  }

  /// Unary call to SetProfile
  ///
  /// - Parameters:
  ///   - request: Request to send to SetProfile.
  ///   - callOptions: Call options; `self.defaultCallOptions` is used if `nil`.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func setProfile(_ request: Skyle_Profile, callOptions: CallOptions? = nil) -> UnaryCall<Skyle_Profile, Skyle_StatusMessage> {
    return self.makeUnaryCall(path: "/Skyle.Skyle/SetProfile",
                              request: request,
                              callOptions: callOptions ?? self.defaultCallOptions)
  }

}

/// To build a server, implement a class that conforms to this protocol.
public protocol Skyle_SkyleProvider: CallHandlerProvider {
  func calibrate(context: StreamingResponseCallContext<Skyle_CalibMessages>) -> EventLoopFuture<(StreamEvent<Skyle_calibControlMessages>) -> Void>
  func positioning(request: SwiftProtobuf.Google_Protobuf_Empty, context: StreamingResponseCallContext<Skyle_PositioningMessage>) -> EventLoopFuture<GRPCStatus>
  func gaze(request: SwiftProtobuf.Google_Protobuf_Empty, context: StreamingResponseCallContext<Skyle_Point>) -> EventLoopFuture<GRPCStatus>
  func getButton(request: SwiftProtobuf.Google_Protobuf_Empty, context: StatusOnlyCallContext) -> EventLoopFuture<Skyle_Button>
  func setButton(request: Skyle_ButtonActions, context: StatusOnlyCallContext) -> EventLoopFuture<Skyle_ButtonActions>
  func configure(request: Skyle_OptionMessage, context: StatusOnlyCallContext) -> EventLoopFuture<Skyle_Options>
  func getVersions(request: SwiftProtobuf.Google_Protobuf_Empty, context: StatusOnlyCallContext) -> EventLoopFuture<Skyle_DeviceVersions>
  func getProfiles(request: SwiftProtobuf.Google_Protobuf_Empty, context: StreamingResponseCallContext<Skyle_Profile>) -> EventLoopFuture<GRPCStatus>
  func currentProfile(request: SwiftProtobuf.Google_Protobuf_Empty, context: StatusOnlyCallContext) -> EventLoopFuture<Skyle_Profile>
  func setProfile(request: Skyle_Profile, context: StatusOnlyCallContext) -> EventLoopFuture<Skyle_StatusMessage>
}

extension Skyle_SkyleProvider {
  public var serviceName: String { return "Skyle.Skyle" }

  /// Determines, calls and returns the appropriate request handler, depending on the request's method.
  /// Returns nil for methods not handled by this service.
  public func handleMethod(_ methodName: String, callHandlerContext: CallHandlerContext) -> GRPCCallHandler? {
    switch methodName {
    case "Calibrate":
      return BidirectionalStreamingCallHandler(callHandlerContext: callHandlerContext) { context in
        return self.calibrate(context: context)
      }

    case "Positioning":
      return ServerStreamingCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.positioning(request: request, context: context)
        }
      }

    case "Gaze":
      return ServerStreamingCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.gaze(request: request, context: context)
        }
      }

    case "GetButton":
      return UnaryCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.getButton(request: request, context: context)
        }
      }

    case "SetButton":
      return UnaryCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.setButton(request: request, context: context)
        }
      }

    case "Configure":
      return UnaryCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.configure(request: request, context: context)
        }
      }

    case "GetVersions":
      return UnaryCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.getVersions(request: request, context: context)
        }
      }

    case "GetProfiles":
      return ServerStreamingCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.getProfiles(request: request, context: context)
        }
      }

    case "CurrentProfile":
      return UnaryCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.currentProfile(request: request, context: context)
        }
      }

    case "SetProfile":
      return UnaryCallHandler(callHandlerContext: callHandlerContext) { context in
        return { request in
          self.setProfile(request: request, context: context)
        }
      }

    default: return nil
    }
  }
}


// Provides conformance to `GRPCPayload` for request and response messages
extension Skyle_calibControlMessages: GRPCProtobufPayload {}
extension Skyle_CalibMessages: GRPCProtobufPayload {}
extension SwiftProtobuf.Google_Protobuf_Empty: GRPCProtobufPayload {}
extension Skyle_PositioningMessage: GRPCProtobufPayload {}
extension Skyle_Point: GRPCProtobufPayload {}
extension Skyle_Button: GRPCProtobufPayload {}
extension Skyle_ButtonActions: GRPCProtobufPayload {}
extension Skyle_OptionMessage: GRPCProtobufPayload {}
extension Skyle_Options: GRPCProtobufPayload {}
extension Skyle_DeviceVersions: GRPCProtobufPayload {}
extension Skyle_Profile: GRPCProtobufPayload {}
extension Skyle_StatusMessage: GRPCProtobufPayload {}

