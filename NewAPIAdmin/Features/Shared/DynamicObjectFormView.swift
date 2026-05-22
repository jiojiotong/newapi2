import SwiftUI

struct DynamicObjectFormView: View {
    let title: String
    let initialValues: [String: AnyJSONValue]
    let save: (DynamicObject) async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var jsonText: String
    @State private var errorMessage: String?

    init(title: String, initialValues: [String: AnyJSONValue], save: @escaping (DynamicObject) async -> Void) {
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
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { await saveJSON() }
                }
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private func saveJSON() async {
        do {
            let data = Data(jsonText.utf8)
            let object = try JSONDecoder().decode(DynamicObject.self, from: data)
            await save(object)
            dismiss()
        } catch {
            errorMessage = "JSON 格式无效"
        }
    }
}
