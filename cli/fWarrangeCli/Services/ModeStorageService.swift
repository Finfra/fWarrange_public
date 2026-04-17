import Foundation

// MARK: - 프로토콜

protocol ModeStorageService {
    var modesDirectoryPath: String { get }
    func save(_ mode: Mode) throws
    func load(name: String) throws -> Mode
    func listModes() throws -> [Mode]
    func listModeMetadata() throws -> [ModeMetadata]
    func delete(name: String) throws
    func rename(oldName: String, newName: String) throws
}

// MARK: - 구현체

/// Mode YAML 파일을 `{dataDir}/modes/` 디렉토리에서 관리
final class YAMLModeStorageService: ModeStorageService {
    private let modesDirectory: URL

    init(baseDirectory: URL) {
        self.modesDirectory = baseDirectory
            .appendingPathComponent(YAMLLayoutStorageService.currentHostname())
            .appendingPathComponent("modes")
    }

    var modesDirectoryPath: String { modesDirectory.path }

    // MARK: - YAML 직렬화

    /// Mode → YAML 문자열 (v2 스키마)
    private func serializeToYAML(_ mode: Mode) -> String {
        var yaml = "version: 2\n"
        yaml += "mode:\n"
        yaml += "  name: \"\(escapeYAML(mode.name))\"\n"
        yaml += "  icon: \"\(escapeYAML(mode.icon))\"\n"
        if let shortcut = mode.shortcut, !shortcut.isEmpty {
            yaml += "  shortcut: \"\(escapeYAML(shortcut))\"\n"
        }
        yaml += "  layout: \"\(escapeYAML(mode.layoutRef))\"\n"
        if !mode.requiredApps.isEmpty {
            yaml += "  apps:\n"
            for app in mode.requiredApps {
                yaml += "    - bundleId: \"\(escapeYAML(app.bundleId))\"\n"
                yaml += "      action: \"\(app.action.rawValue)\"\n"
            }
        }
        return yaml
    }

    private func escapeYAML(_ value: String) -> String {
        value.replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - YAML 파싱

    /// YAML 문자열 → Mode (v2 스키마)
    private func parseYAML(_ content: String, fileName: String) -> Mode? {
        var name: String?
        var icon = "rectangle.3.group"
        var shortcut: String?
        var layoutRef: String?
        var requiredApps: [AppConfig] = []

        // apps 블록 파싱 상태
        var inAppsBlock = false
        var currentBundleId: String?
        var currentAction: AppAction?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // apps 블록 종료 판별 — apps 내부가 아닌 최상위 키 만나면 종료
            if inAppsBlock && !trimmed.isEmpty && !trimmed.hasPrefix("-") && !trimmed.hasPrefix("bundleId:") && !trimmed.hasPrefix("action:") {
                // 마지막 앱 저장
                if let bid = currentBundleId {
                    requiredApps.append(AppConfig(bundleId: bid, action: currentAction ?? .launch))
                    currentBundleId = nil
                    currentAction = nil
                }
                inAppsBlock = false
            }

            if inAppsBlock {
                if trimmed.hasPrefix("- bundleId:") {
                    // 이전 앱 저장
                    if let bid = currentBundleId {
                        requiredApps.append(AppConfig(bundleId: bid, action: currentAction ?? .launch))
                    }
                    currentBundleId = parseStringValue(String(trimmed.dropFirst(11)))
                    currentAction = nil
                } else if trimmed.hasPrefix("bundleId:") {
                    currentBundleId = parseStringValue(String(trimmed.dropFirst(9)))
                } else if trimmed.hasPrefix("action:") {
                    let actionStr = parseStringValue(String(trimmed.dropFirst(7)))
                    currentAction = AppAction(rawValue: actionStr)
                }
            } else if trimmed.hasPrefix("name:") {
                name = parseStringValue(String(trimmed.dropFirst(5)))
            } else if trimmed.hasPrefix("icon:") {
                icon = parseStringValue(String(trimmed.dropFirst(5)))
            } else if trimmed.hasPrefix("shortcut:") {
                shortcut = parseStringValue(String(trimmed.dropFirst(9)))
            } else if trimmed.hasPrefix("layout:") {
                layoutRef = parseStringValue(String(trimmed.dropFirst(7)))
            } else if trimmed == "apps:" {
                inAppsBlock = true
            }
        }

        // 파일 끝에서 마지막 앱 저장
        if let bid = currentBundleId {
            requiredApps.append(AppConfig(bundleId: bid, action: currentAction ?? .launch))
        }

        // name 없으면 파일명 사용
        let modeName = name ?? fileName
        // layoutRef 없으면 name과 동일하게 설정
        let ref = layoutRef ?? modeName

        return Mode(name: modeName, icon: icon, shortcut: shortcut, layoutRef: ref, requiredApps: requiredApps)
    }

