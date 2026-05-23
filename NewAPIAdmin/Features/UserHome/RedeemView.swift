import SwiftUI

struct RedeemView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @State private var redeemCode = ""
    @State private var isRedeeming = false
    @State private var resultMessage: String?
    @State private var isError = false

    var body: some View {
        Form {
            Section(header: Text("兑换码"), footer: Text("输入兑换码兑换额度到当前账户")) {
                TextField("请输入兑换码", text: $redeemCode)
                    .adminPlainTextInput()
                    .adminEditableField()
            }

            if let result = resultMessage {
                Section {
                    Text(result)
                        .foregroundColor(isError ? Color.red : Color.green)
                }
            }

            Section {
                Button {
                    Task { await redeem() }
                } label: {
                    HStack {
                        Spacer()
                        if isRedeeming {
                            ProgressView()
                                .padding(.trailing, 8)
                        }
                        Text("兑换")
                        Spacer()
                    }
                }
                .disabled(redeemCode.trimmingCharacters(in: .whitespaces).isEmpty || isRedeeming)
            }
        }
        .navigationTitle("兑换码")
    }

    private func redeem() async {
        guard let client = try? sessionStore.activeClient() else {
            resultMessage = "未登录"
            isError = true
            return
        }

        isRedeeming = true
        defer { isRedeeming = false }
        resultMessage = nil

        let code = redeemCode.trimmingCharacters(in: .whitespaces)

        do {
            let quota: Int = try await client.post("/api/user/topup", body: RedeemRequest(key: code))
            let dollars = Double(quota) / 500000.0
            resultMessage = "兑换成功！获得额度 \(String(format: "$%.2f", dollars))"
            isError = false
            redeemCode = ""
        } catch let error as NewAPIError {
            resultMessage = error.localizedDescription
            isError = true
        } catch {
            resultMessage = error.localizedDescription
            isError = true
        }
    }
}

private struct RedeemRequest: Encodable {
    let key: String
}
