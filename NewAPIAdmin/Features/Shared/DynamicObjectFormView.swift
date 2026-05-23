import SwiftUI

struct DynamicObjectFormView: View {
    let title: String
    let initialValues: [String: AnyJSONValue]
    let save: (DynamicObject) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var jsonText: String
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(title: String, initialValues: [String: AnyJSONValue], save: @escaping (DynamicObject) async -> Bool) {
        self.title = title
        self.initialValues = initialValues
        self.save = save
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(DynamicObject(values: initialValues)), let text = String(data: data, encoding: .utf8) {
            _jsonText = State(initialValue: text)
        } else {
            _jsonText = State(initialValue: "{}")
        }
    }

    var body: some View {
        Form {
            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(Color.red)
                }
            }

            Section("JSON") {
                TextEditor(text: $jsonText)
                    .font(Font.system(Font.TextStyle.body, design: Font.Design.monospaced))
                    .frame(minHeight: 280)
            }
        }
        .navigationTitle(title)
        .toolbar {
            Button("取消") {
                dismiss()
            }
            Button("保存") {
                Task { await saveJSON() }
            }
            .disabled(isSaving)
        }
        .adminFormChrome()
    }

    private func saveJSON() async {
        errorMessage = nil
        guard let data = jsonText.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: data) else {
            errorMessage = "JSON 格式无效"
            return
        }
        guard let object = try? JSONDecoder().decode(DynamicObject.self, from: data) else {
            errorMessage = "JSON 解析失败"
            return
        }
        isSaving = true
        let success = await save(object)
        isSaving = false
        if success {
            dismiss()
        } else {
            errorMessage = "保存失败，请检查数据后重试"
        }
    }
}
