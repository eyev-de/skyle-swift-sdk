import XCTest
import Combine
@testable import SkyleSwiftSDK

final class SkyleSwiftSDKTests: XCTestCase {
    private let et = ET()
    private var cancellables = Set<AnyCancellable>()
    
    override func tearDown() {
        self.cancellables.removeAll()
    }
    
    func testConnectivity() {
        let exp = XCTestExpectation(description: #function)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            XCTAssert(connectivity == .ready)
            exp.fulfill()
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testCalibration() {
        let exp = XCTestExpectation(description: #function)
        let calibration = self.et.calibration
        self.et.$grpcError.sink(receiveValue: { error in
            guard let error = error else { return }
            print(error)
        }).store(in: &self.cancellables)
        calibration.$state.sink(receiveValue: { state in
            print(state)
        }).store(in: &self.cancellables)
        calibration.$currentPoint.sink { point in
            if point == (ET.Calibration.Points.Five.count - 1) {
                exp.fulfill()
            }
        }.store(in: &self.cancellables)
        calibration.$point.sink { point in
            print(point)
        }.store(in: &self.cancellables)
        
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            calibration.start(points: ET.Calibration.Points.Five, stopHID: true)
        }.store(in: &self.cancellables)
        
        
        wait(for: [exp], timeout: 100)
    }
    
    func testControlStream() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$stream.sink { isStreaming in
            XCTAssert(isStreaming)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.stream = true
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testControlPause() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$pause.sink { isPaused in
            XCTAssert(isPaused)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.pause = true
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testControlUnpause() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$pause.sink { isPaused in
            XCTAssert(!isPaused)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.pause = false
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testControlEnablePause() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$pause.sink { isPauseEnabled in
            XCTAssert(isPauseEnabled)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.enablePause = true
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testControlDisablePause() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$pause.sink { isPauseEnabled in
            XCTAssert(!isPauseEnabled)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.enablePause = false
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testControlEnableStandby() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$pause.sink { isStandbyEnabled in
            XCTAssert(isStandbyEnabled)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.enableStandby = true
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testControlDisableStandby() {
        let exp = XCTestExpectation(description: #function)
        let control = self.et.control
        control.$pause.sink { isStandbyEnabled in
            XCTAssert(!isStandbyEnabled)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            control.enableStandby = false
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testVersion() {
        let exp = XCTestExpectation(description: #function)
        let version = self.et.version
        version.$version.sink { versions in
            XCTAssert(versions.firmware != "")
            XCTAssert(versions.eyetracker != "")
            XCTAssert(versions.calib != "")
            XCTAssert(versions.base != "")
//            XCTAssert(versions.isDemo)
            XCTAssert(versions.serial > 0)
            XCTAssert(versions.skyleType > 0)
            exp.fulfill()
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            version.get()
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 2)
    }
    
    func testGaze() {
        let exp = XCTestExpectation(description: #function)
        let gaze = self.et.gaze
        gaze.$point.sink { point in
            XCTAssert(point.x != 0 && point.y != 0)
            exp.fulfill()
        }.store(in: &self.cancellables)
        gaze.$state.sink { state in
            XCTAssert(state == .running)
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            gaze.start()
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 5)
    }
    
    func testPositioning() {
        let exp = XCTestExpectation(description: #function)
        let positioning = self.et.positioning
        positioning.$position.sink { position in
            XCTAssert(position.left.x != 0 && position.left.y != 0)
            XCTAssert(position.right.x != 0 && position.right.y != 0)
            exp.fulfill()
        }.store(in: &self.cancellables)
        positioning.$state.sink { state in
            XCTAssert(state == .running)
        }.store(in: &self.cancellables)
        self.et.$connectivity.removeDuplicates().sink { connectivity in
            guard connectivity == .ready else {
                return
            }
            positioning.start()
        }.store(in: &self.cancellables)
        wait(for: [exp], timeout: 5)
    }

    static var allTests = [
        ("testConnectivity", testConnectivity),
        ("testCalibration", testCalibration),
        ("testControlStream", testControlStream),
        ("testControlPause", testControlPause),
        ("testControlUnpause", testControlUnpause),
        ("testVersion", testVersion),
        ("testGaze", testGaze),
        ("testPositioning", testPositioning),
    ]
}
