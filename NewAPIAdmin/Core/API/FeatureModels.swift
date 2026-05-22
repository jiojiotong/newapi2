import Foundation

struct Channel: Codable, Identifiable, Equatable {
    let id: Int
    var name: String
    var type: Int?
    var group: String?
    var status: Int?
    var balance: Double?
    var responseTime: Double?
    var priority: Int?
    var weight: Int?
    var raw: DynamicObject

    init(id: Int, name: String, type: Int? = nil, group: String? = nil, status: Int? = nil, balance: Double? = nil, responseTime: Double? = nil, priority: Int? = nil, weight: Int? = nil, raw: DynamicObject = DynamicObject()) {
        self.id = id
        self.name = name
        self.type = type
        self.group = group
        self.status = status
        self.balance = balance
        self.responseTime = responseTime
        self.priority = priority
        self.weight = weight
        self.raw = raw
    }

    init(from decoder: Decoder) throws {
        let raw = try DynamicObject(from: decoder)
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeIntIfPresent("id") ?? Int.random(in: Int.min ..< -1)
        name = container.decodeStringIfPresent("name") ?? "未命名渠道"
        type = container.decodeIntIfPresent("type")
        group = container.decodeStringIfPresent("group", "group_name")
        status = container.decodeIntIfPresent("status")
        balance = container.decodeDoubleIfPresent("balance")
        responseTime = container.decodeDoubleIfPresent("response_time", "responseTime")
        priority = container.decodeIntIfPresent("priority")
        weight = container.decodeIntIfPresent("weight")
        self.raw = raw
    }
}

struct ManagedUser: Codable, Identifiable, Equatable {
    let id: Int
    var username: String
    var displayName: String?
    var group: String?
    var quota: Double?
    var status: Int?
    var role: Int?
    var raw: DynamicObject

    init(id: Int, username: String, displayName: String? = nil, group: String? = nil, quota: Double? = nil, status: Int? = nil, role: Int? = nil, raw: DynamicObject = DynamicObject()) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.group = group
        self.quota = quota
        self.status = status
        self.role = role
        self.raw = raw
    }

    init(from decoder: Decoder) throws {
        let raw = try DynamicObject(from: decoder)
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeIntIfPresent("id") ?? Int.random(in: Int.min ..< -1)
        username = container.decodeStringIfPresent("username") ?? "未知用户"
        displayName = container.decodeStringIfPresent("display_name", "displayName")
        group = container.decodeStringIfPresent("group")
        quota = container.decodeDoubleIfPresent("quota", "balance")
        status = container.decodeIntIfPresent("status")
        role = container.decodeIntIfPresent("role")
        self.raw = raw
    }
}

struct RedemptionCode: Codable, Identifiable, Equatable {
    let id: Int
    var name: String?
    var key: String
    var quota: Double?
    var count: Int?
    var usedCount: Int?
    var status: Int?
    var expiredTime: Int?
    var raw: DynamicObject

    init(id: Int, name: String? = nil, key: String, quota: Double? = nil, count: Int? = nil, usedCount: Int? = nil, status: Int? = nil, expiredTime: Int? = nil, raw: DynamicObject = DynamicObject()) {
        self.id = id
        self.name = name
        self.key = key
        self.quota = quota
        self.count = count
        self.usedCount = usedCount
        self.status = status
        self.expiredTime = expiredTime
        self.raw = raw
    }

    init(from decoder: Decoder) throws {
        let raw = try DynamicObject(from: decoder)
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        id = container.decodeIntIfPresent("id") ?? Int.random(in: Int.min ..< -1)
        name = container.decodeStringIfPresent("name")
        key = container.decodeStringIfPresent("key", "code") ?? ""
        quota = container.decodeDoubleIfPresent("quota")
        count = container.decodeIntIfPresent("count")
        usedCount = container.decodeIntIfPresent("used_count", "usedCount")
        status = container.decodeIntIfPresent("status")
        expiredTime = container.decodeIntIfPresent("expired_time", "expiredTime")
        self.raw = raw
    }
}

struct OptionItem: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    var value: String

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }
}

struct MessageResponse: Codable, Equatable {
    let message: String?
}

struct ManageUserRequest: Encodable {
    let id: Int
    let action: String
    var value: Int?
    var mode: String?
}

struct OptionUpdateRequest: Encodable {
    let key: String
    let value: String
}

struct OptionBatchUpdateRequest: Encodable {
    let options: [OptionUpdateRequest]
}
