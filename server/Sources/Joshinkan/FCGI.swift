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

protocol Response {
    func write() -> Void
}

struct StringResponse: Response {
  var status: HTTPStatus
  var headers: [String: String] = [:]
  var body: String // NOTE(sven): Must be an ascii string!

  func write() {
    FCGI_puts("HTTP/1.1 \(status.rawValue) \(status.name)")
    FCGI_puts("Content-Length: \(body.lengthOfBytes(using: .ascii))")
    for (key, value) in headers.sorted(by: { $0.0 < $1.0 }) {
      FCGI_puts("\(key): \(value)")
    }
    FCGI_puts("")
    FCGI_puts(body)
  }
}

let jsonEncoder = JSONEncoder()

struct JSONResponse: Response {
  var status: HTTPStatus
  var headers: [String: String] = [:]
  var json: Codable

  func jsonDataToString(_ data: Data) -> String? {
    return String(data: data, encoding: .ascii)
  }

  func write() {
    let body: String
    do {
      let data = try jsonEncoder.encode(json)
      body = jsonDataToString(data)!
    } catch {
      let body = try! jsonEncoder.encode(["error": "internal error", "message": "could not construct response"])
      let response = StringResponse(
        status: .INTERNAL_SERVER_ERROR,
        headers: ["Content-Type": "application/json"],
        body: jsonDataToString(body)!
      )
      response.write()
      return
    }

    var headers = self.headers
    headers["Content-Type"] = "application/json"
    
    let response = StringResponse(status: status, headers: headers, body: body)
    response.write()
  }
}

func env(_ key: String) -> String? {
  return ProcessInfo.processInfo.environment[key]
}

func contentLength() -> Int? {
  guard let contentLengthEnv = env("CONTENT_LENGTH") else {
    return nil
  }
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
  guard components[components.endIndex-1] == "--\n" else { return nil }

  var formData: [String:FormValue] = [:]
  
  // NOTE(sven): Skip the first component which is always empty and skip the last
  // component which are double hyphens.
  for i in 1 ..< components.count - 1 {
    let component = components[i]
    let componentParts = component.split(separator: "\n\n", maxSplits: 1)
    let componentHeader = componentParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
    var headers: [String:String] = [:]

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
      if case .list(var values) = formData[prefix] {
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


struct Route {
  let path: URL
  let handler: (_ server: inout MailServer) -> Response
}

func matchAndExecuteRoutes(routes: [Route], server: inout MailServer) {
  guard let scriptName = env("SCRIPT_NAME") else { return }
  let current = URL(string: scriptName)
  
  for route in routes {
    if current == route.path {
      let response = route.handler(&server)
      response.write()
      return
    }
  }
  
  let response = StringResponse(status: .NOT_FOUND, headers: ["Location": "/404"], body: "")
  response.write()
}
