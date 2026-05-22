import SwiftUI

struct KeyValueJSONEditorView: View {
    @Binding var jsonText: String
    @State private var rows: [KeyValueRow] = []
    @State private var errorMessage: String?

    var body: some View {
        Section("可视化编辑") {
            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red)
            }

            if errorMessage == nil {
                ForEach($rows) { $row in
                    HStack {
                        TextField("Key", text: $row.key)
                        TextField("Value", text: $row.value)
                            .adminDecimalKeyboard()
                            .multilineTextAlignment(.trailing)
                    }
                }
                .onDelete { rows.remove(atOffsets: $0); syncJSON() }
                .onChange(of: rows) { _ in syncJSON() }

                Button("添加一行") {
                    rows.append(KeyValueRow(key: "", value: "1"))
                    syncJSON()
                }
            }
        }
        .onAppear { loadRows() }
        .onChange(of: jsonText) { _ in loadRows() }
    }

    private func loadRows() {
        guard let data = jsonText.data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            rows = []
            errorMessage = "当前 JSON 不是对象，无法可视化编辑。"
            return
        }

        guard Self.isVisualEditableObject(object) else {
            rows = []
            errorMessage = "当前 JSON 包含数组或嵌套对象，请使用原始 JSON 编辑以避免结构被改写。"
            return
        }

        rows = object.keys.sorted().map { key in
            KeyValueRow(key: key, value: String(describing: object[key] ?? ""))
        }
        errorMessage = nil
    }

    private func syncJSON() {
        var object: [String: Any] = [:]
        for row in rows where !row.key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let intValue = Int(row.value) {
                object[row.key] = intValue
            } else if let doubleValue = Double(row.value) {
                object[row.key] = doubleValue
            } else {
                object[row.key] = row.value
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            errorMessage = "无法生成 JSON"
            return
        }
        jsonText = text
        errorMessage = nil
    }

    static func isVisualEditableObject(_ object: [String: Any]) -> Bool {
        object.values.allSatisfy { value in
            value is String || value is NSNumber || value is NSNull
        }
    }
}

private struct KeyValueRow: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String
}
