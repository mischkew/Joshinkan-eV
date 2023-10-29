@testable import Joshinkan
import libfcgi
import XCTest

struct FixtureFile {
  let file: FileHandle
  let size: UInt64
  
  static func forResource(resource: String, withExtension: String) -> FixtureFile? {
    guard let filepath = Bundle.module.url(forResource: resource, withExtension: withExtension) else {
      return nil
    }
    
    guard let file = try? FileHandle(forReadingFrom: filepath) else {
      return nil
    }
    
    guard let _ = try? file.seekToEnd() else {
      return nil
    }
    
    guard let size = try? file.offset() else {
      return nil
    }
    
    guard let _ = try? file.seek(toOffset: 0) else {
      return nil
    }
    
    return FixtureFile(file: file, size: size)
  }
}

func readFixture(forResource: String, withExtension: String, line: UInt = #line) -> FixtureFile? {
  guard let file = FixtureFile.forResource(resource: forResource, withExtension: withExtension) else {
    XCTFail("Failed to read resource", line: line)
    return nil
  }
  return file
}

/**
 * Reads HTTP request from a file and sets the environment variables to the received
 * headers. Returns a FileHandle from which the body can be read.
 */
func readRequest(fromResource: String, withExtension: String) -> FileHandle? {
  guard let filepath = Bundle.module.url(forResource: fromResource, withExtension: withExtension) else {
    return nil
  }

  guard let file = freopen(filepath.path(), "r", stdin) else {
    return nil
  }
  defer { fclose(file) }
  
  guard let methodLine = readLine() else { return nil }
  let parts = methodLine.split(separator: " ", maxSplits: 2)
  let method = String(parts[0])
  let scriptName = String(parts[1])
  let httpVersion = String(parts[2])
  setenv("REQUEST_METHOD", method, 1)
  setenv("SCRIPT_NAME", scriptName, 1)
  setenv("SERVER_PROTOCOL", httpVersion, 1)
  
  while let line = readLine() {
    if line == "" { break }
    let parts = line.split(separator: ":", maxSplits: 1)
    let key = parts[0].uppercased().replacingOccurrences(of: "-", with: "_").trimmingCharacters(in: CharacterSet.whitespaces)
    let value = parts[1].trimmingCharacters(in: CharacterSet.whitespaces)
    setenv(key, value, 1)
  }
  
  let duplicated = dup(fileno(file))
  return FileHandle(fileDescriptor: duplicated)
}

final class FCGITests: XCTestCase {
  func test_readBody() {
    guard let file = readRequest(fromResource: "adult-registration", withExtension: "request") else {
      XCTFail("Failed to read request")
      return
    }
    
    let body = readBody(file)
    XCTAssertEqual(body?.suffix(46), "on\n------WebKitFormBoundaryiB5iskbmcAfH1zPo--\n")
  }
  
  func test_readFormData() {
    guard let file = readRequest(fromResource: "adult-registration", withExtension: "request") else {
      XCTFail("Failed to read request")
      return
    }
    
    let formData = readFormData(file)
    XCTAssertEqual(formData?["first_name"], "sven")
    XCTAssertEqual(formData?["last_name"], "mkw")
    XCTAssertEqual(formData?["email"], "sven.mkw@gmail.com")
    XCTAssertEqual(formData?["phone"], "123456789")
    XCTAssertEqual(formData?["age"], "23")
    XCTAssertEqual(formData?["privacy"], "on")
  }
  
  func test_response() {

    let capture = Capture()
    defer { capture.close() }

    let response = StringResponse(status: .OK, body: "Hello World")
    response.write()
    
    let body = capture.read()
    XCTAssertEqual(body, "HTTP/1.1 200 OK\nContent-Length: 11\n\nHello World\n")
  }
  
  func test_responseWithStatus() {
    FCGI_Accept()
    defer { FCGI_Finish() }
    let capture = Capture()
    defer { capture.close() }

    let response = StringResponse(status: .NOT_FOUND, body: "Hello World")
    response.write()
    
    let body = capture.read()
    XCTAssertEqual(body, "HTTP/1.1 404 Not Found\nContent-Length: 11\n\nHello World\n")
  }
  
  func test_responseWithHeaders() {
    FCGI_Accept()
    defer { FCGI_Finish() }
    let capture = Capture()
    defer { capture.close() }

    let response = StringResponse(
      status: .OK,
      headers: ["Content-Type": "text/html"],
      body: "Hello World"
    )
    response.write()
    
    let body = capture.read()
    XCTAssertEqual(body, "HTTP/1.1 200 OK\nContent-Length: 11\nContent-Type: text/html\n\nHello World\n")
  }
  
  func test_jsonResponse() {
    FCGI_Accept()
    defer {
      FCGI_Finish()
    }
    let capture = Capture()
    defer { capture.close() }

    let json = ["message": "Hello World"]
    let response = JSONResponse(
      status: .OK,
      json: json
    )
    response.write()
    
    let body = capture.read()
    XCTAssertEqual(body, "HTTP/1.1 200 OK\nContent-Length: 25\nContent-Type: application/json\n\n{\"message\":\"Hello World\"}\n")
  }
  
  func test_jsonResponseWithHeader() {
    FCGI_Accept()
    defer {
      FCGI_Finish()
    }
    let capture = Capture()
    defer { capture.close() }

    let json = ["message": "Hello World"]
    let response = JSONResponse(
      status: .OK,
      headers: ["Custom-Header": "Is-Me"],
      json: json
    )
    response.write()
    
    let body = capture.read()
    XCTAssertEqual(
      body,
      "HTTP/1.1 200 OK\n"
        + "Content-Length: 25\n"
        + "Content-Type: application/json\n"
        + "Custom-Header: Is-Me\n\n"
        + "{\"message\":\"Hello World\"}\n"
    )
  }
}

class Capture {
  let pipe = Pipe()
  let recoverFd = dup(STDOUT_FILENO)
  
  init() {
    assert(recoverFd >= 0)
    let fd = dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    assert(fd >= 0)
  }
  
  func read() -> String {
    let data = pipe.fileHandleForReading.availableData
    return String(decoding: data, as: UTF8.self)
  }
  
  func close() {
    try? pipe.fileHandleForReading.close()
    try? pipe.fileHandleForWriting.close()
    dup2(STDOUT_FILENO, recoverFd)
  }
}
