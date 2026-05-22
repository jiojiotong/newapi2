import SwiftUI

struct ChannelFormView: View {
    @ObservedObject var viewModel: ChannelsViewModel
    @Environment(\.dismiss) private var dismiss

    let editingChannel: Channel?

    @State private var name = ""
    @State private var type = 1
    @State private var key = ""
    @State private var baseURL = ""
    @State private var models = ""
    @State private var group = "default"
    @State private var priority = ""
    @State private var weight = ""
    @State private var status = 1
    @State private var modelMapping = ""
    @State private var tag = ""
    @State private var remark = ""
    @State private var isSaving = false

    var body: some View {
        Form {
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundColor(Color.red) }
            }

            Section("基本信息") {
                TextField("渠道名称", text: $name)
                    .adminPlainTextInput()
                Picker("渠道类型", selection: $type) {
                    ForEach(ChannelType.allTypes, id: \.id) { ct in
                        Text(ct.name).tag(ct.id)
                    }
                }
                Picker("状态", selection: $status) {
                    Text("启用").tag(1)
                    Text("禁用").tag(2)
                }
            }

            Section("密钥") {
                TextEditor(text: $key)
                    .font(Font.system(Font.TextStyle.body, design: Font.Design.monospaced))
                    .frame(minHeight: 80)
                Text("一行一个密钥，多个密钥自动启用多 Key 模式")
                    .font(Font.caption)
                    .foregroundColor(Color.secondary)
            }

            Section("代理/转发") {
                TextField("Base URL（留空使用默认）", text: $baseURL)
                    .adminURLKeyboard()
            }

            Section("模型") {
                TextEditor(text: $models)
                    .font(Font.system(Font.TextStyle.body, design: Font.Design.monospaced))
                    .frame(minHeight: 80)
                Text("一行一个模型名称，或用逗号分隔")
                    .font(Font.caption)
                    .foregroundColor(Color.secondary)
            }

            Section("分组与调度") {
                TextField("分组（逗号分隔）", text: $group)
                    .adminPlainTextInput()
                HStack {
                    Text("优先级")
                    Spacer()
                    TextField("默认 0", text: $priority)
                        .adminNumberKeyboard()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                HStack {
                    Text("权重")
                    Spacer()
                    TextField("默认 1", text: $weight)
                        .adminNumberKeyboard()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
            }

            Section("高级") {
                TextField("模型映射 JSON（可选）", text: $modelMapping)
                    .adminPlainTextInput()
                TextField("标签（可选）", text: $tag)
                    .adminPlainTextInput()
                TextField("备注（可选）", text: $remark)
                    .adminPlainTextInput()
            }

            Section {
                Button(editingChannel == nil ? "创建渠道" : "保存修改") {
                    Task { await save() }
                }
                .disabled(isSaving || name.isEmpty || key.isEmpty)
            }
        }
        .navigationTitle(editingChannel == nil ? "新增渠道" : "编辑渠道")
        .onAppear { loadFromChannel() }
    }

    private func loadFromChannel() {
        guard let channel = editingChannel else { return }
        name = channel.name
        type = channel.type ?? 1
        status = channel.status ?? 1
        priority = channel.priority.map { String($0) } ?? ""
        weight = channel.weight.map { String($0) } ?? ""
        group = channel.group ?? "default"

        // Load from raw DynamicObject for fields not in the Channel struct
        if case .string(let v) = channel.raw["key"] { key = v }
        if case .string(let v) = channel.raw["base_url"] { baseURL = v }
        if case .string(let v) = channel.raw["models"] { models = v.replacingOccurrences(of: ",", with: "\n") }
        if case .string(let v) = channel.raw["model_mapping"] { modelMapping = v }
        if case .string(let v) = channel.raw["tag"] { tag = v }
        if case .string(let v) = channel.raw["remark"] { remark = v }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }

        let modelsString = models
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")

        var values: [String: AnyJSONValue] = [
            "name": .string(name),
            "type": .int(type),
            "key": .string(key),
            "models": .string(modelsString),
            "group": .string(group),
            "status": .int(status)
        ]

        if !baseURL.trimmingCharacters(in: .whitespaces).isEmpty {
            values["base_url"] = .string(baseURL.trimmingCharacters(in: .whitespaces))
        }
        if let p = Int(priority) {
            values["priority"] = .int(p)
        }
        if let w = Int(weight) {
            values["weight"] = .int(w)
        }
        if !modelMapping.trimmingCharacters(in: .whitespaces).isEmpty {
            values["model_mapping"] = .string(modelMapping.trimmingCharacters(in: .whitespaces))
        }
        if !tag.trimmingCharacters(in: .whitespaces).isEmpty {
            values["tag"] = .string(tag.trimmingCharacters(in: .whitespaces))
        }
        if !remark.trimmingCharacters(in: .whitespaces).isEmpty {
            values["remark"] = .string(remark.trimmingCharacters(in: .whitespaces))
        }

        if let channel = editingChannel {
            values["id"] = .int(channel.id)
            await viewModel.update(DynamicObject(values: values))
        } else {
            await viewModel.create(DynamicObject(values: values))
        }

        if viewModel.errorMessage == nil {
            dismiss()
        }
    }
}

// MARK: - Channel Types

enum ChannelType {
    struct TypeInfo: Identifiable {
        let id: Int
        let name: String
    }

    static let allTypes: [TypeInfo] = [
        TypeInfo(id: 1, name: "OpenAI"),
        TypeInfo(id: 14, name: "Anthropic"),
        TypeInfo(id: 24, name: "Gemini"),
        TypeInfo(id: 43, name: "DeepSeek"),
        TypeInfo(id: 3, name: "Azure"),
        TypeInfo(id: 33, name: "AWS Bedrock"),
        TypeInfo(id: 41, name: "Vertex AI"),
        TypeInfo(id: 4, name: "Ollama"),
        TypeInfo(id: 20, name: "OpenRouter"),
        TypeInfo(id: 40, name: "SiliconFlow"),
        TypeInfo(id: 25, name: "Moonshot"),
        TypeInfo(id: 31, name: "零一万物"),
        TypeInfo(id: 16, name: "智谱 GLM"),
        TypeInfo(id: 17, name: "阿里通义"),
        TypeInfo(id: 15, name: "百度文心"),
        TypeInfo(id: 23, name: "腾讯混元"),
        TypeInfo(id: 45, name: "火山引擎"),
        TypeInfo(id: 35, name: "MiniMax"),
        TypeInfo(id: 18, name: "讯飞星火"),
        TypeInfo(id: 34, name: "Cohere"),
        TypeInfo(id: 42, name: "Mistral"),
        TypeInfo(id: 27, name: "Perplexity"),
        TypeInfo(id: 48, name: "xAI"),
        TypeInfo(id: 49, name: "Coze"),
        TypeInfo(id: 8, name: "自定义渠道"),
        TypeInfo(id: 2, name: "Midjourney"),
        TypeInfo(id: 50, name: "Kling"),
        TypeInfo(id: 38, name: "Jina"),
        TypeInfo(id: 39, name: "Cloudflare"),
        TypeInfo(id: 56, name: "Replicate"),
    ]

    static func name(for type: Int) -> String {
        allTypes.first(where: { $0.id == type })?.name ?? "类型 \(type)"
    }
}
