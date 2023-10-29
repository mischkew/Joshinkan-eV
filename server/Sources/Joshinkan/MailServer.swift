import ArgumentParser
import Foundation

import libfcgi

let routeTrialRegistration = Route(path: URL(string: "/api/trial-registration")!) { server in
  // TODO:
  // - read json body
  // - validate that all keys are present and contain the correct data type/ ranges
  // - construct email template
  // - send registration details to cc/bcc list + smtpUser
  // - send separate acknowledgement email to registrating user
  let mail = Mail(
    from: server.smtpUser,
    to: [User(name: "Sven", email: "sven.mkw@gmail.com")],    
    replyTo: server.replyTo,
    subject: "A test mail",
    body: "A test body"
  )

  do {
    try server.smtp.send(mail)
  } catch is SmtpError {
    return JSONResponse(status: .INTERNAL_SERVER_ERROR, json: ["error": "Failed to send email."])
  } catch {
    return JSONResponse(status: .INTERNAL_SERVER_ERROR, json: ["error": "Unknown error."])
  }
  
  let json = ["message": "Email sent."]
  return JSONResponse(status: .OK, json: json)
}

let routePrintEnv = Route(path: URL(string: "/api/env")!) { _ in
  let keys = ProcessInfo.processInfo.environment.keys
  var body = ""
  for key in keys.sorted() {
    let value = ProcessInfo.processInfo.environment[key]
    body += "\(key): \(value ?? "NOT SET")<br/>\n"
  }

  return StringResponse(status: .OK, headers: ["Content-Type": "text/html"], body: body)
}

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
  
  @Option(
    name: .customLong("reply-to"),
    help: """
    Reply to this address when the user presses the "Reply" button in their email
    client. Can either be email only or a combination of name and email, i.e.
    'smith@example.com' or 'John Smith <smith@example.com>'.
    """,
    transform: User.init
  )
  var replyTo: User? = nil
  
  lazy var smtp: SMTP = .init(
    email: smtpUser.email,
    password: smtpPassword,
    hostname: smtpHostname
  )
  
  lazy var ROUTES: [Route] = {
    var routes = [
      routeTrialRegistration
    ]
    
#if DEBUG
    routes += [
      routePrintEnv
    ]
#endif
    return routes
  }()
  
  mutating func run() {
    loopAcceptAndDo {
      matchAndExecuteRoutes(routes: self.ROUTES, server: &self)
    }
  }
}
