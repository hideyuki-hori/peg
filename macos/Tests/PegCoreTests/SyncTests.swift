import XCTest
@testable import PegCore

private struct SyncCases: Decodable {
    struct Planner: Decodable {
        let name: String
        let remote: [String: String]
        let local: [String: String]
        let state: [String: SyncEntry]
        let actions: [SyncAction]
    }

    struct Guard: Decodable {
        let name: String
        let remoteCount: Int
        let localCount: Int
        let stateCount: Int
        let trashCount: Int
        let deleteCount: Int
        let blocked: Bool
    }

    struct Filter: Decodable {
        let path: String
        let included: Bool
    }

    struct Conflict: Decodable {
        let path: String
        let device: String
        let stamp: String
        let expected: String
    }

    let planner: [Planner]
    let `guard`: [Guard]
    let filter: [Filter]
    let conflict: [Conflict]

    static func load() throws -> SyncCases {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("sync-cases.json")
        return try JSONDecoder().decode(SyncCases.self, from: Data(contentsOf: url))
    }
}

final class SyncCasesTests: XCTestCase {
    func testPlannerMatchesSharedCases() throws {
        let cases = try SyncCases.load().planner
        XCTAssertEqual(cases.count, 13)
        for item in cases {
            XCTAssertEqual(SyncPlanner.plan(remote: item.remote, local: item.local, state: item.state), item.actions, item.name)
        }
    }

    func testGuardMatchesSharedCases() throws {
        let cases = try SyncCases.load().guard
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            XCTAssertEqual(
                SyncPlanner.isBlocked(
                    remoteCount: item.remoteCount,
                    localCount: item.localCount,
                    stateCount: item.stateCount,
                    trashCount: item.trashCount,
                    deleteCount: item.deleteCount
                ),
                item.blocked,
                item.name
            )
        }
    }

    func testFilterMatchesSharedCases() throws {
        let cases = try SyncCases.load().filter
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            XCTAssertEqual(SyncFilter.includes(item.path), item.included, item.path)
        }
    }

    func testConflictNameMatchesSharedCases() throws {
        let cases = try SyncCases.load().conflict
        XCTAssertFalse(cases.isEmpty)
        for item in cases {
            XCTAssertEqual(ConflictName.make(path: item.path, device: item.device, stamp: item.stamp), item.expected, item.path)
        }
    }
}

final class SyncSupportTests: XCTestCase {
    func testConflictStampUsesLocalTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .gmt
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 14, minute: 5, second: 59)) ?? Date(timeIntervalSince1970: 0)
        XCTAssertEqual(ConflictName.stamp(date, calendar: calendar), "20260930-1405")
    }

    func testKeyIsNormalizedToNFC() {
        let decomposed = "メモ/か\u{3099}.md"
        XCTAssertEqual(Array(SyncPath.key(for: decomposed, prefix: "vault/").unicodeScalars), Array("vault/メモ/が.md".unicodeScalars))
        XCTAssertEqual(SyncPath.path(for: "vault/" + decomposed, prefix: "vault/").map { Array($0.unicodeScalars) }, Array("メモ/が.md".unicodeScalars))
    }

    func testPathRejectsKeysOutsidePrefix() {
        XCTAssertEqual(SyncPath.path(for: "a.md", prefix: ""), "a.md")
        XCTAssertNil(SyncPath.path(for: "other/a.md", prefix: "vault/"))
        XCTAssertNil(SyncPath.path(for: "vault/", prefix: "vault/"))
        XCTAssertNil(SyncPath.path(for: "vault/dir/", prefix: "vault/"))
    }

    func testStateRoundTrips() throws {
        let state = SyncState(entries: ["a.md": SyncEntry(etag: "e1", hash: "h1")])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try state.encoded().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(SyncState.load(from: url), state)
        XCTAssertEqual(SyncState.load(from: url.appendingPathExtension("missing")), SyncState())
    }
}

final class SigV4Tests: XCTestCase {
    private let emptyHash = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    func testHashesEmptyPayload() {
        XCTAssertEqual(SigV4.sha256Hex(Data()), emptyHash)
    }

    func testSignsGetVanilla() {
        let signer = SigV4(
            accessKeyId: "AKIDEXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY",
            region: "us-east-1",
            service: "service"
        )
        let header = signer.authorization(
            method: "GET",
            path: "/",
            query: [:],
            headers: ["Host": "example.amazonaws.com", "X-Amz-Date": "20150830T123600Z"],
            payloadHash: emptyHash,
            timestamp: "20150830T123600Z"
        )
        XCTAssertEqual(
            header,
            "AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, SignedHeaders=host;x-amz-date, Signature=5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31"
        )
    }

