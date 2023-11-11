//
//  File.swift
//
//
//  Created by Sven Mischkewitz on 26.09.23.
//

import Foundation
import libfcgi

enum HTTPStatus: Int {
    case OK = 200
    case BAD_REQUEST = 400
    case NOT_FOUND = 404
    case INTERNAL_SERVER_ERROR = 500

    var name: String {
        switch self {
        case .OK: return "OK"
        case .BAD_REQUEST: return "Bad Request"
        case .NOT_FOUND: return "Not Found"
        case .INTERNAL_SERVER_ERROR: return "Internal Server Error"
        }
    }
}

let jsonEncoder = JSONEncoder()

struct Response {
    var status: HTTPStatus
    var headers: [String: String] = [:]
    var text: String?
    var json: Codable?

    func jsonDataToString(_ data: Data) -> String? {
        String(data: data, encoding: .ascii)
    }

    private func writeBody(body: String) {
        FCGI_puts("HTTP/1.1 \(status.rawValue) \(status.name)")

        let length = body.lengthOfBytes(using: .ascii)
        FCGI_puts("Content-Length: \(length)")

        for (key, value) in headers.sorted(by: { $0.0 < $1.0 }) {
            FCGI_puts("\(key): \(value)")
        }

        FCGI_puts("")
        FCGI_puts(body)
    }

    private func writeJson() {
        let body: String
        do {
            let data = try jsonEncoder.encode(json!)
            body = jsonDataToString(data)!
        } catch {
            let data = try! jsonEncoder.encode([
                "error": "internal error",
                "message": "could not construct response",
            ])
            let error = Response(
                status: .INTERNAL_SERVER_ERROR,
                headers: ["Content-Type": "application/json"],
                text: jsonDataToString(data)!
            )
            error.write()
            return
        }

        var headers = headers
        headers["Content-Type"] = "application/json"

        let response = Response(status: status, headers: headers, text: body)
        response.write()
    }

    func write() {
        if let json {
            writeJson()
        } else {
            writeBody(body: text ?? "")
        }
    }
}

func env(_ key: String) -> String? {
    ProcessInfo.processInfo.environment[key]
}

func contentLength() -> Int? {
    guard let contentLengthEnv = env("CONTENT_LENGTH") else { return nil }
    return Int(contentLengthEnv)
}

func readBody(_ file: FileHandle = FileHandle.standardInput) -> String? {
    guard let contentLength = contentLength() else { return nil }
    // TODO: assert content type charset
    guard let bodyData = try? file.read(upToCount: contentLength) else { return nil }
    let body = String(decoding: bodyData, as: UTF8.self)
    return body
}

enum FormValue: Equatable {
    case plain(_ string: String)
    case list(_ list: [String])
}

func readFormData(_ file: FileHandle = FileHandle.standardInput) -> [String: FormValue]? {
    guard let contentLength = contentLength() else { return nil }
    guard let contentType = env("CONTENT_TYPE") else { return nil }

    let contentTypeRegex = /^multipart\/form-data;\s*boundary=(?<boundary>.+)$/
    guard let match = try? contentTypeRegex.wholeMatch(in: contentType) else { return nil }
    let boundary = match.output.boundary

    guard let body = readBody(file) else { return nil }
    let components = body.components(separatedBy: "--" + boundary)
    guard components[components.endIndex - 1] == "--\n" else { return nil }

    var formData: [String: FormValue] = [:]

    // NOTE(sven): Skip the first component which is always empty and skip the last
    // component which are double hyphens.
    for i in 1 ..< components.count - 1 {
        let component = components[i]
        let componentParts = component.split(separator: "\n\n", maxSplits: 1)
        let componentHeader = componentParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        var headers: [String: String] = [:]

        for line in componentHeader.split(separator: "\n") {
            let headerParts = line.split(separator: ":", maxSplits: 1)
            let key = String(headerParts[0]).capitalized
            let value = String(headerParts[1])
            headers[key] = value.trimmingCharacters(in: .whitespaces)
        }

        guard let contentDisposition = headers["Content-Disposition"] else { return nil }

        // i.e. form-data; name=\"first_name\"
        let contentDispositionParts = contentDisposition.split(separator: ";")
        guard contentDispositionParts.count == 2 else { return nil }

        // i.e. name=\"first_name\"
        let nameStatement = contentDispositionParts[1].trimmingCharacters(in: .whitespaces)
        let statementParts = nameStatement.split(separator: "=")
        guard statementParts.count == 2 else { return nil }
        guard statementParts[0] == "name" else { return nil }

        let componentName = statementParts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let componentBody = componentParts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        if componentName.hasSuffix("[]") {
            let endIndex = componentName.index(componentName.endIndex, offsetBy: -3)
            let prefix = String(componentName[...endIndex])
            if case var .list(values) = formData[prefix] {
                values.append(componentBody)
                formData[prefix] = .list(values)
            } else {
                formData[prefix] = .list([componentBody])
            }
        } else {
            formData[componentName] = .plain(componentBody)
        }
    }

    return formData
}

func loopAcceptAndDo(_ handler: () -> Void) {
    while FCGI_Accept() >= 0 {
        handler()
    }
}

enum Method: String {
    case GET
    case POST
}

struct Route<Context> {
    let path: URL
    var method: Method = .GET
    let handler: (_ context: Context) -> Response
}


func matchRoutes<Context>(_ routes: [Route<Context>], context: Context) -> Response {
    guard
        let scriptName = env("SCRIPT_NAME"),
        let method = env("REQUEST_METHOD") else {
        return Response(
            status: .INTERNAL_SERVER_ERROR,
            text: "Server not initialised"
        )
    }
    let current = URL(string: scriptName)

    for route in routes {
        if current == route.path && method == route.method.rawValue {
            return route.handler(context)
        }
    }

    return Response(
        status: .NOT_FOUND,
        headers: ["Content-Type": "text/html"],
        text: "<center><h1>Not Found</h1></center>"
    )
}

func matchAndExecuteRoutes<Context>(_ routes: [Route<Context>], context: Context) {
    let response = matchRoutes(routes, context: context)
    response.write()
}