import Foundation

// MARK: - 프로토콜

protocol LayoutStorageService {
    var dataDirectoryPath: String { get }
    func save(name: String, windows: [WindowInfo]) throws
    func load(name: String) throws -> Layout
    func listLayouts() throws -> [Layout]
    func listLayoutMetadata() throws -> [LayoutMetadata]
    func delete(name: String) throws
    func deleteAll() throws
    func rename(oldName: String, newName: String) throws
}

// MARK: - 구현체

final class YAMLLayoutStorageService: LayoutStorageService {
    private let dataDirectory: URL

    // MARK: - 경로 분기 (host/share 모드)

    init(storageMode: DataStorageMode = .host) {
        let baseDir = Self.resolveDefaultBaseDirectory()

        switch storageMode {
        case .host:
            let hostname = Self.currentHostname()
            self.dataDirectory = baseDir.appendingPathComponent(hostname)
        case .share:
            self.dataDirectory = baseDir.appendingPathComponent("_share")
        }
    }

    init(dataDirectoryURL: URL) {
        self.dataDirectory = dataDirectoryURL
    }

    var dataDirectoryPath: String { dataDirectory.path }

    // MARK: - 기본 데이터 경로 탐색

    static let defaultDataDirectoryPath = "~/Documents/finfra/fWarrangeData"

    /// 환경변수 키: 이 값이 설정되어 있으면 데이터 디렉토리로 사용
    static let envConfigKey = "fWarrangeCli_config"

    /// hostname 헬퍼 — .local 접미사 제거
    static func currentHostname() -> String {
        let hostname = ProcessInfo.processInfo.hostName
        if hostname.hasSuffix(".local") {
            return String(hostname.dropLast(6))
        }
        return hostname
    }

    /// base directory(hostname 하위 아님)를 반환
    /// 우선순위: 환경변수 fWarrangeCli_config → ~/Documents/finfra/fWarrange
    static func resolveDefaultBaseDirectory() -> URL {
        let defaultDir: URL
        if let envPath = ProcessInfo.processInfo.environment[envConfigKey], !envPath.isEmpty {
            defaultDir = URL(fileURLWithPath: (envPath as NSString).expandingTildeInPath)
        } else {
            defaultDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/finfra/fWarrangeData")
        }
        try? FileManager.default.createDirectory(at: defaultDir, withIntermediateDirectories: true)
        return defaultDir
    }

    // MARK: - Issue166_3: 마이그레이션 (루트 yml → hostname 폴더)

    /// 기존 루트 yml 파일을 hostname 폴더로 마이그레이션
    static func migrateRootDataIfNeeded() {
        let baseDir = resolveDefaultBaseDirectory()

        let hostname = currentHostname()
        let hostnameDir = baseDir.appendingPathComponent(hostname)
        let fm = FileManager.default

        // hostname 폴더가 이미 존재하면 스킵
        guard !fm.fileExists(atPath: hostnameDir.path) else { return }

        // 루트에 .yml 파일이 있는지 확인
        guard let contents = try? fm.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: nil),
              contents.contains(where: { $0.pathExtension == "yml" }) else { return }

        // hostname 폴더 생성
        try? fm.createDirectory(at: hostnameDir, withIntermediateDirectories: true)

        // .yml 파일 이동
        for file in contents where file.pathExtension == "yml" {
            let dest = hostnameDir.appendingPathComponent(file.lastPathComponent)
            try? fm.moveItem(at: file, to: dest)
        }

