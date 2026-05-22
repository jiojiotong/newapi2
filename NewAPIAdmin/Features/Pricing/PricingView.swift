import SwiftUI

struct PricingView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                PricingContentView(viewModel: viewModel)
            } else {
                LoadingStateView(title: "准备定价管理")
            }
        }
        .navigationTitle("定价")
        .task { setupAndLoad() }
    }

    private func setupAndLoad() {
        guard holder.viewModel == nil, let client = try? sessionStore.activeClient() else { return }
        let viewModel = PricingViewModel(service: PricingService(client: client))
        holder.viewModel = viewModel
        Task { await viewModel.load() }
    }

    @MainActor private final class Holder: ObservableObject {
        @Published var viewModel: PricingViewModel?
    }
}

private struct PricingContentView: View {
    @ObservedObject var viewModel: PricingViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("类型", selection: $selectedTab) {
                Text("模型定价").tag(0)
                Text("分组倍率").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(Color.red).padding(.horizontal)
            }
            if let success = viewModel.successMessage {
                Text(success).foregroundColor(Color.green).padding(.horizontal)
            }

            if selectedTab == 0 {
                ModelPricingListView(viewModel: viewModel)
            } else {
                GroupRatioListView(viewModel: viewModel)
            }
        }
        .overlay {
            if viewModel.isLoading { LoadingStateView(title: "加载定价配置") }
        }
        .toolbar {
            Button("保存") { Task { await viewModel.saveAll() } }
                .disabled(viewModel.isLoading)
            Button("刷新") { Task { await viewModel.load() } }
                .disabled(viewModel.isLoading)
        }
    }
}

// MARK: - Model Pricing Table

private struct ModelPricingListView: View {
    @ObservedObject var viewModel: PricingViewModel
    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var newModelName = ""

    private var filteredModels: [ModelPricingRow] {
        if searchText.isEmpty {
            return viewModel.modelRows
        }
        let query = searchText.lowercased()
        return viewModel.modelRows.filter { $0.modelName.lowercased().contains(query) }
    }

    var body: some View {
        List {
            Section {
                Text("共 \(viewModel.modelRows.count) 个模型")
                    .font(Font.caption)
                    .foregroundColor(Color.secondary)
            }

            ForEach(filteredModels) { row in
                NavigationLink {
                    ModelPricingEditView(viewModel: viewModel, modelName: row.modelName)
                } label: {
                    ModelPricingRowView(row: row)
                }
            }
            .onDelete { indexSet in
                let models = filteredModels
                for index in indexSet {
                    viewModel.removeModel(models[index].modelName)
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索模型")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加模型") { showingAdd = true }
            }
        }
        .alert("添加模型", isPresented: $showingAdd) {
            TextField("模型名称", text: $newModelName)
            Button("添加") {
                let name = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    viewModel.addModel(name)
                }
                newModelName = ""
            }
            Button("取消", role: .cancel) { newModelName = "" }
        }
    }
}

private struct ModelPricingRowView: View {
    let row: ModelPricingRow

    private var inputDisplay: Double { row.modelRatio * 2 }
    private var outputDisplay: Double { row.modelRatio * 2 * row.completionRatio }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.modelName)
                .font(Font.headline)
                .lineLimit(1)
            HStack(spacing: 12) {
                if let price = row.modelPrice, price > 0 {
                    Label("固定 \(formatNumber(price))", systemImage: "dollarsign.circle")
                } else {
                    Label("输入 \(formatNumber(inputDisplay))", systemImage: "arrow.right")
                    Label("输出 \(formatNumber(outputDisplay))", systemImage: "arrow.left")
                }
            }
            .font(Font.caption)
            .foregroundColor(Color.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formatNumber(_ value: Double) -> String {
        if value == value.rounded() && value < 10000 {
            return String(Int(value))
        }
        return String(format: "%.4g", value)
    }
}

// MARK: - Model Pricing Edit

private struct ModelPricingEditView: View {
    @ObservedObject var viewModel: PricingViewModel
    let modelName: String

    @State private var modelRatio = ""
    @State private var completionRatio = ""
    @State private var modelPrice = ""
    @State private var cacheRatio = ""
    @State private var createCacheRatio = ""
    @State private var imageRatio = ""
    @State private var audioRatio = ""
    @State private var audioCompletionRatio = ""

