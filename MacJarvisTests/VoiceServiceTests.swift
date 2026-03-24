import XCTest
@testable import MacJarvis

final class VoiceServiceTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let service = VoiceService()
        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isTranscribing)
        XCTAssertFalse(service.isSpeaking)
        XCTAssertEqual(service.transcript, "")
        XCTAssertFalse(service.isModelLoaded)
    }

    @MainActor
    func testModelStatus_notLoaded() {
        let service = VoiceService()
        XCTAssertEqual(service.modelStatusLabel, "MODEL NOT LOADED")
    }

    @MainActor
    func testCanRecord_requiresModel() {
        let service = VoiceService()
        XCTAssertFalse(service.canRecord)
    }

    @MainActor
    func testAudioLevel_initiallyZero() {
        let service = VoiceService()
        XCTAssertEqual(service.audioLevel, 0.0)
    }
}
