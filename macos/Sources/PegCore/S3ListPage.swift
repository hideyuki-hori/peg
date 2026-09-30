import Foundation

public struct S3Object: Equatable, Sendable {
    public let key: String
    public let etag: String

    public init(key: String, etag: String) {
        self.key = key
        self.etag = etag
    }
}

public struct S3ListPage: Equatable, Sendable {
    public let objects: [S3Object]
    public let nextToken: String?

    public init(objects: [S3Object], nextToken: String?) {
        self.objects = objects
        self.nextToken = nextToken
    }

    public static func parse(_ data: Data) -> S3ListPage? {
        let reader = S3ListReader()
        let parser = XMLParser(data: data)
        parser.delegate = reader
        guard parser.parse(), reader.sawRoot else { return nil }
        guard reader.isTruncated else {
            return S3ListPage(objects: reader.objects, nextToken: nil)
        }
        guard let token = reader.nextToken, !token.isEmpty else { return nil }
        return S3ListPage(objects: reader.objects, nextToken: token)
    }

    public static func cleanETag(_ etag: String) -> String {
        etag.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

final class S3ListReader: NSObject, XMLParserDelegate {
    var objects: [S3Object] = []
    var nextToken: String?
    var isTruncated = false
    var sawRoot = false

    private var text = ""
    private var key = ""
    private var etag = ""
    private var inContents = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        text = ""
        switch elementName {
        case "ListBucketResult":
            sawRoot = true
        case "Contents":
            inContents = true
            key = ""
            etag = ""
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch elementName {
        case "Key" where inContents:
            key = text
        case "ETag" where inContents:
            etag = S3ListPage.cleanETag(text)
        case "Contents":
            inContents = false
            objects.append(S3Object(key: key, etag: etag))
        case "IsTruncated":
            isTruncated = text.trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        case "NextContinuationToken":
            nextToken = text
        default:
            break
        }
        text = ""
    }
}
