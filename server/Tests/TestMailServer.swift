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

final class SMTPStub: SMTPClient {
    var mails: [Mail] = []
    func send(_ mail: Mail) throws {
        mails.append(mail)
    }
}

struct Client {
    let context: ServerContext
    func request(_ requestName: String) -> Response {
        guard readRequest(fromResource: requestName, withExtension: "request") != nil else {
            fatalError("Request \(requestName).request not found")
        }
        
        FCGI_Accept()
        defer { FCGI_Finish() }
        return matchRoutes(ROUTES, context: context)
    }
}

extension Response {
    func read() -> String {
        let capture = Capture()
        write()
        return capture.read()
    }
    
    func flatJson() -> [String:String] {
        guard let json else { fatalError("No json defined") }
        return json as! [String:String]
    }
}

extension ServerContext {
    var smtpStub: SMTPStub {
        smtp as! SMTPStub
    }
}


func context() -> ServerContext {
    return .init(
        domain: "localhost",
        sender: User(name: "Sender", email: "sender@example.com"),
        smtp: SMTPStub(),
        replyTo: User(name: "Replier", email: "reply-to@example.com"),
        cc: [User(name: "CC", email: "cc@example.com")],
        bcc: nil
    )
}

func client() -> Client {
    return .init(context: context())
}

final class PrintEnvTests: XCTestCase {
    func test_printEnv() {
        let response = client().request("print-env")
        let text = response.read()
        XCTAssert(text.contains("CONTENT_LENGTH:"))
        XCTAssert(text.contains("SCRIPT_NAME:"))
        XCTAssert(text.contains("REQUEST_METHOD: GET"))
    }
}

final class TrialRegistrationTests: XCTestCase {
    func test_registerAdult() {
        let client = client()
        let response = client.request("adult-registration")
        XCTAssertEqual(response.status, .OK)
        XCTAssertNotNil(response.json)
        XCTAssertEqual(response.flatJson()["message"], "Email sent.")
        XCTAssertEqual(client.context.smtpStub.mails.count, 2)
        
        let registrationMail = client.context.smtpStub.mails[0]
        XCTAssertEqual(registrationMail.subject, "Anmeldung zum Probetraining: Erwachsene")
        XCTAssert(registrationMail.body.contains("Name: sven mkw"))
        XCTAssert(registrationMail.body.contains("Alter: 23"))
        XCTAssert(registrationMail.body.contains("Email: sven.mkw@gmail.com"))
        XCTAssert(registrationMail.body.contains("Telefon: 123456789"))
        
        let acknowledgementMail = client.context.smtpStub.mails[1]
        XCTAssertEqual(acknowledgementMail.subject, "Joshinkan Werder Karate - Anmeldung zum Probetraining")
        XCTAssert(acknowledgementMail.body.contains("Hallo sven"))
        XCTAssert(acknowledgementMail.body.contains("Vielen Dank für die Anmeldung zum Probetraining."))
    }
    
    func test_registerNoPrivacy() {
        let client = client()
        let response = client.request("registration-no-privacy")
        XCTAssertEqual(response.status, .BAD_REQUEST)
        XCTAssertNotNil(response.json)
        XCTAssertEqual(response.flatJson()["error"], "Form data could not be parsed.")
    }
    
    func test_registerChild() {
        let client = client()
        let response = client.request("child-registration")
        XCTAssertEqual(response.status, .OK)
        XCTAssertNotNil(response.json)
        XCTAssertEqual(response.flatJson()["message"], "Email sent.")
        XCTAssertEqual(client.context.smtpStub.mails.count, 2)
        
        let registrationMail = client.context.smtpStub.mails[0]
        XCTAssertEqual(registrationMail.subject, "Anmeldung zum Probetraining: Kinder (1)")
        XCTAssert(registrationMail.body.contains("Name: Boi Fam"))
        XCTAssert(registrationMail.body.contains("Alter: 17"))
        XCTAssertFalse(registrationMail.body.contains("Name: Girl Fam"))
        XCTAssertFalse(registrationMail.body.contains("Alter: 16"))
        
        XCTAssert(registrationMail.body.contains("Name: Dad Fam"))
        XCTAssert(registrationMail.body.contains("Email: fam@mail.com"))
        XCTAssert(registrationMail.body.contains("Telefon: 04912847"))
        
        let acknowledgementMail = client.context.smtpStub.mails[1]
        XCTAssertEqual(acknowledgementMail.subject, "Joshinkan Werder Karate - Anmeldung zum Probetraining")
        XCTAssert(acknowledgementMail.body.contains("Liebe Familie Fam"))
        XCTAssert(acknowledgementMail.body.contains("Vielen Dank für die Anmeldung von Boi zum Probetraining."))
    }
    
    func test_registerChildren() {
        let client = client()
        let response = client.request("children-registration")
        XCTAssertEqual(response.status, .OK)
        XCTAssertNotNil(response.json)
        XCTAssertEqual(response.flatJson()["message"], "Email sent.")
        XCTAssertEqual(client.context.smtpStub.mails.count, 2)
        
        let registrationMail = client.context.smtpStub.mails[0]
        XCTAssertEqual(registrationMail.subject, "Anmeldung zum Probetraining: Kinder (2)")
        XCTAssert(registrationMail.body.contains("Name: Boi Fam"))
        XCTAssert(registrationMail.body.contains("Alter: 17"))
        XCTAssert(registrationMail.body.contains("Name: Girl Fam"))
        XCTAssert(registrationMail.body.contains("Alter: 16"))
        
        XCTAssert(registrationMail.body.contains("Name: Dad Fam"))
        XCTAssert(registrationMail.body.contains("Email: fam@mail.com"))
        XCTAssert(registrationMail.body.contains("Telefon: 049127495"))
        
        let acknowledgementMail = client.context.smtpStub.mails[1]
        XCTAssertEqual(acknowledgementMail.subject, "Joshinkan Werder Karate - Anmeldung zum Probetraining")
        XCTAssert(acknowledgementMail.body.contains("Liebe Familie Fam"))
        XCTAssert(acknowledgementMail.body.contains("Vielen Dank für die Anmeldung von Boi und Girl zum Probetraining."))
    }
}