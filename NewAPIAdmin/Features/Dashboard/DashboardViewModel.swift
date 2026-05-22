import Combine
import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var statusText = "未加载"
    @Published var channelCountText = "-"
    @Published var userCountText = "-"
    @Published var redemptionCountText = "-"
    @Published var errors: [String] = []

    private let service: DashboardService

    init(service: DashboardService) {
        self.service = service
    }

    func load() async {
        errors = []
        await loadStatus()
        await loadChannelCount()
        await loadUserCount()
        await loadRedemptionCount()
    }

    private func loadStatus() async {
        do {
            let status = try await service.status()
            statusText = status.version.map { "已连接，版本 \($0)" } ?? "已连接"
        } catch {
            statusText = "连接异常"
            errors.append(error.localizedDescription)
        }
    }

    private func loadChannelCount() async {
        do {
            channelCountText = String(try await service.channelCount())
        } catch {
            channelCountText = "加载失败"
        }
    }

    private func loadUserCount() async {
        do {
            userCountText = String(try await service.userCount())
        } catch {
            userCountText = "加载失败"
        }
    }

    private func loadRedemptionCount() async {
        do {
            redemptionCountText = String(try await service.redemptionCount())
        } catch {
            redemptionCountText = "加载失败"
        }
    }
}