    var body: some View {
        Form {
            Section(header: Text("基本定价"), footer: Text("输入/输出价格单位为 $/1M tokens")) {
                LabeledContent("输入价格") {
                    TextField("默认 2", text: $modelRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("输出价格") {
                    TextField("默认与输入相同", text: $completionRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("固定价格（$/次）") {
                    TextField("不设置则用 token 计费", text: $modelPrice)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("扩展倍率") {
                LabeledContent("缓存倍率") {
                    TextField("不设置", text: $cacheRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("创建缓存倍率") {
                    TextField("不设置", text: $createCacheRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("图片倍率") {
                    TextField("不设置", text: $imageRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("音频输入倍率") {
                    TextField("不设置", text: $audioRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("音频输出倍率") {
                    TextField("不设置", text: $audioCompletionRatio)
                        .adminDecimalKeyboard()
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                Button("应用修改") {
                    applyChanges()
                }
            }
        }
        .navigationTitle(modelName)
        .onAppear { loadValues() }
    }

    private func loadValues() {
        let row = viewModel.modelRows.first(where: { $0.modelName == modelName })
        // Display as $/1M tokens (modelRatio * 2 for input, modelRatio * 2 * completionRatio for output)
        let mr = row?.modelRatio ?? 1
        let cr = row?.completionRatio ?? 1
        modelRatio = formatOptional(mr * 2)
        completionRatio = formatOptional(mr * 2 * cr)
        modelPrice = formatOptional(row?.modelPrice)
        cacheRatio = formatOptional(row?.cacheRatio)
        createCacheRatio = formatOptional(row?.createCacheRatio)
        imageRatio = formatOptional(row?.imageRatio)
        audioRatio = formatOptional(row?.audioRatio)
        audioCompletionRatio = formatOptional(row?.audioCompletionRatio)
    }

    private func applyChanges() {
        // Convert display values back to raw ratios
        let inputPrice = Double(modelRatio) ?? 2
        let outputPrice = Double(completionRatio) ?? inputPrice
        let rawModelRatio = inputPrice / 2
        let rawCompletionRatio = inputPrice > 0 ? outputPrice / inputPrice : 1

        viewModel.updateModel(
            modelName,
            modelRatio: rawModelRatio,
            completionRatio: rawCompletionRatio,
            modelPrice: Double(modelPrice),
            cacheRatio: Double(cacheRatio),
            createCacheRatio: Double(createCacheRatio),
            imageRatio: Double(imageRatio),
            audioRatio: Double(audioRatio),
            audioCompletionRatio: Double(audioCompletionRatio)
        )
    }

    private func formatOptional(_ value: Double?) -> String {
        guard let value, value != 0 else { return "" }
        if value == value.rounded() && value < 100000 {
            return String(Int(value))
        }
        return String(value)
    }
}

// MARK: - Group Ratio

private struct GroupRatioListView: View {
    @ObservedObject var viewModel: PricingViewModel
    @State private var showingAdd = false
    @State private var newGroupName = ""

    var body: some View {
        List {
            Section {
                Text("分组倍率决定不同用户分组的价格系数")
                    .font(Font.caption)
                    .foregroundColor(Color.secondary)
            }

            ForEach(viewModel.groupRows) { row in
                GroupRatioRowView(viewModel: viewModel, row: row)
            }
            .onDelete { indexSet in
                let groups = viewModel.groupRows
                for index in indexSet {
                    viewModel.removeGroup(groups[index].groupName)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("添加分组") { showingAdd = true }
            }
        }
        .alert("添加分组", isPresented: $showingAdd) {
            TextField("分组名称", text: $newGroupName)
            Button("添加") {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    viewModel.addGroup(name)
                }
                newGroupName = ""
            }
            Button("取消", role: .cancel) { newGroupName = "" }
        }
    }
}

private struct GroupRatioRowView: View {
    @ObservedObject var viewModel: PricingViewModel
    let row: GroupRatioRow

    @State private var ratioText: String = ""

    var body: some View {
        HStack {
            Text(row.groupName)
                .font(Font.headline)
            Spacer()
            TextField("倍率", text: $ratioText)
                .adminDecimalKeyboard()
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
                .onChange(of: ratioText) { newValue in
                    if let value = Double(newValue) {
                        viewModel.updateGroup(row.groupName, ratio: value)
                    }
                }
        }
        .onAppear {
            if row.ratio == row.ratio.rounded() && row.ratio < 100000 {
                ratioText = String(Int(row.ratio))
            } else {
                ratioText = String(row.ratio)
            }
        }
    }
}