    /// version 필드 확인 — v2 스키마인지 판별
    private func isV2Schema(_ content: String) -> Bool {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("version:") {
                let val = trimmed.dropFirst(8).trimmingCharacters(in: .whitespaces)
                return val == "2"
            }
        }
        return false
    }

    private func parseStringValue(_ raw: String) -> String {
        let val = raw.trimmingCharacters(in: .whitespaces)
        if val.hasPrefix("\"") && val.hasSuffix("\"") {
            return String(val.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
        }
        return val
    }

    // MARK: - CRUD

    func save(_ mode: Mode) throws {
        try FileManager.default.createDirectory(at: modesDirectory, withIntermediateDirectories: true)
        let fileURL = modesDirectory.appendingPathComponent("\(mode.name).yml")
        let yaml = serializeToYAML(mode)
        try yaml.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func load(name: String) throws -> Mode {
        let fileURL = modesDirectory.appendingPathComponent("\(name).yml")
        let content = try String(contentsOf: fileURL, encoding: .utf8)

        guard isV2Schema(content) else {
            throw ModeStorageError.notV2Schema(name)
        }

        guard let mode = parseYAML(content, fileName: name) else {
            throw ModeStorageError.parseFailed(name)
        }

        return mode
    }

    func listModes() throws -> [Mode] {
        guard FileManager.default.fileExists(atPath: modesDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: modesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return files
            .filter { $0.pathExtension == "yml" }
            .compactMap { fileURL -> Mode? in
                let name = fileURL.deletingPathExtension().lastPathComponent
                return try? load(name: name)
            }
            .sorted { $0.name < $1.name }
    }

    func listModeMetadata() throws -> [ModeMetadata] {
        guard FileManager.default.fileExists(atPath: modesDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: modesDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return files
            .filter { $0.pathExtension == "yml" }
            .compactMap { fileURL -> ModeMetadata? in
                let name = fileURL.deletingPathExtension().lastPathComponent
                guard let content = try? String(contentsOf: fileURL, encoding: .utf8),
                      isV2Schema(content),
                      let mode = parseYAML(content, fileName: name) else { return nil }
                let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileDate = attrs?[.modificationDate] as? Date ?? Date()
                return ModeMetadata(
                    name: mode.name,
                    icon: mode.icon,
                    shortcut: mode.shortcut,
                    layoutRef: mode.layoutRef,
                    requiredApps: mode.requiredApps,
                    fileDate: fileDate
                )
            }
            .sorted { $0.name < $1.name }
    }

    func delete(name: String) throws {
        let fileURL = modesDirectory.appendingPathComponent("\(name).yml")
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ModeStorageError.notFound(name)
        }
        try FileManager.default.removeItem(at: fileURL)
    }

    func rename(oldName: String, newName: String) throws {
        let oldURL = modesDirectory.appendingPathComponent("\(oldName).yml")
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw ModeStorageError.notFound(oldName)
        }
        // 파일 이동 후 내부 name 필드도 갱신
        var mode = try load(name: oldName)
        mode.name = newName
        try FileManager.default.removeItem(at: oldURL)
        try save(mode)
    }
}

// MARK: - 에러

/// 모드 전환 에러
enum ModeActivationError: LocalizedError {
    case alreadyInProgress

    var errorDescription: String? {
        switch self {
        case .alreadyInProgress: return "모드 전환이 이미 진행 중입니다"
        }
    }
}

enum ModeStorageError: LocalizedError {
    case notFound(String)
    case notV2Schema(String)
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let name): return "모드를 찾을 수 없습니다: \(name)"
        case .notV2Schema(let name): return "v2 스키마가 아닙니다: \(name)"
        case .parseFailed(let name): return "모드 파싱 실패: \(name)"
        }
    }
}
