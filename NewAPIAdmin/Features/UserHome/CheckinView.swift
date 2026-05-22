import SwiftUI

struct CheckinView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isLoading = true
    @State private var isCheckinEnabled = false
    @State private var hasCheckedToday = false
    @State private var totalCheckins = 0
    @State private var totalQuota = 0
    @State private var monthCheckins = 0
    @State private var minQuota = 0
    @State private var maxQuota = 0
    @State private var records: [CheckinRecord] = []
    @State private var isCheckingIn = false
    @State private var resultMessage: String?
    @State private var isError = false
    @State private var turnstileToken = ""

    var body: some View {
        Form {
            if !isLoading && !isCheckinEnabled {
                Section {
                    Text("签到功能未启用")
                        .foregroundColor(Color.secondary)
                }
            }

            if isCheckinEnabled {
                Section("签到") {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: hasCheckedToday ? "checkmark.circle.fill" : "circle")
                                .font(Font.system(size: 50))
                                .foregroundColor(hasCheckedToday ? Color.green : Color.accentColor)
                            Text(hasCheckedToday ? "今日已签到" : "点击签到")
                                .font(Font.headline)
                            if !hasCheckedToday {
                                Text("可获得 \(formatQuota(minQuota)) ~ \(formatQuota(maxQuota)) 额度")
                                    .font(Font.caption)
                                    .foregroundColor(Color.secondary)
                            }
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !hasCheckedToday && !isCheckingIn {
                            Task { await doCheckin() }
                        }
                    }
                }

                // Turnstile for checkin if required
                if sessionStore.turnstileRequired && !sessionStore.turnstileSiteKey.isEmpty && !hasCheckedToday {
                    Section("安全验证") {
                        if turnstileToken.isEmpty {
                            TurnstileView(siteKey: sessionStore.turnstileSiteKey) { token in
                                turnstileToken = token
                            }
                            .frame(height: 80)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color.green)
                                Text("验证已通过")
                            }
                        }
                    }
                }

                if let result = resultMessage {
                    Section {
                        Text(result)
                            .foregroundColor(isError ? Color.red : Color.green)
                    }
                }

                Section("统计") {
                    LabeledContent("累计签到", value: "\(totalCheckins) 次")
                    LabeledContent("累计获得", value: formatQuota(totalQuota))
                    LabeledContent("本月签到", value: "\(monthCheckins) 次")
                }

                if !records.isEmpty {
                    Section("本月记录") {
                        ForEach(records, id: \.checkinDate) { record in
                            HStack {
                                Text(record.checkinDate)
                                Spacer()
                                Text("+\(formatQuota(record.quotaAwarded))")
                                    .foregroundColor(Color.green)
                            }
                            .font(Font.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("签到")
        .overlay {
            if isLoading { LoadingStateView(title: "加载签到信息") }
        }
        .task { await loadStatus() }
    }

    private func loadStatus() async {
        guard let client = try? sessionStore.activeClient() else {
            isLoading = false
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let response: CheckinStatusResponse = try await client.get("/api/user/checkin")
            isCheckinEnabled = response.enabled
            minQuota = response.minQuota
            maxQuota = response.maxQuota
            if let stats = response.stats {
                hasCheckedToday = stats.checkedInToday
                totalCheckins = stats.totalCheckins
                totalQuota = stats.totalQuota
                monthCheckins = stats.checkinCount
                records = stats.records
            }
        } catch {
            isCheckinEnabled = false
        }
    }

    private func doCheckin() async {
        guard let client = try? sessionStore.activeClient() else { return }

        // Check if turnstile is required but not verified
        if sessionStore.turnstileRequired && turnstileToken.isEmpty {
            resultMessage = "请先完成安全验证"
            isError = true
            return
        }

        isCheckingIn = true
        defer { isCheckingIn = false }
        resultMessage = nil

        let checkinPath: String
        if !turnstileToken.isEmpty {
            checkinPath = "/api/user/checkin?turnstile=\(turnstileToken)"
        } else {
            checkinPath = "/api/user/checkin"
        }

        do {
            let response: CheckinDoResponse = try await client.post(checkinPath, body: EmptyBody())
            hasCheckedToday = true
            resultMessage = "签到成功！获得 \(formatQuota(response.quotaAwarded))"
            isError = false
            // Reload stats
            await loadStatus()
        } catch let error as NewAPIError {
            resultMessage = error.localizedDescription
            isError = true
        } catch {
            resultMessage = error.localizedDescription
            isError = true
        }
    }

    private func formatQuota(_ value: Int) -> String {
        String(format: "$%.2f", Double(value) / 500000.0)
    }
}

// MARK: - Models

private struct EmptyBody: Encodable {}

struct CheckinStatusResponse: Decodable {
    let enabled: Bool
    let minQuota: Int
    let maxQuota: Int
    let stats: CheckinStats?

    enum CodingKeys: String, CodingKey {
        case enabled
        case minQuota = "min_quota"
        case maxQuota = "max_quota"
        case stats
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        minQuota = (try? container.decode(Int.self, forKey: .minQuota)) ?? 0
        maxQuota = (try? container.decode(Int.self, forKey: .maxQuota)) ?? 0
        stats = try? container.decode(CheckinStats.self, forKey: .stats)
    }
}

struct CheckinStats: Decodable {
    let totalQuota: Int
    let totalCheckins: Int
    let checkinCount: Int
    let checkedInToday: Bool
    let records: [CheckinRecord]

    enum CodingKeys: String, CodingKey {
        case totalQuota = "total_quota"
        case totalCheckins = "total_checkins"
        case checkinCount = "checkin_count"
        case checkedInToday = "checked_in_today"
        case records
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalQuota = (try? container.decode(Int.self, forKey: .totalQuota)) ?? 0
        totalCheckins = (try? container.decode(Int.self, forKey: .totalCheckins)) ?? 0
        checkinCount = (try? container.decode(Int.self, forKey: .checkinCount)) ?? 0
        checkedInToday = (try? container.decode(Bool.self, forKey: .checkedInToday)) ?? false
        records = (try? container.decode([CheckinRecord].self, forKey: .records)) ?? []
    }
}

struct CheckinRecord: Decodable {
    let checkinDate: String
    let quotaAwarded: Int

    enum CodingKeys: String, CodingKey {
        case checkinDate = "checkin_date"
        case quotaAwarded = "quota_awarded"
    }
}

struct CheckinDoResponse: Decodable {
    let quotaAwarded: Int
    let checkinDate: String

    enum CodingKeys: String, CodingKey {
        case quotaAwarded = "quota_awarded"
        case checkinDate = "checkin_date"
    }
}
