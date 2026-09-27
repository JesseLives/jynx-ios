public enum Copy {
    static let codes: [String: String] = [
        "network": "Network error. Check your connection and try again.",
        "invalid": "Please check the form and try again.",
        "too_many": "Too many attempts. Wait a few minutes and try again.",
        "bad_credentials": "Wrong username, email or password.",
        "username_taken": "That username is taken",
        "email_taken": "An account with this email already exists",
        "read_only": "Only the team posts in this channel.",
        "muted": "You are muted in this group for now.",
        "banned": "You are banned from this group.",
        "not_found": "Not found.",
    ]

    public static func error(_ e: Error) -> String {
        switch e as? APIError {
        case .offline?: return codes["network"]!
        case .signedOut?: return "Signed out. Sign in again."
        case let .server(_, code, _, message)?: return message ?? codes[code] ?? "Something went wrong. Try again."
        default: return "Something went wrong. Try again."
        }
    }

    public static func verdict(_ v: PostVerdict) -> String? {
        switch v {
        case .ok: nil
        case .readOnly: codes["read_only"]
        case .muted: codes["muted"]
        case .banned: codes["banned"]
        case .noAccess, .other: "You can't post here."
        }
    }
}
