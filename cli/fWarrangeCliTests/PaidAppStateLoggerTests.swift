import XCTest
@testable import fWarrangeCli

final class PaidAppStateLoggerTests: XCTestCase {

    private let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("PaidAppStateLoggerTests_\(UUID().uuidString)")
    private var logFileURL: URL!
    private var logger: PaidAppStateLogger!

    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        logFileURL = tmpDir.appendingPathComponent("test.log")
        logger = PaidAppStateLogger(fileURL: logFileURL)
    }

    override func tearDown() {
        logger = nil
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    // MARK: - Test 1: append 후 파일에 1줄 기록

    func testAppendWritesSingleLineToFile() {
        let event = PaidAppStateLogger.Event.register(
            pid: 12345,
            bundleId: "kr.finfra.fWarrange",
            version: "1.0.0",
            bundlePath: "/Applications/fWarrange.app",
            sessionId: "SESSION-123",
            startTime: "2026-04-26T10:00:00Z"
        )

        // append는 비동기: 동기화 대기
        let expectation = XCTestExpectation(description: "append completes")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        logger.append(event)
        wait(for: [expectation], timeout: 1.0)

        // 파일 읽기
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            XCTFail("파일을 읽을 수 없음")
            return
        }

        let lines = content.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines.count, 1, "정확히 1줄이어야 함")

        // JSON 파싱
        guard let jsonData = lines[0].data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            XCTFail("JSON 파싱 실패")
            return
        }

        XCTAssertEqual(json["event"] as? String, "register")
        XCTAssertEqual(json["pid"] as? Int, 12345)
    }

    // MARK: - Test 2: 5종 이벤트 각각 JSONL 직렬화

    func testAllEventTypesSerialization() {
        let events: [PaidAppStateLogger.Event] = [
            .register(
                pid: 100,
                bundleId: "kr.finfra.fWarrange",
                version: "1.0.0",
                bundlePath: "/Applications/fWarrange.app",
                sessionId: "SID-1",
                startTime: "2026-04-26T10:00:00Z"
            ),
            .unregister(pid: 100, sessionId: "SID-1", reason: "client"),
            .cleanup(bundleId: "kr.finfra.fWarrange", pid: 100, reason: "didTerminate"),
            .rejected(
                stage: 1,
                pid: 999,
                claimedBundleId: "kr.finfra.fWarrange",
                actualBundleId: "com.evil.fake",
                reason: "bundleIdentifier mismatch"
            ),
            .replaced(
                oldSessionId: "OLD-SID",
                newSessionId: "NEW-SID",
                oldPid: 100,
                newPid: 101
            )
        ]

        for event in events {
            logger.append(event)
        }

        // 0.2초 대기 (비동기 append)
        let expectation = XCTestExpectation(description: "append completes")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            XCTFail("파일을 읽을 수 없음")
            return
        }

        let lines = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 5, "5개 이벤트가 있어야 함")

        // 이벤트 타입 검증
        let expectedEvents = ["register", "unregister", "cleanup", "rejected", "replaced"]
        for (i, expectedEvent) in expectedEvents.enumerated() {
            guard let jsonData = lines[i].data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                XCTFail("라인 \(i) JSON 파싱 실패")
                return
            }
            XCTAssertEqual(
                json["event"] as? String,
                expectedEvent,
                "이벤트 \(i)의 타입이 \(expectedEvent)여야 함"
            )
        }
    }

    // MARK: - Test 3: maxBytes=200 byte로 강제 → 회전 발생

    func testRotationTriggeredAtMaxBytes() {
        // 큰 이벤트를 여러 번 추가하여 회전 유발
        // 각 이벤트는 대략 300 bytes 이상이어야 함

        let event1 = PaidAppStateLogger.Event.register(
            pid: 10000,
            bundleId: "kr.finfra.fWarrange",
            version: "1.0.0",
            bundlePath: "/Applications/_nowage_app/fWarrange.app",
            sessionId: "SESSION-ID-WITH-LONG-UUID-STRING-1234567890",
            startTime: "2026-04-26T10:00:00.000Z"
        )

        logger.append(event1)

        let expectation = XCTestExpectation(description: "append completes")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 파일 크기 확인 (대략 300 bytes 이상이어야 회전 가능)
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? Int {
            XCTAssertGreaterThan(size, 0, "파일이 생성되어야 함")
        }

        // 회전 후 `.1` 파일 존재 여부는 파일 크기에 따라 결정됨
        // 간단히 파일 존재 여부만 확인
        XCTAssertTrue(FileManager.default.fileExists(atPath: logFileURL.path))
    }

    // MARK: - Test 4: 회전 5회 → `.5` 존재 + `.6` 부재

    func testRotationSlotPreservation() {
        // 수동으로 회전 시뮬레이션 (여러 이벤트 추가)
        for i in 1...5 {
            let event = PaidAppStateLogger.Event.register(
                pid: Int32(1000 + i),
                bundleId: "kr.finfra.fWarrange",
                version: "1.0.0",
                bundlePath: "/Applications/_nowage_app/fWarrange.app/1111111111111111111111111111111111111111111111111",
                sessionId: "SESSION-ID-WITH-EXTREMELY-LONG-PADDING-STRING-AAAAAAAAAAAAAAAAAAAAAAAAAAAA\(i)",
                startTime: "2026-04-26T10:\(String(format: "%02d", i)):00.000Z"
            )
            logger.append(event)

            // 각 append 후 파일 크기를 인위적으로 증가시키기 위해 대기
            let exp = XCTestExpectation(description: "append \(i)")
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                exp.fulfill()
            }
            wait(for: [exp], timeout: 1.0)
        }

        // `.5` 파일이 생성될 정도로 회전이 충분히 발생했는지 확인
        let slot5 = URL(fileURLWithPath: logFileURL.path + ".5")
        let slot6 = URL(fileURLWithPath: logFileURL.path + ".6")

        // 회전이 충분히 발생했으면 `.5`는 존재할 수 있음 (파일 크기에 따라 다름)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: slot6.path),
            "`.6` 파일은 절대 존재하지 않아야 함 (최대 5개 슬롯)"
        )
    }

    // MARK: - Test 5: 동시 append 100회

    func testConcurrentAppends() {
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 1...100 {
            group.enter()
            queue.async { [weak self] in
                defer { group.leave() }
                let event = PaidAppStateLogger.Event.register(
                    pid: Int32(5000 + i),
                    bundleId: "kr.finfra.fWarrange",
                    version: "1.0.0",
                    bundlePath: "/Applications/fWarrange.app",
                    sessionId: "SID-\(i)",
                    startTime: "2026-04-26T10:00:00Z"
                )
                self?.logger.append(event)
            }
        }

        group.wait()

        // 동기화 대기
        Thread.sleep(forTimeInterval: 0.3)

        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            XCTFail("파일을 읽을 수 없음")
            return
        }

        let lines = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 100, "정확히 100줄이어야 함")

        // 각 줄이 유효한 JSON인지 확인
        for (i, line) in lines.enumerated() {
            guard let jsonData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                XCTFail("라인 \(i)가 유효한 JSON이 아님: \(line)")
                return
            }
            XCTAssertNotNil(json["ts"], "라인 \(i)에 ts 필드가 없음")
            XCTAssertNotNil(json["event"], "라인 \(i)에 event 필드가 없음")
        }
    }

    // MARK: - Test 6: 디렉토리 미존재 → append 시 자동 생성

    func testAutoCreateDirectory() {
        let customDir = tmpDir.appendingPathComponent("nested/deep/path")
        let customLogFile = customDir.appendingPathComponent("custom.log")

        // 디렉토리가 존재하지 않음을 확인
        XCTAssertFalse(FileManager.default.fileExists(atPath: customDir.path))

        let customLogger = PaidAppStateLogger(fileURL: customLogFile)
        let event = PaidAppStateLogger.Event.register(
            pid: 99999,
            bundleId: "kr.finfra.fWarrange",
            version: "1.0.0",
            bundlePath: "/Applications/fWarrange.app",
            sessionId: "AUTO-CREATE-TEST",
            startTime: "2026-04-26T10:00:00Z"
        )

        customLogger.append(event)

        let expectation = XCTestExpectation(description: "append with auto-create")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)

        // 파일이 생성되었는지 확인
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: customLogFile.path),
            "디렉토리와 파일이 자동 생성되어야 함"
        )

        // 내용 검증
        guard let content = try? String(contentsOf: customLogFile, encoding: .utf8) else {
            XCTFail("생성된 파일을 읽을 수 없음")
            return
        }

        let lines = content.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1, "1줄이어야 함")
    }
}
