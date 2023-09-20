import Darwin
import Foundation
import libcurl

struct User: CustomStringConvertible {
  let name: String?
  let email: String

  enum ParsingError: Error {
    case INVALID_EMAIL
    case UNEXPECTED_FORMAT
  }

  var description: String {
    if let name = name {
      return "\(name) <\(email)>"
    } else {
      return "<\(email)>"
    }
  }

  static func isValidEmail(_ email: String) -> Bool {
    let emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
    return email.wholeMatch(of: emailRegex) != nil
  }
}

extension User {
  init(description: String) throws {
    let userRegex = /^(?<name>[^<>]+)?(\s*<(?<email>.+)>\s*)?/
    let match = description.wholeMatch(of: userRegex)
    guard let match = match else {
      throw User.ParsingError.UNEXPECTED_FORMAT
    }
    
    if match.output.email == nil && match.output.name != nil{
      self.email = String(match.output.name!)
      self.name = nil
    } else {
      if let name = match.output.name {
        self.name = String(name).trimmingCharacters(in: CharacterSet.whitespaces)
      } else {
        self.name = nil
      }
      
      guard let email = match.output.email else {
        throw User.ParsingError.UNEXPECTED_FORMAT
      }
      self.email = String(email)
    }
    
    guard User.isValidEmail(self.email) else {
      throw User.ParsingError.INVALID_EMAIL
    }
  }
}

struct Mail {
  let from: User
  let to: [User]
  var cc: [User] = []
  var bcc: [User] = []
  var subject: String = ""
  let body: String

  var recipients: [User] {
    to + cc + bcc
  }

  func toPayload() -> String {
    assert(!to.isEmpty)
    return """
    To: \(to.map { $0.description }.joined(separator: ", "))
    From: \(from)
    Subject: \(subject)
    Reply-To: \(from)

    \(body)
    """
  }
}

func list2curl(_ list: [String]) -> UnsafeMutablePointer<curl_slist> {
  assert(!list.isEmpty)
  var curlList: UnsafeMutablePointer<curl_slist>? = nil
  for item in list {
    curlList = curl_slist_append(curlList, item)
  }
  return curlList!
}

struct UserData {
  var payload: String
  var bytesRead = 0

  /**
   Read data from the userData buffer and place size * numItems many bytes into the
   buffer. This is used by curl for chunked data transmission.
   */
  static func curlRead(
    buffer: UnsafeMutablePointer<CChar>?,
    size: Int,
    numItems: Int,
    userData: UnsafeMutableRawPointer?
  ) -> Int {
    // NOTE(sven): userData might be a struct, thus only assing the pointer so we can
    // modify the underlying data structure
    guard let pUserData = userData?.assumingMemoryBound(to: UserData.self) else {
      // NOTE(sven): userData provided via CURLOPT_READDATA is not a pointer to UserData
      return 0
    }
    let userData = pUserData.pointee

    guard let buffer = buffer else {
      // NOTE(sven): internal curl failure, the buffer we should copy into is not
      // initialised
      return 0
    }

    let rangeStart = userData.payload.index(
      userData.payload.startIndex,
      offsetBy: userData.bytesRead
    )
    let rangeEnd = userData.payload.index(
      userData.payload.startIndex,
      offsetBy: min(userData.bytesRead + size * numItems, userData.payload.count)
    )
    guard let bytes = userData.payload[rangeStart ..< rangeEnd].data(using: .utf8) else {
      // NOTE(sven): The payload contains non-UTF8 characters
      return 0
    }

    bytes.withUnsafeBytes {
      $0.withMemoryRebound(to: CChar.self) { chars in
        // memcpy
        for (index, char) in chars.enumerated() {
          buffer[index] = char
        }
      }
    }

    pUserData.pointee.bytesRead += bytes.count
    return bytes.count
  }
}

enum SmtpError: Error {
  case curlInitFailed
}

struct SMTP {
  let email: String
  let password: String
  let hostname: String

  func send(_ mail: Mail) throws {
    guard let curl = curl_easy_init() else {
      // TODO(sven): throw a runtime error or something
      throw SmtpError.curlInitFailed
    }

    curl_easy_setopt_string(curl, CURLOPT_URL, hostname)
    curl_easy_setopt_string(curl, CURLOPT_USERNAME, email)
    curl_easy_setopt_string(curl, CURLOPT_PASSWORD, password)

    curl_easy_setopt_string(curl, CURLOPT_MAIL_FROM, mail.from.email)
    let recipients = list2curl(mail.recipients.map { $0.email })
    curl_easy_setopt_slist(curl, CURLOPT_MAIL_RCPT, recipients)

    // NOTE(sven): Swift function pointers cannot be passed to C-callbacks.
    // We always need a closure.
    curl_easy_setopt_func(curl, CURLOPT_READFUNCTION) {
      buffer, size, numItems, userData in
      UserData.curlRead(buffer: buffer, size: size, numItems: numItems, userData: userData)
    }

    var userData = UserData(payload: mail.toPayload())
    _ = withUnsafeMutablePointer(to: &userData) {
      curl_easy_setopt_pointer(curl, CURLOPT_READDATA, $0)
    }

    curl_easy_setopt_long(curl, CURLOPT_UPLOAD, 1)
    curl_easy_setopt_long(curl, CURLOPT_VERBOSE, 1)
    let result = curl_easy_perform(curl)

    if result != CURLE_OK {
      if let error = curl_easy_strerror(result) {
        let errorStr = String(cString: error)
        print("Mail sending failed: \(errorStr)")
      } else {
        print("Mail sending failed: Unknown Error")
      }
    }

    curl_slist_free_all(recipients)
    curl_easy_cleanup(curl)
  }
}
