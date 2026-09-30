import Foundation
import PegCore

public enum R2Failure: Error, Equatable {
    case unreachable
    case forbidden
    case preconditionFailed
    case status(Int)
    case invalidResponse
}

public enum R2Condition: Equatable, Sendable {
    case none
    case ifNoneMatch
    case ifMatch(String)
}

public struct R2Object: Equatable, Sendable {
    public let data: Data
    public let etag: String

    public init(data: Data, etag: String) {
        self.data = data
        self.etag = etag
    }
}

public protocol RemoteStore: Sendable {
    func list() async throws -> [String: String]
    func get(_ path: String) async throws -> R2Object
    func put(_ path: String, data: Data, condition: R2Condition) async throws -> String
    func delete(_ path: String) async throws
}

public struct R2Client: RemoteStore {
    private struct Response {
        let data: Data
        let report: HTTPReport
    }

    private let config: R2Config
    private let prefix: String
    private let signer: SigV4

    public init(config: R2Config) {
        self.config = config
        self.prefix = config.prefix ?? ""
        self.signer = SigV4(
            accessKeyId: config.accessKeyId,
            secretAccessKey: config.secretAccessKey,
            region: "auto",
            service: "s3"
        )
    }

    public func list() async throws -> [String: String] {
        var result: [String: String] = [:]
        var token: String?
        repeat {
            var query = ["list-type": "2"]
            if !prefix.isEmpty {
                query["prefix"] = prefix
            }
            if let token {
                query["continuation-token"] = token
            }
            let response = try await send(method: "GET", path: "/\(config.bucket)", query: query, body: nil, condition: .none)
            guard let page = S3ListPage.parse(response.data) else { throw R2Failure.invalidResponse }
            for object in page.objects {
                guard let path = SyncPath.path(for: object.key, prefix: prefix) else { continue }
                result[path] = object.etag
            }
            token = page.nextToken
        } while token != nil
        return result
    }

    public func get(_ path: String) async throws -> R2Object {
        let response = try await send(method: "GET", path: objectPath(path), query: [:], body: nil, condition: .none)
        return R2Object(data: response.data, etag: try etag(of: response.report))
    }

    public func put(_ path: String, data: Data, condition: R2Condition) async throws -> String {
        let response = try await send(method: "PUT", path: objectPath(path), query: [:], body: data, condition: condition)
        return try etag(of: response.report)
    }

    public func delete(_ path: String) async throws {
        _ = try await send(method: "DELETE", path: objectPath(path), query: [:], body: nil, condition: .none)
    }

    private func objectPath(_ path: String) -> String {
        "/\(config.bucket)/" + SyncPath.key(for: path, prefix: prefix)
    }

    private func etag(of report: HTTPReport) throws -> String {
        guard let value = report.header("etag") else { throw R2Failure.invalidResponse }
        return S3ListPage.cleanETag(value)
    }

    private func send(
        method: String,
        path: String,
        query: [String: String],
        body: Data?,
        condition: R2Condition
    ) async throws -> Response {
        let host = "\(config.accountId).r2.cloudflarestorage.com"
        let queryString = SigV4.canonicalQuery(query)
        let address = "https://\(host)" + SigV4.encode(path, keepSlash: true) + (queryString.isEmpty ? "" : "?" + queryString)
        let payloadHash = SigV4.sha256Hex(body ?? Data())
        let timestamp = SigV4.timestamp(Date())
        var headers = [
            "host": host,
            "x-amz-content-sha256": payloadHash,
            "x-amz-date": timestamp
        ]
        switch condition {
        case .none:
            break
        case .ifNoneMatch:
            headers["if-none-match"] = "*"
        case let .ifMatch(etag):
            headers["if-match"] = "\"\(etag)\""
        }
        let authorization = signer.authorization(
            method: method,
            path: path,
            query: query,
            headers: headers,
            payloadHash: payloadHash,
            timestamp: timestamp
        )
        var lines = headers.filter { $0.key != "host" }.map { "\($0.key): \($0.value)" }
        lines.append("authorization: \(authorization)")
        lines.append("content-type: application/octet-stream")
        lines.append("expect:")
        let headerText = lines.joined(separator: "\n") + "\n"
        let response = try await Task.detached {
            try R2Client.curl(method: method, address: address, headerText: headerText, body: body)
        }.value
        switch response.report.status {
        case 200..<300:
            return response
        case 401, 403:
            throw R2Failure.forbidden
        case 412:
            throw R2Failure.preconditionFailed
        default:
            throw R2Failure.status(response.report.status)
        }
    }

    private static func curl(method: String, address: String, headerText: String, body: Data?) throws -> Response {
        let manager = FileManager.default
        let directory = manager.temporaryDirectory.appendingPathComponent("peg-sync-" + UUID().uuidString)
        try manager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: directory) }
        let received = directory.appendingPathComponent("received")
        var arguments = [
            "--silent",
            "--path-as-is",
            "--max-time", "120",
            "--request", method,
            "--header", "@-",
            "--output", received.path,
            "--write-out", HTTPReport.format
        ]
        if let body {
            let sending = directory.appendingPathComponent("sending")
            try body.write(to: sending)
            arguments += ["--data-binary", "@" + sending.path]
        }
        arguments.append(address)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = arguments
        let input = Pipe()
        let output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            throw R2Failure.unreachable
        }
        input.fileHandleForWriting.write(Data(headerText.utf8))
        try? input.fileHandleForWriting.close()
        let written = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw R2Failure.unreachable }
        guard let report = HTTPReport.parse(written) else { throw R2Failure.invalidResponse }
        let data = (try? Data(contentsOf: received)) ?? Data()
        return Response(data: data, report: report)
    }
}
