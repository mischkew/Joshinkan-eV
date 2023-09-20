import XCTest
@testable import Joshinkan

final class UserTests: XCTestCase {
  func testParseDescription_missingClosingCaret() {
    XCTAssertThrowsError(try User(description: "<missing")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.UNEXPECTED_FORMAT)
    }
  }
  
  func testParseDescription_missingOpeningCaret() {
    XCTAssertThrowsError(try User(description: "missing>")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.UNEXPECTED_FORMAT)
    }
  }
  
  func testParseDescription_textAfterEmail() {
    XCTAssertThrowsError(try User(description: "John Smith <john@example.com> shouldnotbehere")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.UNEXPECTED_FORMAT)
    }
  }
  
  func testParseDescription_caretsInName() {
    XCTAssertThrowsError(try User(description: "Jo<hn Smith <john@example.com>")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.INVALID_EMAIL)
    }
    
    XCTAssertThrowsError(try User(description: "Jo>hn Smith <john@example.com>")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.UNEXPECTED_FORMAT)
    }
    
    XCTAssertThrowsError(try User(description: "J<o>hn Smith <john@example.com>")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.INVALID_EMAIL)
    }
  }
  
  func testParseDescription_invalidEmail() {
    XCTAssertThrowsError(try User(description: "John Smith")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.INVALID_EMAIL)
    }
    
    XCTAssertThrowsError(try User(description: "invalid@invalid")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.INVALID_EMAIL)
    }
    
    XCTAssertThrowsError(try User(description: "<John Smith>")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.INVALID_EMAIL)
    }
    
    XCTAssertThrowsError(try User(description: "<invalid@i.i>")) { error in
      XCTAssertEqual(error as! User.ParsingError, User.ParsingError.INVALID_EMAIL)
    }
  }

  
  func testParseDescription_fullDescription() {
    let user = try! User(description: "John Smith <john@example.com>")
    XCTAssertEqual(user.email, "john@example.com")
    XCTAssertEqual(user.name, "John Smith")
  }
  
  func testParseDescription_fullDescriptionExtraWhitespace() {
    let user = try! User(description: "John Smith    <john@example.com>      ")
    XCTAssertEqual(user.email, "john@example.com")
    XCTAssertEqual(user.name, "John Smith")
  }
  
  func testParseDescription_emailOnly() {
    let user = try! User(description: "<john@example.com>")
    XCTAssertEqual(user.email, "john@example.com")
    XCTAssertNil(user.name)
  }
  
  func testParseDescription_emailAsName() {
    let user = try! User(description: "john@example.com")
    XCTAssertEqual(user.email, "john@example.com")
    XCTAssertNil(user.name)
  }
}
