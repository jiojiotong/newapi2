import SwiftUI

struct PricingView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var holder = Holder()

    var body: some View {
        Group {
            if let viewModel = holder.viewModel {
                Form {
                    if let error = viewModel.errorMessage {
                        Section { Text(error).foregroundStyle(.red) }
                    }
                    if let success = viewModel.successMessage {
                        Section { Text(success).foregroundStyle(.green) }
                    }

                    Section("选项") {
                        Picker("Key", selection: Binding(get: {
                            viewModel.selectedKey
                        }, set: { key in
                            viewModel.select(key)
                            holder.editorText = viewModel.editorText
                        })) {
                            ForEach(PricingService.primaryKeys, id: \.self) { key in
                                Text(key).tag(key)
                            }
                        }
                    }

                    KeyValueJSONEditorView(jsonText: $holder.editorText)

                    Section("原始 JSON") {
                        TextEditor(text: $holder.editorText)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 260)
                            .onChange(of: holder.editorText) { _, newValue in
                                viewModel.editorText = newValue
                            }
                    }
                }
                .overlay {
                    if viewModel.isLoading { LoadingStateView(title: "加载定价配置") }
                }
                .toolbar {
                    Button("保存") { Task { await viewModel.saveSelected() } }
                    Button("批量保存模型") { Task { await viewModel.saveModelBatch() } }
                    Button("刷新") { Task { await viewModel.load(); holder.editorText = viewModel.editorText } }
                }
                .onChange(of: viewModel.editorText) { _, newValue in
                    holder.editorText = newValue
                }
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
        Task {
            await viewModel.load()
            holder.editorText = viewModel.editorText
        }
    }

    @MainActor private final class Holder: ObservableObject {
        @Published var viewModel: PricingViewModel?
        @Published var editorText = "{}"
    }
}
