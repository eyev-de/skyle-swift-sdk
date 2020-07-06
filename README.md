# SkyleSwiftSDK

This is the official swift SDK for the [Skyle eye-tracker](https://eyev.de/skyle) sold by the eyeV GmbH. The SDK is based on the [Skyle gRPC protos](https://github.com/eyev-de/Skyle.proto) and [Apples Combine framework](https://developer.apple.com/documentation/combine).

It works on >= macOS 10.15 Catalina and >= iPadOS 13

# Usage

**Important: Update to the latest firmware (>= v3.0) on your eye tracker before using this!**

# Example

To dive straight in you can generate a Playground with the repository using [arena](https://github.com/finestructure/Arena).

Just follow the install instructions and execute the following:

```bash
arena https://github.com/eyev-de/skyle-swift-sdk@from:1.0.0
```
After that paste the following code into the Playground file, connect Skyle to your computer and start the Playground.
The SwiftUI part will work in an iPadOS >= 13 app (on device and in the Simulator) and a Mac Catalyst app.

```swift

import SkyleSwiftSDK
import PlaygroundSupport
import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var et: ET
    @ObservedObject var gaze: ET.Gaze
    @ObservedObject var version: ET.Version
    @ObservedObject var positioning: ET.Positioning
    @ObservedObject var control: ET.Control
    @ObservedObject var stream: ET.MjpegStream
    
    init() {
        let et = ET()
        self.et = et
        self.gaze = et.gaze
        self.version = et.version
        self.positioning = et.positioning
        self.control = et.control
        self.stream = et.stream
    }
    
    var body: some View {
        VStack {
            Text("Welcome to Skyle").font(.system(.title)).padding()
            Text("Frimware version: \(self.version.firmware)")
            Text("Current gaze point: x: \(Int(self.gaze.point.x.rounded())) y: \(Int(self.gaze.point.y.rounded()))")
            GeometryReader { proxy in
                ZStack {
                    if self.stream.cgimage != nil {
                        Image(nsImage: NSImage(cgImage: self.stream.cgimage!, size: NSSize(width: self.stream.cgimage!.width, height: self.stream.cgimage!.height))).resizable()
                            .frame(width: 100 / self.factor, height: 100)
                    } else {
                    Rectangle()
                        .fill(Color.gray)
                    }
                    if self.positioning.isPresent {
                        Circle().fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .position(x: self.calculateX(self.positioning.position.left.x, proxy: proxy), y: self.calculateY(self.positioning.position.left.y, proxy: proxy))
                        Circle().fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .position(x: self.calculateX(self.positioning.position.right.x, proxy: proxy), y: self.calculateY(self.positioning.position.right.y, proxy: proxy))
                    }
                }
            }
            .frame(width: 100 / self.factor, height: 100)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(self.et.$connectivity) { connected in
            if connected == .ready {
                self.gaze.start()
                self.positioning.start()
                self.control.stream = true
                self.stream.start()
            }
        }
    }
    
    private var factor: CGFloat {
        return CGFloat(ET.Positioning.Height / ET.Positioning.Width)
    }
    
    private func calculateX(_ value: Double, proxy: GeometryProxy) -> CGFloat {
        let width = Double(proxy.size.height / self.factor)
        let v = CGFloat(value / ET.Positioning.Width * width)
        return v + (proxy.size.width - proxy.size.height / self.factor) / 2
    }
    
    private func calculateY(_ value: Double, proxy: GeometryProxy) -> CGFloat {
        let height = Double(proxy.size.height)
        return CGFloat(value / ET.Positioning.Height * height)
    }
}

PlaygroundPage.current.setLiveView(ContentView())


```

![](misc/SkyleSwiftSDKDemo.webm)

# Swift Package Manager

You can also include SkyleSwiftSDK with SPM:

Just add the following to your `dependencies` in your Package.swift file.

```swift

.package(url: "https://github.com/eyev-de/skyle-swift-sdk.git", from: "1.0.0"),

```

Alternatively, you can add it to your project in Xcode. Go to File -> Swift Packages -> Add Package Dependency...


# Meta

(c) 2020 eyeV GmbH, written by Konstantin Wachendorff

Distributed under the MIT license. See LICENSE for more information.

Also see our other repos here

# Support

If you bought the Skyle eye tracker and need support, please contact support@eyev.de.



