import Foundation

enum NewAPIError: LocalizedError, Equatable {
    case invalidServerURL
    case invalidResponse
    case unauthorized
    case forbidden
    case administratorRequired
    case twoFactorUnsupported
    case serverMessage(String)
    case network(String)
    case timeout
    case decoding(String)
    case missingData
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "服务器地址无效"
        case .invalidResponse:
            return "服务器响应无效"
        case .unauthorized:
            return "登录已失效，请重新登录"
        case .forbidden:
            return "当前账号没有权限执行此操作"
        case .administratorRequired:
            return "此账号不是管理员，无法使用移动管理端。"
        case .twoFactorUnsupported:
            return "当前账号需要两步验证，第一版移动管理端暂不支持 2FA 登录。"
        case .serverMessage(let message):
            return message.isEmpty ? "服务器返回失败" : message
        case .network(let message):
            return "网络请求失败：\(message)"
        case .timeout:
            return "服务器连接超时，请检查地址和网络"
        case .decoding(let message):
            return "数据解析失败：\(message)"
        case .missingData:
            return "服务器没有返回数据"
        case .validation(let message):
            return message
        }
    }
}
