import SwiftUI

struct RedemptionCreateView: View {
    @ObservedObject var viewModel: RedemptionsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var quotaText = "1"
    @State private var countText = "1"
    @State private var expiryText = ""
    @State private var usageLimitText = ""
    @State private var localError: String?

    var body: some View {
        Form {
            if let localError {
                Section { Text(localError).foregroundColor(Color.red) }
            }

            Section("创建") {
                TextField("额度", text: $quotaText)
                    .adminDecimalKeyboard()
                TextField("数量", text: $countText)
                    .adminNumberKeyboard()
                TextField("过期时间戳，可选", text: $expiryText)
                    .adminNumberKeyboard()
                TextField("使用次数限制，可选", text: $usageLimitText)
                    .adminNumberKeyboard()
            }

            Section {
                Button("创建") {
                    Task { await create() }
                }
            }
        }
        .navigationTitle("新增兑换码")
    }

    private func create() async {
        localError = nil
        guard let quota = Double(quotaText), let count = Int(countText) else {
            localError = "额度和数量格式无效"
            return
        }
        let expiry = expiryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Int(expiryText)
        let usageLimit = usageLimitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : Int(usageLimitText)

        if !expiryText.isEmpty && expiry == nil {
            localError = "过期时间必须是整数时间戳"
            return
        }
        if !usageLimitText.isEmpty && usageLimit == nil {
            localError = "使用次数限制必须是整数"
            return
        }

        await viewModel.createValidated(quota: quota, count: count, expiredTime: expiry, usageLimit: usageLimit)
        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}
