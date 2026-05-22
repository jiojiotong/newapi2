import Foundation

struct PaginatedResponse<Item: Codable & Identifiable>: Codable {
    let items: [Item]
    let total: Int?

    init(items: [Item], total: Int? = nil) {
        self.items = items
        self.total = total
    }

    init(from decoder: Decoder) throws {
        if var unkeyed = try? decoder.unkeyedContainer() {
            var values: [Item] = []
            while !unkeyed.isAtEnd {
                values.append(try unkeyed.decode(Item.self))
            }
            items = values
            total = values.count
            return
        }

        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var decodedItems: [Item] = []
        for key in ["items", "data", "rows", "list"] {
            if let codingKey = DynamicCodingKey(stringValue: key), let values = try? container.decode([Item].self, forKey: codingKey) {
                decodedItems = values
                break
            }
        }

        items = decodedItems
        total = ["total", "count", "num"].compactMap { DynamicCodingKey(stringValue: $0) }.compactMap { try? container.decode(Int.self, forKey: $0) }.first ?? decodedItems.count
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        if let itemsKey = DynamicCodingKey(stringValue: "items") {
            try container.encode(items, forKey: itemsKey)
        }
        if let totalKey = DynamicCodingKey(stringValue: "total") {
            try container.encodeIfPresent(total, forKey: totalKey)
        }
    }
}

struct DynamicObject: Codable, Equatable {
    var values: [String: AnyJSONValue]

    init(values: [String: AnyJSONValue] = [:]) {
        self.values = values
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var values: [String: AnyJSONValue] = [:]
        for key in container.allKeys {
            values[key.stringValue] = try container.decode(AnyJSONValue.self, forKey: key)
        }
        self.values = values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in values {
            guard let codingKey = DynamicCodingKey(stringValue: key) else { continue }
            try container.encode(value, forKey: codingKey)
        }
    }

    subscript(_ key: String) -> AnyJSONValue? {
        get { values[key] }
        set { values[key] = newValue }
    }
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer {
    func decodeStringIfPresent(_ keys: String...) -> String? {
        for key in keys {
            guard let codingKey = Key(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(String.self, forKey: codingKey) {
                return value
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: codingKey), let intValue {
                return String(intValue)
            }
            if let doubleValue = try? decodeIfPresent(Double.self, forKey: codingKey), let doubleValue {
                return String(doubleValue)
            }
        }
        return nil
    }

    func decodeIntIfPresent(_ keys: String...) -> Int? {
        for key in keys {
            guard let codingKey = Key(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Int.self, forKey: codingKey) {
                return value
            }
            if let string = try? decodeIfPresent(String.self, forKey: codingKey), let string, let value = Int(string) {
                return value
            }
        }
        return nil
    }

    func decodeDoubleIfPresent(_ keys: String...) -> Double? {
        for key in keys {
            guard let codingKey = Key(stringValue: key) else { continue }
            if let value = try? decodeIfPresent(Double.self, forKey: codingKey) {
                return value
            }
            if let intValue = try? decodeIfPresent(Int.self, forKey: codingKey), let intValue {
                return Double(intValue)
            }
            if let string = try? decodeIfPresent(String.self, forKey: codingKey), let string, let value = Double(string) {
                return value
            }
        }
        return nil
    }
}
