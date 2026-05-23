import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct TopUpView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @Environment(\.openURL) private var openURL
    @State private var isLoading = true
    @State private var topUpInfo: TopUpInfo?
    @State private var errorMessage: String?
    @State private var amountText = ""
    @State private var selectedMethod = ""
    @State private var isPaying = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        Group {
            if isLoading {
                LoadingStateView(title: "加载充值信息")
            } else if let info = topUpInfo {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerCard

                        if !info.topupLink.isEmpty {
                            thirdPartyRechargeCard(link: info.topupLink)
                        }

                        if !info.payMethods.isEmpty {
                            onlineRechargeCard(info: info)
                        }

                        if !info.enableRedemption && info.payMethods.isEmpty && info.topupLink.isEmpty {
                            AdminSurfaceCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("暂未开放充值功能")
                                        .font(.headline)
                                    Text("当前服务器没有可用的充值入口。")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }

                        if let result = resultMessage {
                            AdminSurfaceCard {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                        .foregroundColor(isError ? .red : .green)
                                    Text(result)
                                        .foregroundColor(.secondary)
                                    Spacer(minLength: 0)
                                }
                            }
                        }
                    }
                    .padding()
                }
                .adminScreenBackground()
            } else if let error = errorMessage {
                ErrorStateView(message: error, retry: { Task { await loadInfo() } })
            }
        }
        .navigationTitle("充值")
        .task { await loadInfo() }
    }

    private var headerCard: some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.12))
                        Image(systemName: "creditcard")
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: 44, height: 44)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("充值")
                            .font(.title3.weight(.semibold))
                        Text("系统会调用第三方支付页面完成充值")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Text("如果你的服务器只开放充值，这里会优先展示入口按钮，界面保持简洁。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func thirdPartyRechargeCard(link: String) -> some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("充值")
                    .font(.headline)
                Text("点击后会打开系统支付页面完成充值，回到应用后额度会自动同步。")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    if let url = URL(string: link) {
                        openURL(url)
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.right.square")
                        Text("前往支付页面")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
                .disabled(URL(string: link) == nil)
            }
        }
    }

    private func onlineRechargeCard(info: TopUpInfo) -> some View {
        AdminSurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("在线充值")
                    .font(.headline)
                Text("最低充值：\(info.minTopup) 单位")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Picker("支付方式", selection: $selectedMethod) {
                    Text("请选择").tag("")
                    ForEach(info.payMethods, id: \.type) { method in
                        Text(method.name).tag(method.type)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("充值数量")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("数量", text: $amountText)
                        .adminNumberKeyboard()
                        .adminEditableField()
                }

                if !info.amountOptions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(info.amountOptions, id: \.self) { option in
                                Button(String(option)) {
                                    amountText = String(option)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                Button {
                    Task { await requestPay() }
                } label: {
                    HStack {
                        Spacer()
                        if isPaying { ProgressView().padding(.trailing, 4) }
                        Text("充值")
                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isPaying || selectedMethod.isEmpty || amountText.isEmpty)
            }
        }
    }

    private func loadInfo() async {
        errorMessage = nil
        topUpInfo = nil
        resultMessage = nil
        isError = false
        selectedMethod = ""
        amountText = ""

        guard let client = try? sessionStore.activeClient() else {
            isLoading = false
            errorMessage = "未登录"
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let info: TopUpInfo = try await client.get("/api/user/topup/info")
            topUpInfo = info
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requestPay() async {
        guard let client = try? sessionStore.activeClient(),
              let amount = Int(amountText), amount > 0 else {
            resultMessage = "请输入有效的充值数量"
            isError = true
            return
        }

        isPaying = true
        defer { isPaying = false }
        resultMessage = nil

        do {
            // Request payment URL via epay
            let response: PayResponse = try await client.post("/api/user/pay", body: PayRequest(amount: amount, paymentMethod: selectedMethod))
            if let payURL = response.url, !payURL.isEmpty, let url = URL(string: payURL) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
                resultMessage = "已跳转到支付页面，请在浏览器中完成支付"
                isError = false
            } else {
                resultMessage = response.message ?? "获取支付链接失败"
                isError = true
            }
        } catch let error as NewAPIError {
            resultMessage = error.localizedDescription
            isError = true
        } catch {
            resultMessage = error.localizedDescription
            isError = true
        }
    }
}

// MARK: - Models

struct TopUpInfo: Decodable {
    let enableRedemption: Bool
    let topupLink: String
    let minTopup: Int
    let payMethods: [PayMethod]
    let amountOptions: [Int]

    enum CodingKeys: String, CodingKey {
        case enableRedemption = "enable_redemption"
        case topupLink = "topup_link"
        case minTopup = "min_topup"
        case payMethods = "pay_methods"
        case amountOptions = "amount_options"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enableRedemption = (try? container.decode(Bool.self, forKey: .enableRedemption)) ?? false
        topupLink = (try? container.decode(String.self, forKey: .topupLink)) ?? ""
        minTopup = (try? container.decode(Int.self, forKey: .minTopup)) ?? 1
        payMethods = (try? container.decode([PayMethod].self, forKey: .payMethods)) ?? []
        amountOptions = (try? container.decode([Int].self, forKey: .amountOptions)) ?? []
    }
}

struct PayMethod: Decodable {
    let name: String
    let type: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decode(String.self, forKey: .name)) ?? ""
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case name
        case type
    }
}

struct PayRequest: Encodable {
    let amount: Int
    let paymentMethod: String

    enum CodingKeys: String, CodingKey {
        case amount
        case paymentMethod = "payment_method"
    }
}

struct PayResponse: Decodable {
    let url: String?
    let message: String?

    init(from decoder: Decoder) throws {
        // Response could be {"message": "success", "data": "url"} or {"message": "error", "data": "msg"}
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            url = str
            message = nil
        } else {
            url = nil
            message = nil
        }
    }
}
