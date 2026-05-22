import Foundation

struct ServerStatus: Decodable {
    let version: String?
    let startTime: Int?
    let systemName: String?
    let emailVerification: Bool?
    let turnstileCheck: Bool?

    enum CodingKeys: String, CodingKey {
        case version
        case startTime = "start_time"
        case systemName = "system_name"
        case emailVerification = "email_verification"
        case turnstileCheck = "turnstile_check"
    }
}
