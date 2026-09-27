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
        "insufficient": "Not enough in your wallet. Deposit first, or pay by ABA or USDT.",
        "not_withdrawable": "That is more than you can withdraw. Only referral earnings can be withdrawn.",
        "below_minimum": "That is below the minimum withdrawal.",
        "withdrawal_pending": "You already have a withdrawal waiting. Wait for it to be paid first.",
        "bad_amount": "Enter an amount within the deposit limits.",
        "code_taken": "That invite code is taken. Try another.",
        "code_invalid": "Use 3 to 20 letters, numbers, - or _.",
        "no_price": "That plan is no longer available.",
        "bad_receipt": "The receipt must be a PNG, JPEG or WebP image under 5 MB.",
        "no_proof": "Add a receipt screenshot or a transaction reference.",
        "too_many_pending": "You already have 5 payments waiting to be checked.",
        "not_pending": "That payment was already decided.",
        "no_copier_pass": "You need an active Copier Pass to connect MT5.",
        "already_connected": "An MT5 account is already connected. Disconnect it first.",
        "copier_unavailable": "The copier is not available right now.",
        "not_connected": "No MT5 account is connected.",
        "qr_unavailable": "Payment by QR is not available right now. Try again in a minute, or pay with USDT.",
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
        case .readOnly: "Only the team posts here."
        case .muted: codes["muted"]
        case .banned: codes["banned"]
        case .noAccess, .other: "You can't post here."
        }
    }
}
