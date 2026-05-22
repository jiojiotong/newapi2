import Foundation

enum FormValidation {
    static func requirePositive(_ value: Double?, field: String) throws {
        guard let value, value > 0 else {
            throw NewAPIError.validation("\(field) 必须大于 0")
        }
    }

    static func requireNonNegative(_ value: Double?, field: String) throws {
        guard let value, value >= 0 else {
            throw NewAPIError.validation("\(field) 不能为负数")
        }
    }

    static func requirePositiveInt(_ value: Int?, field: String) throws {
        guard let value, value > 0 else {
            throw NewAPIError.validation("\(field) 必须大于 0")
        }
    }

    static func validateJSONString(_ value: String, field: String) throws {
        guard let data = value.data(using: .utf8), !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NewAPIError.validation("\(field) 不能为空")
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw NewAPIError.validation("\(field) 不是有效 JSON")
        }
    }
}

enum OptionParser {
    static func dictionary(from options: [OptionItem]) -> [String: String] {
        Dictionary(options.map { ($0.key, $0.value) }, uniquingKeysWith: { _, last in last })
    }
}
