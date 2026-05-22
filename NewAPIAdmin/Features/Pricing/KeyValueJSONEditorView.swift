import SwiftUI

struct KeyValueJSONEditorView: View {
    @Binding var jsonText: String
    @State private var rows: [KeyValueRow] = []
    @State private var errorMessage: String?

    var body: some View {
        Section("可视化编辑") {
            if let errorMessage {
                Text(errorMessage).foregroundColor(Color.red)
            } else if rows.isEmpty {
                Text("当前 JSON 没有可视化键值项，请使用下方原始 JSON 编辑。")
                    .foregroundColor(Color.secondary)
            } else {
                Text("已识别 \(rows.count) 个键值项。为避免 iOS 编译器在复杂 SwiftUI 表达式上崩溃，请暂时使用下方原始 JSON 编辑。")
                    .foregroundColor(Color.secondary)
            }
        }
        .onAppear { loadRows() }
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
