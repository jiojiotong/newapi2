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
    @State private var priority = ""
    @State private var weight = ""
    @State private var status = 1
    @State private var modelMapping = ""
    @State private var tag = ""
    @State private var remark = ""
    @State private var isSaving = false
    @State private var isFetchingModels = false
    @State private var availableGroups: [String] = []
    @State private var selectedGroups: Set<String> = ["default"]
    @State private var channelModelPricing: [ChannelModelPriceItem] = []

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
                Button {
                    Task { await fetchModelsFromUpstream() }
                } label: {
                    HStack {
                        if isFetchingModels {
                            ProgressView()
                                .padding(.trailing, 4)
                        }
                        Text("从上游获取模型列表")
                    }
                }
                .disabled(key.isEmpty || isFetchingModels)
            }

            Section("分组与调度") {
                if availableGroups.isEmpty {
                    Text("加载分组中...")
                        .foregroundColor(Color.secondary)
                } else {
                    ForEach(availableGroups, id: \.self) { groupName in
                        Button {
                            if selectedGroups.contains(groupName) {
                                selectedGroups.remove(groupName)
                            } else {
                                selectedGroups.insert(groupName)
                            }
                        } label: {
                            HStack {
                                Text(groupName)
                                    .foregroundColor(Color.primary)
                                Spacer()
                                if selectedGroups.contains(groupName) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                        }
                    }
                }
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

            if editingChannel != nil {
                Section(header: Text("模型定价（全局）"), footer: Text("定价为全局设置，修改会影响所有使用同名模型的渠道")) {
                    if channelModelPricing.isEmpty {
                        Text("暂无定价信息")
                            .foregroundColor(Color.secondary)
                    } else {
                        ForEach(channelModelPricing, id: \.modelName) { item in
                            NavigationLink {
                                ChannelModelPriceEditView(
                                    modelName: item.modelName,
                                    inputPrice: item.inputPrice,
                                    outputPrice: item.outputPrice,
                                    onSave: { newInput, newOutput in
                                        updateModelPrice(item.modelName, inputPrice: newInput, outputPrice: newOutput)
                                    }
                                )
                            } label: {
                                HStack {
                                    Text(item.modelName)
                                        .font(Font.subheadline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text("输入 \(formatPriceValue(item.inputPrice)) / 输出 \(formatPriceValue(item.outputPrice))")
                                        .font(Font.caption)
                                        .foregroundColor(Color.secondary)
                                }
                            }
                        }
                    }
                    Button("刷新定价") {
                        Task { await loadChannelPricing() }
                    }
                }
            }

            Section {
                Button(editingChannel == nil ? "创建渠道" : "保存修改") {
                    Task { await save() }
                }
                .disabled(isSaving || name.isEmpty || key.isEmpty)
            }
        }
        .navigationTitle(editingChannel == nil ? "新增渠道" : "编辑渠道")
        .task {
            availableGroups = await viewModel.fetchGroups()
            loadFromChannel()
            if editingChannel != nil {
                await loadChannelPricing()
            }
        }
    }

    private func loadFromChannel() {
        guard let channel = editingChannel else { return }
        name = channel.name
        type = channel.type ?? 1
        status = channel.status ?? 1
        priority = channel.priority.map { String($0) } ?? ""
        weight = channel.weight.map { String($0) } ?? ""

        // Parse group string into selected set
        let groupStr = channel.group ?? "default"
        selectedGroups = Set(groupStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })

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
            "group": .string(selectedGroups.sorted().joined(separator: ",")),
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

    private func fetchModelsFromUpstream() async {
        isFetchingModels = true
        defer { isFetchingModels = false }

        let fetchedModels: [String]?
        if let channel = editingChannel {
            fetchedModels = await viewModel.fetchModels(channelId: channel.id)
        } else {
            let firstKey = key.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespaces) ?? key
            fetchedModels = await viewModel.fetchModels(type: type, key: firstKey, baseURL: baseURL)
        }

        if let fetched = fetchedModels, !fetched.isEmpty {
            models = fetched.joined(separator: "\n")
        }
    }

    private func loadChannelPricing() async {
        // Get current channel's models
        let channelModels = models
            .components(separatedBy: CharacterSet.newlines)
            .flatMap { $0.components(separatedBy: ",") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !channelModels.isEmpty else {
            channelModelPricing = []
            return
        }

        // Fetch global pricing options
        do {
            let options = try await viewModel.fetchPricingOptions()
            let modelRatioMap = parsePricingJSON(options["ModelRatio"])
            let completionRatioMap = parsePricingJSON(options["CompletionRatio"])
            let modelPriceMap = parsePricingJSON(options["ModelPrice"])

            channelModelPricing = channelModels.map { name in
                let mr = modelRatioMap[name] ?? 1
                let cr = completionRatioMap[name] ?? 1
                let mp = modelPriceMap[name]
                if let fixedPrice = mp, fixedPrice > 0 {
                    return ChannelModelPriceItem(modelName: name, inputPrice: fixedPrice, outputPrice: fixedPrice, isFixedPrice: true)
                }
                return ChannelModelPriceItem(modelName: name, inputPrice: mr * 2, outputPrice: mr * 2 * cr, isFixedPrice: false)
            }
        } catch {
            channelModelPricing = []
        }
    }

    private func updateModelPrice(_ modelName: String, inputPrice: Double, outputPrice: Double) {
        if let index = channelModelPricing.firstIndex(where: { $0.modelName == modelName }) {
            channelModelPricing[index].inputPrice = inputPrice
            channelModelPricing[index].outputPrice = outputPrice
        }
        // Save to global pricing via viewModel
        Task {
            let rawModelRatio = inputPrice / 2
            let rawCompletionRatio = inputPrice > 0 ? outputPrice / inputPrice : 1
            await viewModel.updateSingleModelPricing(modelName: modelName, modelRatio: rawModelRatio, completionRatio: rawCompletionRatio)
        }
    }

    private func formatPriceValue(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(Int(value))
        }
        return String(format: "%.4g", value)
    }

    private func parsePricingJSON(_ jsonString: String?) -> [String: Double] {
        guard let str = jsonString, let data = str.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: Double] = [:]
        for (key, value) in obj {
            if let num = value as? Double { result[key] = num }
            else if let num = value as? Int { result[key] = Double(num) }
        }
        return result
    }
}

struct ChannelModelPriceItem {
    let modelName: String
    var inputPrice: Double
    var outputPrice: Double
    var isFixedPrice: Bool
}

private struct ChannelModelPriceEditView: View {
    let modelName: String
    @State var inputPrice: Double
    @State var outputPrice: Double
    let onSave: (Double, Double) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var outputText = ""

    var body: some View {
        Form {
            Section(header: Text("模型定价"), footer: Text("单位：$/1M tokens。修改为全局生效。")) {
                LabeledContent("输入价格") {
                    TextField("输入", text: $inputText)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("输出价格") {
                    TextField("输出", text: $outputText)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
            }
            Section {
                Button("保存定价") {
                    let newInput = Double(inputText) ?? inputPrice
                    let newOutput = Double(outputText) ?? outputPrice
                    onSave(newInput, newOutput)
                    dismiss()
                }
            }
        }
        .navigationTitle(modelName)
        .onAppear {
            inputText = formatValue(inputPrice)
            outputText = formatValue(outputPrice)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(Int(value))
        }
        return String(value)
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
