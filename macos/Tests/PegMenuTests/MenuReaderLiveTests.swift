import AppKit
import XCTest
@testable import PegMenu

final class MenuReaderLiveTests: XCTestCase {
    func testReadsFinderMenu() async throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PEG_MENU_LIVE"] == "1", "PEG_MENU_LIVE=1 で実行")
        try XCTSkipUnless(AXIsProcessTrusted(), "アクセシビリティの許可が必要")
        let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        let pid = try XCTUnwrap(finder?.processIdentifier)
        let result = await MenuReader.read(pid: pid)
        let snapshot = try XCTUnwrap(result)
        XCTAssertGreaterThan(snapshot.items.count, 20)
        XCTAssertTrue(snapshot.items.contains { $0.path.first == "ファイル" || $0.path.first == "File" })
        for item in snapshot.items.prefix(15) {
            print(item.title)
        }
    }
}
