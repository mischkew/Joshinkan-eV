import ArgumentParser
import Foundation

// NOTE(sven): We provide a stub implementation during testing.
@main
struct MailServerCommand: ParsableCommand {
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

    @Option(
        name: .customLong("domain"),
        help: """
        Domain name of the webserver this mail server is running for, including
        protocol and port, i.e. https://joshinkan.de or http://localhost:3000.
        """
    )
    var domain: String

    lazy var smtp: SMTP = .init(
        email: smtpUser.email,
        password: smtpPassword,
        hostname: smtpHostname
    )

    mutating func run() {
        let context = ServerContext(
            domain: domain,
            sender: smtpUser,
            smtp: smtp,
            replyTo: replyTo,
            cc: cc,
            bcc: bcc
        )
        loopAcceptAndDo {
            matchAndExecuteRoutes(ROUTES, context: context)
        }
    }
}

class ServerContext {
    let domain: String
    let sender: User
    let smtp: SMTPClient
    let replyTo: User?
    let cc: [User]
    let bcc: [User]

    init(
        domain: String,
        sender: User,
        smtp: SMTPClient,
        replyTo: User?,
        cc: [User]?,
        bcc: [User]?
    ) {
        self.domain = domain
        self.sender = sender
        self.smtp = smtp
        self.replyTo = replyTo
        self.cc = cc ?? []
        self.bcc = bcc ?? []
    }
}
