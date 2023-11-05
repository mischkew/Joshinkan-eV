//
//  File.swift
//
//
//  Created by Sven Mischkewitz on 29.10.23.
//

import Foundation

@testable import Joshinkan
import libfcgi
import XCTest

final class MailServerTests: XCTestCase {
    func test_registerAdult() throws {
        let _ = readRequest(fromResource: "adult-registration", withExtension: "request")
        FCGI_Accept()
        defer { FCGI_Finish() }

        XCTAssertEqual(env("SCRIPT_NAME"), "/api/trial-registration")
//    XCTAssertEqual(handle?.fileDescriptor, FileHandle.standardInput.fileDescriptor)
        let body = readBody()
        // let all = try? handle?.readToEnd()
//        let data = FileHandle.standardInput.availableData
//        let other = handle?.availableData

        print("lol")
        // TODO: need a stub implementation for MailServer
        // MailServer(smtpHostname: "example.com", domain: "localhost", smtp: nil)
    }
}
