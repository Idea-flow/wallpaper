import AppKit // NSWorkspace
import Foundation // URLSession

// UpdateService：检查远端 JSON 更新信息
enum UpdateService {
    struct UpdatePayload: Decodable {
        let latest: UpdateRelease
        let minimum: UpdateMinimum?
    }

    struct UpdateRelease: Decodable {
        let version: String
        let build: Int
        let title: String
        let notes: String
        let pubDate: String
        let downloadURL: URL
        let sizeBytes: Int?
        let sha256: String?

        private enum CodingKeys: String, CodingKey {
            case version
            case build
            case title
            case notes
            case pubDate = "pub_date"
            case downloadURL = "download_url"
            case sizeBytes = "size_bytes"
            case sha256
        }
    }

    struct UpdateMinimum: Decodable {
        let version: String
        let build: Int
    }

    enum CheckResult {
        case upToDate
        case updateAvailable(release: UpdateRelease, isMandatory: Bool)
    }

    static func checkUpdates(from feedURL: URL) async throws -> CheckResult {
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw NSError(domain: "UpdateService", code: 1, userInfo: [NSLocalizedDescriptionKey: "更新信息请求失败"])
        }
        let payload = try JSONDecoder().decode(UpdatePayload.self, from: data)

        let currentBuild = currentBuildNumber()
        let currentVersion = currentVersionString()

        let isMandatory = payload.minimum.map { $0.build > currentBuild } ?? false
        if payload.latest.build > currentBuild {
            return .updateAvailable(release: payload.latest, isMandatory: isMandatory)
        }

        if payload.latest.build == currentBuild,
           compareVersion(currentVersion, payload.latest.version) == .orderedAscending {
            return .updateAvailable(release: payload.latest, isMandatory: isMandatory)
        }

        return .upToDate
    }

    static func openDownload(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func currentVersionString() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    static func currentBuildNumber() -> Int {
        let raw = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return Int(raw) ?? 0
    }

    private static func compareVersion(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
        let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(left.count, right.count)
        for index in 0..<maxCount {
            let l = index < left.count ? left[index] : 0
            let r = index < right.count ? right[index] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}
