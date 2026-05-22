import Foundation

struct ServerStatus: Decodable {
    let status: AnyJSONValue?
    let version: String?
    let startTime: Int?

    enum CodingKeys: String, CodingKey {
        case status
        case version
        case startTime = "start_time"
    }
}