        logI("기존 데이터 마이그레이션 완료: \(hostname)/")
    }

    // MARK: - Issue166_2: _share 복사 (host 모드 최초 실행)

    /// host 모드 최초 실행 시 _share에서 데이터 복사
    static func copyShareDataIfNeeded() {
        let baseDir = resolveDefaultBaseDirectory()

        let hostname = currentHostname()
        let hostnameDir = baseDir.appendingPathComponent(hostname)
        let shareDir = baseDir.appendingPathComponent("_share")
        let fm = FileManager.default

        // hostname 폴더가 이미 존재하면 스킵
        guard !fm.fileExists(atPath: hostnameDir.path) else { return }

        // _share 폴더 확인
        guard fm.fileExists(atPath: shareDir.path) else { return }

        guard let shareFiles = try? fm.contentsOfDirectory(at: shareDir, includingPropertiesForKeys: [.contentModificationDateKey]),
              shareFiles.contains(where: { $0.pathExtension == "yml" }) else { return }

        // hostname 폴더 생성
        try? fm.createDirectory(at: hostnameDir, withIntermediateDirectories: true)

        // _share에서 .yml 파일 복사
        for file in shareFiles where file.pathExtension == "yml" {
            let dest = hostnameDir.appendingPathComponent(file.lastPathComponent)
            try? fm.copyItem(at: file, to: dest)
        }

        logI("_share에서 초기 데이터 복사 완료: \(hostname)/")
    }

    // MARK: - Issue166_4 보조: hostname 불일치 감지

    /// 다른 hostname 폴더가 존재하는지 감지
    static func detectHostnameMismatch() -> [String] {
        let baseDir = resolveDefaultBaseDirectory()

        let hostname = currentHostname()
        let hostnameDir = baseDir.appendingPathComponent(hostname)
        let fm = FileManager.default

        // 현재 hostname 폴더가 이미 존재하면 불일치 없음
        guard !fm.fileExists(atPath: hostnameDir.path) else { return [] }

        // 다른 hostname 폴더 탐색 (디렉토리이고 _share가 아닌 것)
        guard let contents = try? fm.contentsOfDirectory(at: baseDir, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }

        var otherHostnames: [String] = []
        for item in contents {
            let name = item.lastPathComponent
            guard name != "_share" && name != hostname && !name.hasPrefix(".") else { continue }
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                // 실제 yml 파일이 있는 폴더만
                if let files = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil),
                   files.contains(where: { $0.pathExtension == "yml" }) {
                    otherHostnames.append(name)
                }
            }
        }

        return otherHostnames
    }

    // MARK: - YAML 직렬화 (saveWindowsInfo.swift 호환)

    private func serializeToYAML(_ windows: [WindowInfo]) -> String {
        var yaml = ""
        for w in windows {
            let safeApp = w.app.replacingOccurrences(of: "\"", with: "\\\"")
            let safeWindow = w.window.replacingOccurrences(of: "\"", with: "\\\"")
            yaml += """
            - app: "\(safeApp)"
              window: "\(safeWindow)"
              layer: \(w.layer)
              id: \(w.id)
              pos:
                x: \(w.pos.x)
                y: \(w.pos.y)
              size:
                width: \(w.size.width)
                height: \(w.size.height)

            """
        }
        return yaml
    }

    // MARK: - YAML 파싱 (setWindows.swift 호환)

    private func parseYAML(_ content: String) -> [WindowInfo] {
        var results: [WindowInfo] = []
        var current: (app: String, window: String, id: Int, layer: Int, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat)?

        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("- app:") {
                if let c = current {
                    results.append(WindowInfo(
                        id: c.id, app: c.app, window: c.window, layer: c.layer,
                        pos: WindowPosition(x: c.x, y: c.y),
                        size: WindowSize(width: c.width, height: c.height)
                    ))
                }
                let val = parseStringValue(String(trimmed.dropFirst(6)))
                current = (app: val, window: "", id: 0, layer: 0, x: 0, y: 0, width: 0, height: 0)
            } else if trimmed.hasPrefix("window:") {
                current?.window = parseStringValue(String(trimmed.dropFirst(7)))
            } else if trimmed.hasPrefix("layer:") {
                current?.layer = Int(trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)) ?? 0
            } else if trimmed.hasPrefix("id:") {
                current?.id = Int(trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)) ?? 0
            } else if trimmed.hasPrefix("x:") {
                current?.x = CGFloat(Double(trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)) ?? 0)
            } else if trimmed.hasPrefix("y:") {
                current?.y = CGFloat(Double(trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)) ?? 0)
            } else if trimmed.hasPrefix("width:") {
                current?.width = CGFloat(Double(trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)) ?? 0)
            } else if trimmed.hasPrefix("height:") {
                current?.height = CGFloat(Double(trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces)) ?? 0)
            }
        }

        if let c = current {
            results.append(WindowInfo(
                id: c.id, app: c.app, window: c.window, layer: c.layer,
                pos: WindowPosition(x: c.x, y: c.y),
                size: WindowSize(width: c.width, height: c.height)
            ))
        }

        return results
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

    func save(name: String, windows: [WindowInfo]) throws {
        try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        let fileURL = dataDirectory.appendingPathComponent("\(name).yml")
        let yaml = serializeToYAML(windows)
        try yaml.write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func load(name: String) throws -> Layout {
        let fileURL = dataDirectory.appendingPathComponent("\(name).yml")
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let windows = parseYAML(content)
        let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileDate = attrs[.modificationDate] as? Date ?? Date()
        return Layout(name: name, windows: windows, fileDate: fileDate)
    }

    func listLayouts() throws -> [Layout] {
        guard FileManager.default.fileExists(atPath: dataDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: dataDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return files
            .filter { $0.pathExtension == "yml" }
            .compactMap { fileURL -> Layout? in
                let name = fileURL.deletingPathExtension().lastPathComponent
                return try? load(name: name)
            }
            .sorted { $0.fileDate > $1.fileDate }
    }

    func listLayoutMetadata() throws -> [LayoutMetadata] {
        guard FileManager.default.fileExists(atPath: dataDirectory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(
            at: dataDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        )
        return files
            .filter { $0.pathExtension == "yml" }
            .compactMap { fileURL -> LayoutMetadata? in
                let name = fileURL.deletingPathExtension().lastPathComponent
                let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                let fileDate = attrs?[.modificationDate] as? Date ?? Date()
                // "- app:" 패턴 카운팅으로 YAML 전체 파싱 회피
                let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
                let windowCount = content.components(separatedBy: "\n")
                    .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("- app:") }
                    .count
                return LayoutMetadata(name: name, windowCount: windowCount, fileDate: fileDate)
            }
            .sorted { $0.fileDate > $1.fileDate }
    }

    func delete(name: String) throws {
        let fileURL = dataDirectory.appendingPathComponent("\(name).yml")
        try FileManager.default.removeItem(at: fileURL)
    }

    func deleteAll() throws {
        guard FileManager.default.fileExists(atPath: dataDirectory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: dataDirectory, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "yml" {
            try FileManager.default.removeItem(at: file)
        }
    }

    func rename(oldName: String, newName: String) throws {
        let oldURL = dataDirectory.appendingPathComponent("\(oldName).yml")
        let newURL = dataDirectory.appendingPathComponent("\(newName).yml")
        try FileManager.default.moveItem(at: oldURL, to: newURL)
    }
}
