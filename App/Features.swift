import Foundation

enum Features {
    static let sells = (Bundle.main.infoDictionary?["JynxSells"] as? String ?? "YES") != "NO"
    static let copier = (Bundle.main.infoDictionary?["JynxCopier"] as? String ?? "NO") == "YES"
}
