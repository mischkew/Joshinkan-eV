@testable import Joshinkan
import libfcgi
import XCTest

struct FixtureFile {
    let file: FileHandle
    let size: UInt64

    static func forResource(resource: String, withExtension: String) -> FixtureFile? {
        guard
            let filepath = Bundle.module.url(
                forResource: resource,
                withExtension: withExtension
            ) else {
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

func readFixture(
    forResource: String,
    withExtension: String,
    line: UInt = #line
)
    -> FixtureFile? {
    guard
        let file = FixtureFile.forResource(
            resource: forResource,
            withExtension: withExtension
        ) else {
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
    guard
        let filepath = Bundle.module.url(
            forResource: fromResource,
            withExtension: withExtension
        ) else { return nil }
    guard let file = freopen(filepath.path(), "r", stdin) else { return nil }
    // defer { fclose(file) }

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
        let key = parts[0]
            .uppercased()
            .replacingOccurrences(of: "-", with: "_")
            .trimmingCharacters(in: CharacterSet.whitespaces)
        let value = parts[1].trimmingCharacters(in: CharacterSet.whitespaces)
        setenv(key, value, 1)
    }

    // NOTE(sven): The object oriented wrapper around the C-style file handle gets
    // confused when freopen and readLine are combined. We reset the file position.
    try! FileHandle.standardInput.seek(toOffset: UInt64(ftell(file)))
    return FileHandle.standardInput
}

final class HTTPTests: XCTestCase {
    func test_readBody() {
        guard
            let file = readRequest(
                fromResource: "adult-registration",
                withExtension: "request"
            ) else {
            XCTFail("Failed to read request")
            return
        }

        let body = readBody(file)
        XCTAssertEqual(
            body?.suffix(46),
            "on\n------WebKitFormBoundaryiB5iskbmcAfH1zPo--\n"
        )
    }

    func test_readFormData_adult() {
        guard
            let file = readRequest(
                fromResource: "adult-registration",
                withExtension: "request"
            ) else {
            XCTFail("Failed to read request")
            return
        }

        let formData = readFormData(file)
        XCTAssertEqual(formData?["first_name"], .plain("sven"))
        XCTAssertEqual(formData?["last_name"], .plain("mkw"))
        XCTAssertEqual(formData?["email"], .plain("sven.mkw@gmail.com"))
        XCTAssertEqual(formData?["phone"], .plain("123456789"))
        XCTAssertEqual(formData?["age"], .plain("23"))
        XCTAssertEqual(formData?["privacy"], .plain("on"))
    }

    func test_readFormData_child() {
        guard
            let file = readRequest(
                fromResource: "child-registration",
                withExtension: "request"
            ) else {
            XCTFail("Failed to read request")
            return
        }

        let formData = readFormData(file)
        XCTAssertEqual(formData?["child_first_name"], .list(["Boi"]))
        XCTAssertEqual(formData?["child_last_name"], .list(["Fam"]))
        XCTAssertEqual(formData?["child_age"], .list(["17"]))
        XCTAssertEqual(formData?["first_name"], .plain("Dad"))
        XCTAssertEqual(formData?["last_name"], .plain("Fam"))
        XCTAssertEqual(formData?["email"], .plain("fam@mail.com"))
        XCTAssertEqual(formData?["phone"], .plain("04912847"))
        XCTAssertEqual(formData?["age"], .plain(""))
        XCTAssertEqual(formData?["privacy"], .plain("on"))
    }

    func test_readFormData_children() {
        guard
            let file = readRequest(
                fromResource: "children-registration",
                withExtension: "request"
            ) else {
            XCTFail("Failed to read request")
            return
        }

        let formData = readFormData(file)
        XCTAssertEqual(formData?["child_first_name"], .list(["Boi", "Girl"]))
        XCTAssertEqual(formData?["child_last_name"], .list(["Fam", "Fam"]))
        XCTAssertEqual(formData?["child_age"], .list(["17", "16"]))
        XCTAssertEqual(formData?["first_name"], .plain("Dad"))
        XCTAssertEqual(formData?["last_name"], .plain("Fam"))
        XCTAssertEqual(formData?["email"], .plain("fam@mail.com"))
        XCTAssertEqual(formData?["phone"], .plain("049127495"))
        XCTAssertEqual(formData?["age"], .plain(""))
        XCTAssertEqual(formData?["privacy"], .plain("on"))
    }

    func test_response() {
        let capture = Capture()

        let response = Response(status: .OK, text: "Hello World")
        response.write()

        let body = capture.read()
        XCTAssertEqual(body, "HTTP/1.1 200 OK\nContent-Length: 11\n\nHello World\n")
    }

    func test_responseWithStatus() {
        FCGI_Accept()
        defer { FCGI_Finish() }
        let capture = Capture()

        let response = Response(status: .NOT_FOUND, text: "Hello World")
        response.write()

        let body = capture.read()
        XCTAssertEqual(
            body,
            "HTTP/1.1 404 Not Found\nContent-Length: 11\n\nHello World\n"
        )
    }

    func test_responseWithHeaders() {
        FCGI_Accept()
        defer { FCGI_Finish() }
        let capture = Capture()

        let response = Response(
            status: .OK,
            headers: ["Content-Type": "text/html"],
            text: "Hello World"
        )
        response.write()

        let body = capture.read()
        XCTAssertEqual(
            body,
            "HTTP/1.1 200 OK\nContent-Length: 11\nContent-Type: text/html\n\nHello World\n"
        )
    }

    func test_jsonResponse() {
        FCGI_Accept()
        defer { FCGI_Finish() }

        let capture = Capture()

        let json = ["message": "Hello World"]
        let response = Response(
            status: .OK,
            json: json
        )
        response.write()

        let body = capture.read()
        XCTAssertEqual(
            body,
            "HTTP/1.1 200 OK\nContent-Length: 25\nContent-Type: application/json\n\n{\"message\":\"Hello World\"}\n"
        )
    }

    func test_jsonResponseWithHeader() {
        FCGI_Accept()
        defer {
            FCGI_Finish()
        }
        let capture = Capture()

        let json = ["message": "Hello World"]
        let response = Response(
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

    func test_capture() {
        print("not captured 1")
        let capture = Capture()
        print("captured")
        print("double captured")

        capture.restore()
        print("not captured 2 ")
        let text = capture.read()
        XCTAssertEqual(text, "captured\ndouble captured\n")
    }
}

class Capture {
    var savedStdout: Int32
    var buffer: [CChar]

    // NOTE(sven): Increase this size if more than the default number of characters need
    // to be captured.
    init(_ size: Int32 = 4096) {
        savedStdout = dup(STDOUT_FILENO)
        assert(savedStdout >= 0)

        buffer = [CChar](repeating: 0, count: Int(size))
        let file = freopen("/dev/null", "a", stdout)
        assert(file != nil)
        assert(fileno(file) == fileno(stdout))

        buffer.withUnsafeMutableBufferPointer { buf in
            setbuffer(file, buf.baseAddress, size)
        }
    }

    func read() -> String {
        String(cString: buffer)
    }

    func restore() {
        if savedStdout >= 0 {
            dup2(savedStdout, STDOUT_FILENO)
            close(savedStdout)
            setbuf(stdout, nil)
            savedStdout = -1
        }
    }

    deinit {
        restore()
    }
}
