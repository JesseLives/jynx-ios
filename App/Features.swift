import Foundation

enum Features {
    static let sells = (Bundle.main.infoDictionary?["JynxSells"] as? String ?? "YES") != "NO"
}
