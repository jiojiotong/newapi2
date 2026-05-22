import Combine
import Foundation

@MainActor
public final class SessionStore: ObservableObject {
    @Published private(set) var profile: ServerProfile?
    @Published private(set) var adminUser: AdminUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastServerURL = ""

    private let storage = ProfileStorage()
    private let credentialStorage = CredentialStorage()
    private var client: NewAPIClient?

    public init() {
        lastServerURL = storage.lastServerURL()
    }

    var isAuthenticated: Bool {
        profile != nil && adminUser?.isAdmin == true
    }

    func restoreSessionIfPossible() async {
        guard profile == nil, adminUser == nil, let saved = storage.load() else {
            return
        }

        profile = saved.0
        adminUser = saved.1
        let restoredClient = NewAPIClient(baseURL: saved.0.baseURL)
        restoredClient.setUserId(saved.1.id)
        client = restoredClient

        do {
            let user: AdminUser = try await restoredClient.get("/api/user/self")
            guard user.isAdmin else {
                clearLocalSession()
                return
            }
            adminUser = user
            storage.save(profile: saved.0, user: user)
        } catch {
            clearLocalSession()
        }
    }

    func login(serverURL: String, username: String, password: String, rememberPassword: Bool = false) async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            let normalizedURL = try normalizeServerURL(serverURL)
            let apiClient = NewAPIClient(baseURL: normalizedURL)
            let _: AnyJSONValue = try await apiClient.get("/api/status")
            let loginResponse: LoginResponse = try await apiClient.post("/api/user/login", body: LoginRequest(username: username, password: password))

            if loginResponse.requiresTwoFactor {
                throw NewAPIError.twoFactorUnsupported
            }

            // If login response contains user info directly, use it; otherwise fetch from /api/user/self
            let user: AdminUser
            if let responseUser = loginResponse.adminUser {
                user = responseUser
            } else {
                throw NewAPIError.missingData
            }

            // Set user ID for New-Api-User header on all subsequent requests
            apiClient.setUserId(user.id)

            guard user.isAdmin else {
                do {
                    let _: EmptyResponseData = try await apiClient.get("/api/user/logout")
                } catch {
                    // Ignore logout failures while rejecting non-admin users.
                }
                storage.clear()
                throw NewAPIError.administratorRequired
            }

            let serverProfile = ServerProfile(
                name: normalizedURL.host ?? normalizedURL.absoluteString,
                baseURL: normalizedURL,
                lastUser: user.username
            )

            profile = serverProfile
            adminUser = user
            client = apiClient
            storage.save(profile: serverProfile, user: user)
            lastServerURL = normalizedURL.absoluteString
            if rememberPassword {
                credentialStorage.save(password: password, serverURL: normalizedURL, username: username)
            } else {
                credentialStorage.delete(serverURL: normalizedURL, username: username)
            }
        } catch let error as NewAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        if let client {
            do {
                let _: EmptyResponseData = try await client.get("/api/user/logout")
            } catch {
                // Local logout should still succeed if the server session is already gone.
            }
        }
        profile = nil
        adminUser = nil
        client = nil
        storage.clear()
    }

    func revalidateSession() async {
        errorMessage = nil
        guard let client else {
            errorMessage = NewAPIError.unauthorized.localizedDescription
            return
        }

        do {
            let user: AdminUser = try await client.get("/api/user/self")
            guard user.isAdmin else {
                clearLocalSession()
                throw NewAPIError.administratorRequired
            }
            adminUser = user
            if let profile {
                storage.save(profile: profile, user: user)
            }
        } catch let error as NewAPIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearLocalData() {
        clearLocalSession(clearAllProfileData: true)
        credentialStorage.clearAll()
    }

    func rememberedPassword(serverURL: String, username: String) -> String? {
        guard let url = try? normalizeServerURL(serverURL), !username.isEmpty else {
            return nil
        }
        return credentialStorage.load(serverURL: url, username: username)
    }

    func activeClient() throws -> NewAPIClient {
        guard let client else {
            throw NewAPIError.unauthorized
        }
        return client
    }

    private func normalizeServerURL(_ value: String) throws -> URL {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NewAPIError.invalidServerURL
        }

        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme), url.scheme != nil, url.host != nil else {
            throw NewAPIError.invalidServerURL
        }
        return url
    }

    private func clearLocalSession(clearAllProfileData: Bool = false) {
        profile = nil
        adminUser = nil
        client = nil
        if clearAllProfileData {
            storage.clearAll()
            lastServerURL = ""
        } else {
            storage.clear()
        }
    }
}
