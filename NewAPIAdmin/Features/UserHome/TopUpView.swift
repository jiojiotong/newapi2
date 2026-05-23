import SwiftUI

struct TopUpView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var isLoading = true
    @State private var topUpInfo: TopUpInfo?
    @State private var errorMessage: String?
    @State private var amountText = ""
    @State private var selectedMethod = ""
    @State private var isPaying = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        Form {
            if isLoading {
                Section { ProgressView("加载充值信息...") }
            }

            if let error = errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }

            if let result = resultMessage {
                Section { Text(result).foregroundColor(isError ? Color.red : Color.green) }
            }

            if let info = topUpInfo {
                if !info.topupLink.isEmpty {
                    Section(header: Text("外部充值"), footer: Text("点击跳转到充值页面完成支付")) {
                        Link("前往充值页面", destination: URL(string: info.topupLink) ?? URL(string: "about:blank")!)
                    }
                }

                if !info.payMethods.isEmpty {
                    Section(header: Text("在线充值"), footer: Text("最低充值：\(info.minTopup) 单位")) {
                        Picker("支付方式", selection: $selectedMethod) {
                            Text("请选择").tag("")
                            ForEach(info.payMethods, id: \.type) { method in
                                Text(method.name).tag(method.type)
                            }
                        }

                        HStack {
                            Text("充值数量")
                            Spacer()
                            TextField("数量", text: $amountText)
                                .adminNumberKeyboard()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
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
                        }
                        .disabled(isPaying || selectedMethod.isEmpty || amountText.isEmpty)
                    }
                }

                if !info.enableRedemption && info.payMethods.isEmpty && info.topupLink.isEmpty {
                    Section {
                        Text("暂未开放充值功能")
                            .foregroundColor(Color.secondary)
                    }
                }
            }
        }
        .navigationTitle("充值")
        .task { await loadInfo() }
    }

    private func loadInfo() async {
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
