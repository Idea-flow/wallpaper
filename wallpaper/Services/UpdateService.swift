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

    enum DownloadResult {
        case success(fileURL: URL)
        case failure(Error)
    }

    static func checkUpdates(from feedURL: URL) async throws -> CheckResult {
        LogCenter.log("[更新] 开始请求更新 JSON：\(feedURL.absoluteString)")
        let (data, response) = try await URLSession.shared.data(from: feedURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            LogCenter.log("[更新] 请求更新 JSON 失败", level: .error)
            throw NSError(domain: "UpdateService", code: 1, userInfo: [NSLocalizedDescriptionKey: "更新信息请求失败"])
        }
        let payload: UpdatePayload
        do {
            payload = try JSONDecoder().decode(UpdatePayload.self, from: data)
        } catch {
            LogCenter.log("[更新] 解析更新 JSON 失败：\(error.localizedDescription)", level: .error)
            throw error
        }
        LogCenter.log("[更新] 解析更新 JSON 成功：latest=\(payload.latest.version)(\(payload.latest.build))")

        let currentBuild = currentBuildNumber()
        let currentVersion = currentVersionString()

        let isMandatory = payload.minimum.map { $0.build > currentBuild } ?? false
        if payload.latest.build > currentBuild {
            LogCenter.log("[更新] 检测到新版本（build 更高）：\(payload.latest.version)(\(payload.latest.build))")
            return .updateAvailable(release: payload.latest, isMandatory: isMandatory)
        }

        if payload.latest.build == currentBuild,
           compareVersion(currentVersion, payload.latest.version) == .orderedAscending {
            LogCenter.log("[更新] 检测到新版本（version 更高）：\(payload.latest.version)(\(payload.latest.build))")
            return .updateAvailable(release: payload.latest, isMandatory: isMandatory)
        }

        LogCenter.log("[更新] 已是最新版本")
        return .upToDate
    }

    static func openDownload(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    static func downloadUpdate(_ release: UpdateRelease, progress: @escaping (Double) -> Void) async -> DownloadResult {
        LogCenter.log("[更新] 开始下载更新包：\(release.downloadURL.absoluteString)")
        let downloadDir: URL
        do {
            downloadDir = try await resolveDownloadDirectory()
        } catch {
            LogCenter.log("[更新] 获取下载目录失败：\(error.localizedDescription)", level: .error)
            return .failure(error)
        }
        let delegate = DownloadDelegate()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let task = session.downloadTask(with: release.downloadURL)
        return await withCheckedContinuation { continuation in
            delegate.start(
                task: task,
                onProgress: { value in
                    LogCenter.log("[更新] 下载进度：\(Int(value * 100))%")
                    progress(value)
                },
                onCompletion: { result in
                    switch result {
                    case .success(let tempURL):
                        do {
                            let fileName = release.downloadURL.lastPathComponent
                            let didAccess = downloadDir.startAccessingSecurityScopedResource()
                            defer { if didAccess { downloadDir.stopAccessingSecurityScopedResource() } }
                            let target = downloadDir.appendingPathComponent(fileName)
                            if FileManager.default.fileExists(atPath: target.path) {
                                try? FileManager.default.removeItem(at: target)
                            }
                            try FileManager.default.moveItem(at: tempURL, to: target)
                            LogCenter.log("[更新] 下载完成：\(target.path)")
                            continuation.resume(returning: .success(fileURL: target))
                        } catch {
                            LogCenter.log("[更新] 保存下载文件失败：\(error.localizedDescription)", level: .error)
                            continuation.resume(returning: .failure(error))
                        }
                    case .failure(let error):
                        LogCenter.log("[更新] 下载失败：\(error.localizedDescription)", level: .error)
                        continuation.resume(returning: .failure(error))
                    }
                }
            )
        }
    }

    static func revealInFinder(_ url: URL) {
        LogCenter.log("[更新] 在 Finder 中显示下载文件：\(url.lastPathComponent)")
        NSWorkspace.shared.activateFileViewerSelecting([url])
        if !FileManager.default.fileExists(atPath: url.path) {
            LogCenter.log("[更新] 下载文件不存在，改为打开目录：\(url.deletingLastPathComponent().path)", level: .warning)
            NSWorkspace.shared.open(url.deletingLastPathComponent())
        }
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

    private static func resolveDownloadDirectory() async throws -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        if let downloads {
            let isSandboxPath = downloads.path.contains("/Library/Containers/")
            if !isSandboxPath, FileManager.default.isWritableFile(atPath: downloads.path) {
                LogCenter.log("[更新] 使用系统下载文件夹：\(downloads.path)")
                return downloads
            }
            if isSandboxPath {
                LogCenter.log("[更新] 检测到沙盒下载目录，尝试申请用户下载文件夹权限", level: .warning)
            } else {
                LogCenter.log("[更新] 下载文件夹无权限，申请用户授权", level: .warning)
            }
        }
        do {
            return try await requestDownloadDirectory(defaultURL: downloads)
        } catch {
            if let downloads {
                LogCenter.log("[更新] 用户未授权，回退使用下载目录：\(downloads.path)", level: .warning)
                return downloads
            }
            throw error
        }
    }

    @MainActor
    private static func requestDownloadDirectory(defaultURL: URL?) throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = defaultURL
        panel.message = "需要访问“下载”文件夹以保存更新包，请选择下载文件夹。"
        let result = panel.runModal()
        if result == .OK, let url = panel.url {
            LogCenter.log("[更新] 用户授权下载目录：\(url.path)")
            return url
        }
        throw NSError(domain: "UpdateService", code: 3, userInfo: [NSLocalizedDescriptionKey: "用户取消选择下载目录"])
    }
}

private final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private var onProgress: ((Double) -> Void)?
    private var onCompletion: ((Result<URL, Error>) -> Void)?
    private var lastLoggedPercent: Int = -1

    func start(
        task: URLSessionDownloadTask,
        onProgress: @escaping (Double) -> Void,
        onCompletion: @escaping (Result<URL, Error>) -> Void
    ) {
        self.onProgress = onProgress
        self.onCompletion = onCompletion
        task.resume()
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        onCompletion?(.success(location))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            onCompletion?(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let percent = Int(progress * 100)
        if percent != lastLoggedPercent {
            lastLoggedPercent = percent
            DispatchQueue.main.async { [weak self] in
                self?.onProgress?(progress)
            }
        }
    }
}
