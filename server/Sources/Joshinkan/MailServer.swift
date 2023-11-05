import ArgumentParser
import Foundation

import libfcgi

let routeTrialRegistration = Route(path: URL(string: "/api/trial-registration")!) { server in
    let failure = JSONResponse(
        status: .BAD_REQUEST,
        json: ["error": "Form data could not be parsed."]
    )
    guard let formData = readFormData() else { return failure }

    let hasChildren = (
        formData["child_first_name"] != nil
            || formData["child_last_name"] != nil
            || formData["child_age"] != nil
    )

    guard case let .plain(firstName) = formData["first_name"] else { return failure }
    guard !firstName.isEmpty else { return failure }
    guard case let .plain(lastName) = formData["last_name"] else { return failure }
    guard !lastName.isEmpty else { return failure }
    guard case let .plain(phone) = formData["phone"] else { return failure }
    guard !phone.isEmpty else { return failure }
    guard case let .plain(email) = formData["email"] else { return failure }
    guard User.isValidEmail(email) else { return failure }
    guard case let .plain(age) = formData["age"] else { return failure }
    guard formData["privacy"] == .plain("on") else { return failure }

    if hasChildren {
        guard formData["parents_consent"] == .plain("on") else { return failure }
        guard case let .list(childrenFirstNames) = formData["child_first_name"] else { return failure }
        guard case let .list(childrenLastNames) = formData["child_last_name"] else { return failure }
        guard case let .list(childrenAges) = formData["child_age"] else { return failure }

        func makeChildBlock(index: Int) -> String {
            let firstName = childrenFirstNames[index]
            let lastName = childrenLastNames[index]
            let age = childrenAges[index]

            return """
            <b>Kind #\(index + 1)</b>
            Name: \(firstName) \(lastName)
            Alter: \(age)
            """
        }

        let childrenBlocks = (0 ..< childrenFirstNames.count).map(makeChildBlock).joined(separator: "\n")
        let registrationMail = Mail(
            from: server.smtpUser,
            to: server.replyTo != nil ? [server.replyTo!] : [],
            cc: server.cc,
            bcc: server.bcc,
            subject: "Anmeldung zum Probetraining: Kinder (\(childrenFirstNames.count))",
            body: """
            Neuanmeldung zum Probetraining für <b>Kinder</b>.

            \(childrenBlocks)

            <b>Elternteil</b>
            Name: \(firstName) \(lastName)
            Email: \(email)
            Telefonummer: \(phone)
            """
        )

        do {
            try server.smtp.send(registrationMail)
        } catch is SmtpError {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send registration email."]
            )
        } catch {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending registration email."]
            )
        }

        func makeNameList(_ names: [String]) -> String {
            assert(names.count >= 1)
            if names.count == 1 {
                return names[0]
            } else {
                let allButLast = names[names.startIndex ..< names.endIndex - 1]
                return allButLast.joined(separator: ", ") + " und \(names[names.endIndex - 1])"
            }
        }

        let acknowledgementMail = Mail(
            from: server.smtpUser,
            to: [User(name: "\(firstName) \(lastName)", email: email)],
            cc: server.cc,
            bcc: server.bcc + [server.smtpUser],
            subject: "Joshinkan Werder Karate - Anmeldung zum Probetraining",
            body: """
            Liebe Familie \(lastName),

            Vielen Dank für die Anmeldung von \(makeNameList(childrenFirstNames)) \
            zum Probetraining.

            Einer unserer Trainer wird sich in kürze bei euch melden und die Anmeldung mit \
            einem Termin zum ersten Training bestätigen. Falls ihr in der Zwischenzeit \
            weitere Fragen, habt findet ihr Infos <a href="\(server.domain)/kontakt">hier</a>.

            Liebe Grüße,
            Das Joshinkan Team
            """
        )

        do {
            try server.smtp.send(acknowledgementMail)
        } catch is SmtpError {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send acknowledgement email."]
            )
        } catch {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending acknowledgement email."]
            )
        }

    } else {
        guard let age = Int(age) else { return failure }

        let registrationMail = Mail(
            from: server.smtpUser,
            to: server.replyTo != nil ? [server.replyTo!] : [],
            cc: server.cc,
            bcc: server.bcc,
            subject: "Anmeldung zum Probetraining: Erwachsene",
            body: """
            Neuanmeldung zum Probetraining für <b>Erwachsene</b>.

            Name: \(firstName) \(lastName)
            Alter: \(age)
            Email: \(email)
            Telefonummer: \(phone)
            """
        )

        do {
            try server.smtp.send(registrationMail)
        } catch is SmtpError {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send registration email."]
            )
        } catch {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending registration email."]
            )
        }

        let acknowledgementMail = Mail(
            from: server.smtpUser,
            to: [User(name: "\(firstName) \(lastName)", email: email)],
            cc: server.cc,
            bcc: server.bcc + [server.smtpUser],
            subject: "Joshinkan Werder Karate - Anmeldung zum Probetraining",
            body: """
            Hallo \(firstName),

            Vielen Dank für die Anmeldung zum Probetraining.

            Einer unserer Trainer wird sich in kürze bei dir melden und die Anmeldung mit \
            einem Termin zum ersten Training bestätigen. Falls du in der Zwischenzeit \
            weitere Fragen hast, findest du Infos <a href="\(server.domain)/kontakt">hier</a>.

            Liebe Grüße,
            Das Joshinkan Team
            """
        )

        do {
            try server.smtp.send(acknowledgementMail)
        } catch is SmtpError {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send acknowledgement email."]
            )
        } catch {
            return JSONResponse(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending acknowledgement email."]
            )
        }
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

    return StringResponse(
        status: .OK,
        headers: ["Content-Type": "text/html"],
        body: body
    )
}

// NOTE(sven): We provide a stub implementation during testing.
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

    lazy var ROUTES: [Route] = {
        var routes = [
            routeTrialRegistration,
        ]

        #if DEBUG
            routes += [
                routePrintEnv,
            ]
        #endif
        return routes
    }()

    mutating func run() {
        loopAcceptAndDo {
            matchAndExecuteRoutes(routes: ROUTES, server: &self)
        }
    }
}
