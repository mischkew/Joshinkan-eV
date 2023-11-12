//
//  File.swift
//
//
//  Created by Sven Mischkewitz on 05.11.23.
//

import Foundation

typealias R = Route<ServerContext>

let trialRegistration = R(path: URL(string: "/api/trial-registration")!, method: .POST) { context in
    let failure = Response(
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
            <b>Kind #\(index + 1)</b><br/>
            Name: \(firstName) \(lastName)<br/>
            Alter: \(age)<br/>
            """
        }

        let childrenBlocks = (0 ..< childrenFirstNames.count).map(makeChildBlock).joined(separator: "\n<br>")
        let registrationMail = Mail(
            from: context.sender,
            to: context.replyTo != nil ? [context.replyTo!] : [],
            cc: context.cc,
            bcc: context.bcc,
            subject: "Anmeldung zum Probetraining: Kinder (\(childrenFirstNames.count))",
            body: """
            Neuanmeldung zum Probetraining für <b>Kinder</b>.<br/>
            <br/>
            \(childrenBlocks)
            <br/>
            <b>Elternteil</b><br/>
            Name: \(firstName) \(lastName)<br/>
            Email: \(email)<br/>
            Telefon: \(phone)<br/>
            """
        )

        do {
            try context.smtp.send(registrationMail)
        } catch is SmtpError {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send registration email."]
            )
        } catch {
            return Response(
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
            from: context.sender,
            to: [User(name: "\(firstName) \(lastName)", email: email)],
            cc: context.cc,
            bcc: context.bcc + [context.sender],
            subject: "Joshinkan Werder Karate - Anmeldung zum Probetraining",
            body: """
            Liebe Familie \(lastName),<br/>
            <br/>
            Vielen Dank für die Anmeldung von \(makeNameList(childrenFirstNames)) \
            zum Probetraining.<br/>
            <br/>
            Einer unserer Trainer wird sich in Kürze bei euch melden und die Anmeldung mit \
            einem Termin zum ersten Training bestätigen. Falls ihr in der Zwischenzeit \
            weitere Fragen habt, findet ihr Infos <a href="\(env("HTTP_HOST") ?? context.domain)/kontakt">hier</a>.<br/>
            <br/>
            Liebe Grüße,<br/>
            Das Joshinkan Team<br/>
            """
        )

        do {
            try context.smtp.send(acknowledgementMail)
        } catch is SmtpError {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send acknowledgement email."]
            )
        } catch {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending acknowledgement email."]
            )
        }

    } else {
        guard let age = Int(age) else { return failure }

        let registrationMail = Mail(
            from: context.sender,
            to: context.replyTo != nil ? [context.replyTo!] : [],
            cc: context.cc,
            bcc: context.bcc,
            subject: "Anmeldung zum Probetraining: Erwachsene",
            body: """
            Neuanmeldung zum Probetraining für <b>Erwachsene</b>.<br/>
            <br/>
            Name: \(firstName) \(lastName)<br/>
            Alter: \(age)<br/>
            Email: \(email)<br/>
            Telefon: \(phone)<br/>
            """
        )

        do {
            try context.smtp.send(registrationMail)
        } catch is SmtpError {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send registration email."]
            )
        } catch {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending registration email."]
            )
        }

        let acknowledgementMail = Mail(
            from: context.sender,
            to: [User(name: "\(firstName) \(lastName)", email: email)],
            cc: context.cc,
            bcc: context.bcc + [context.sender],
            subject: "Joshinkan Werder Karate - Anmeldung zum Probetraining",
            body: """
            Hallo \(firstName),<br/>
            <br/>
            Vielen Dank für die Anmeldung zum Probetraining.<br/>
            <br/>
            Einer unserer Trainer wird sich in Kürze bei dir melden und die Anmeldung mit \
            einem Termin zum ersten Training bestätigen. Falls du in der Zwischenzeit \
            weitere Fragen hast, findest du Infos <a href="\(env("HTTP_HOST") ?? context.domain)/kontakt">hier</a>.<br/>
            <br/>
            Liebe Grüße,<br/>
            Das Joshinkan Team<br/>
            """
        )

        do {
            try context.smtp.send(acknowledgementMail)
        } catch is SmtpError {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Failed to send acknowledgement email."]
            )
        } catch {
            return Response(
                status: .INTERNAL_SERVER_ERROR,
                json: ["error": "Unknown error while sending acknowledgement email."]
            )
        }
    }

    let json = ["message": "Email sent."]
    return Response(status: .OK, json: json)
}

let printEnv = R(path: URL(string: "/api/print-env")!) { _ in
    let keys = ProcessInfo.processInfo.environment.keys
    var body = ""
    for key in keys.sorted() {
        let value = ProcessInfo.processInfo.environment[key]
        body += "\(key): \(value ?? "NOT SET")<br/>\n"
    }

    return Response(
        status: .OK,
        headers: ["Content-Type": "text/html"],
        text: body
    )
}

let ROUTES: [R] = {
    var routes = [
        trialRegistration,
    ]

    #if DEBUG
        routes += [
            printEnv,
        ]
    #endif
    return routes
}()