    func testSignsS3GetObject() {
        let header = s3Signer().authorization(
            method: "GET",
            path: "/test.txt",
            query: [:],
            headers: [
                "host": "examplebucket.s3.amazonaws.com",
                "range": "bytes=0-9",
                "x-amz-content-sha256": emptyHash,
                "x-amz-date": "20130524T000000Z"
            ],
            payloadHash: emptyHash,
            timestamp: "20130524T000000Z"
        )
        XCTAssertEqual(
            header,
            "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;range;x-amz-content-sha256;x-amz-date, Signature=f0e8bdb87c964420e857bd35b5d6ed310bd44f0170aba48dd91039c6036bdb41"
        )
    }

    func testSignsS3ListWithQuery() {
        let header = s3Signer().authorization(
            method: "GET",
            path: "/",
            query: ["prefix": "J", "max-keys": "2"],
            headers: [
                "host": "examplebucket.s3.amazonaws.com",
                "x-amz-content-sha256": emptyHash,
                "x-amz-date": "20130524T000000Z"
            ],
            payloadHash: emptyHash,
            timestamp: "20130524T000000Z"
        )
        XCTAssertEqual(
            header,
            "AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20130524/us-east-1/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=34b48302e7b5fa45bde8084f4b7868a86f0a534bc59db6670ed5711ef69dc6f7"
        )
    }

    func testEncodesPathAndQuery() {
        XCTAssertEqual(SigV4.encode("/bucket/メモ/a b+c.md", keepSlash: true), "/bucket/%E3%83%A1%E3%83%A2/a%20b%2Bc.md")
        XCTAssertEqual(SigV4.encode("a/b~c_d-e.f", keepSlash: false), "a%2Fb~c_d-e.f")
        XCTAssertEqual(
            SigV4.canonicalQuery(["prefix": "vault/", "list-type": "2", "continuation-token": "a=b"]),
            "continuation-token=a%3Db&list-type=2&prefix=vault%2F"
        )
    }

    func testFormatsTimestampInUTC() {
        XCTAssertEqual(SigV4.timestamp(Date(timeIntervalSince1970: 1_440_938_160)), "20150830T123600Z")
    }

    private func s3Signer() -> SigV4 {
        SigV4(
            accessKeyId: "AKIAIOSFODNN7EXAMPLE",
            secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
            region: "us-east-1",
            service: "s3"
        )
    }
}

final class S3ListPageTests: XCTestCase {
    func testParsesObjectsAndToken() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
          <Name>bucket</Name>
          <Prefix>vault/</Prefix>
          <KeyCount>2</KeyCount>
          <IsTruncated>true</IsTruncated>
          <NextContinuationToken>token+/=</NextContinuationToken>
          <Contents>
            <Key>vault/main.md</Key>
            <ETag>&quot;abc123&quot;</ETag>
            <Size>10</Size>
          </Contents>
          <Contents>
            <Key>vault/メモ/a &amp; b.md</Key>
            <ETag>"def456-2"</ETag>
            <Size>20</Size>
          </Contents>
        </ListBucketResult>
        """
        XCTAssertEqual(
            S3ListPage.parse(Data(xml.utf8)),
            S3ListPage(
                objects: [
                    S3Object(key: "vault/main.md", etag: "abc123"),
                    S3Object(key: "vault/メモ/a & b.md", etag: "def456-2")
                ],
                nextToken: "token+/="
            )
        )
    }

    func testParsesLastPage() {
        let xml = "<ListBucketResult><IsTruncated>false</IsTruncated><KeyCount>0</KeyCount></ListBucketResult>"
        XCTAssertEqual(S3ListPage.parse(Data(xml.utf8)), S3ListPage(objects: [], nextToken: nil))
    }

    func testRejectsUnexpectedDocuments() {
        XCTAssertNil(S3ListPage.parse(Data("<Error><Code>AccessDenied</Code></Error>".utf8)))
        XCTAssertNil(S3ListPage.parse(Data("not xml".utf8)))
        XCTAssertNil(S3ListPage.parse(Data("<ListBucketResult><IsTruncated>true</IsTruncated></ListBucketResult>".utf8)))
    }
}
