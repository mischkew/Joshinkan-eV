import ArgumentParser
import Foundation
import libfcgi

@main
struct MailServer: ParsableCommand {
  static var configuration = CommandConfiguration(
    abstract: "FCGI to send emails from the Joshinkan web registration form.",
    discussion: "Needs to be launched via spawn-fcgi."
  )
  
  @Option(
    name: .customLong("hostname"),
    help: "Hostname for the SMTP server, including protocol and port."
  )
  var smtpHostname: String = "smtps://smtp.gmail.com:465"
  
  @Option(
    name: .customLong("email"),
    help: """
    Send emails from this email address. Can either be email only or a combination of
    name and email, i.e. 'smith@example.com' or 'John Smith <smith@example.com>'.
    """,
    transform: User.init
  )
  var smtpUser: User
  
  @Option(name: .customLong("password"), help: "Password for the email account.")
  var smtpPassword: String
  
  @Option(
    name: .customLong("cc"),
    help: """
    A list of emails to send in cc. Can either be email only or a combination of name
    and email, i.e. 'smith@example.com' or 'John Smith <smith@example.com>'.
    """,
    transform: User.init
  )
  var cc: [User] = []
  
  @Option(
    name: .customLong("bcc"),
    help: """
    A list of emails to send in bcc. Can either be email only or a combination of name
    and email, i.e. 'smith@example.com' or 'John Smith <smith@example.com>'.
    """,
    transform: User.init
  )
  var bcc: [User] = []
  
  mutating func run() {
    var count = 0
    
    while FCGI_Accept() >= 0 {
      count += 1
      
      // headers
      libfcgi.FCGI_puts("Content-type: text/html\r\n")
      libfcgi.FCGI_puts("\r\n")
      
//      libfcgi.FCGI_puts("Hello world!<br>\r\n")
//      let keys = ProcessInfo.processInfo.environment.keys.joined(separator: " ")
//      libfcgi.FCGI_puts("\(keys)\n")
//
//      let scriptName = ProcessInfo.processInfo.environment["SCRIPT_NAME"]!
//      libfcgi.FCGI_puts("\(scriptName)\n")
//      libfcgi.FCGI_puts("Request number \(count)")
      
      // email
      let mail = Mail(
        from: smtpUser,
        to: [User(name: "Other Me", email: "sven.mkw@gmail.com")],
        cc: cc,
        bcc: bcc,
        subject: "Hello world - \(count)",
        body: "Some body text --- count: \(count)"
      )
      let smtp = SMTP(
        email: smtpUser.email,
        password: smtpPassword,
        hostname: smtpHostname
      )
      guard (try? smtp.send(mail)) != nil else {
        FCGI_puts("Failed to send email at usage count \(count)")
        return
      }
      
      FCGI_puts("Email sent at usage conut \(count)")
    }
    
    // TODO:
    // - read form encoded body
    // - send email
    // - return success/ error json
    // - do this inside fcgi loop
    // - in frontend: catch submission, on success forward to "registered" page
  }
}
