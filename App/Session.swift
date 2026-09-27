import Foundation
import JynxKit
import Observation

@Observable @MainActor
final class Session {
    enum State: Equatable { case loading, offline, signedOut, signedIn(Me) }
    var state: State = .loading
    let api = API(base: URL(string: "https://signals.justsal.xyz")!, transport: URLSessionTransport())

    var me: Me? { if case let .signedIn(m) = state { m } else { nil } }

    func start() async { await refreshMe() }

    func refreshMe() async {
        do { state = .signedIn(try await api.me()) }
        catch APIError.signedOut { state = .signedOut }
        catch { if me == nil { state = .offline } }
    }

    func signIn(login: String, password: String) async throws {
        try await api.signIn(login: login, password: password); await refreshMe()
    }
    func signUp(username: String, email: String, password: String, confirm: String) async throws {
        try await api.signUp(username: username, email: email, password: password, confirm: confirm); await refreshMe()
    }
    func signOut() async {
        try? await api.signOut()
        HTTPCookieStorage.shared.cookies?.forEach(HTTPCookieStorage.shared.deleteCookie)
        state = .signedOut
    }
    func handle(_ error: Error) { if case APIError.signedOut = error { state = .signedOut } }
}
