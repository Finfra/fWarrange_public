import AppKit
import Carbon

// MARK: - 단축키 액션 열거형

enum HotKeyAction {
    case save
    case restoreDefault
    case restoreLast
    case showMainWindow
    case showSettings
}

// MARK: - HotKeyService 프로토콜

protocol HotKeyService {
    func register(settings: AppSettings, handler: @escaping (HotKeyAction) -> Void)
    func unregister()
}

// MARK: - CarbonHotKeyService 구현체

/// Carbon RegisterEventHotKey 기반 글로벌 단축키 서비스
/// NSEvent.addGlobalMonitorForEvents는 이벤트 소비 불가 → 비프음 발생
/// Carbon API는 시스템 레벨에서 키 이벤트를 소비하여 비프음 방지
final class CarbonHotKeyService: HotKeyService {
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var eventHandlerRef: EventHandlerRef?
    private var localMonitor: Any?

    /// 등록된 핫키 ID → 액션 매핑
    private static var registeredActions: [UInt32: HotKeyAction] = [:]
    private static var currentHandler: ((HotKeyAction) -> Void)?

    /// 4문자 시그니처 ('fWar')
    private static let hotKeySignature: OSType = {
        let chars: [UInt8] = [0x66, 0x57, 0x61, 0x72] // fWar
        return OSType(chars[0]) << 24 | OSType(chars[1]) << 16 | OSType(chars[2]) << 8 | OSType(chars[3])
    }()

    func register(settings: AppSettings, handler: @escaping (HotKeyAction) -> Void) {
        unregister()

        Self.currentHandler = handler
        Self.registeredActions.removeAll()

        let shortcuts: [(KeyboardShortcutConfig?, HotKeyAction)] = [
            (settings.saveShortcut, .save),
            (settings.restoreDefaultShortcut, .restoreDefault),
            (settings.restoreLastShortcut, .restoreLast),
            (settings.showMainWindowShortcut, .showMainWindow),
            (settings.showSettingsShortcut, .showSettings)
        ]

        let validShortcuts = shortcuts.compactMap { (config, action) -> (KeyboardShortcutConfig, HotKeyAction)? in
            guard let config else { return nil }
            return (config, action)
        }

        guard !validShortcuts.isEmpty else {
            logD("HotKeyService: 등록된 단축키 없음 - 모니터링 건너뜀")
            return
        }

        // Carbon 이벤트 핸들러 설치
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerUPP: EventHandlerUPP = { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard status == noErr else { return status }

            if let action = CarbonHotKeyService.registeredActions[hotKeyID.id] {
                logD("HotKeyService: 단축키 트리거 (id=\(hotKeyID.id))")
                DispatchQueue.main.async {
                    CarbonHotKeyService.currentHandler?(action)
                }
                return noErr
            }
            return OSStatus(eventNotHandledErr)
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerUPP,
            1,
            &eventType,
            nil,
            &eventHandlerRef
        )

        // 각 단축키 등록
        for (index, (config, action)) in validShortcuts.enumerated() {
            let hotKeyID = EventHotKeyID(signature: Self.hotKeySignature, id: UInt32(index + 1))
            let carbonModifiers = Self.toCarbonModifiers(nsFlags: NSEvent.ModifierFlags(rawValue: config.modifierFlags))

            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(config.keyCode),
                carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )

            if status == noErr {
                hotKeyRefs.append(ref)
                Self.registeredActions[UInt32(index + 1)] = action
                logD("HotKeyService: '\(action)' 등록 완료 (\(config.displayString))")
            } else {
                logW("HotKeyService: '\(action)' 등록 실패 (status=\(status), \(config.displayString))")
            }
        }

        // 로컬 모니터: fWarrangeCli 포커스 시 비프음 방지 보조
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let eventMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            for (config, _) in validShortcuts {
                if event.keyCode == config.keyCode {
                    let configMods = NSEvent.ModifierFlags(rawValue: config.modifierFlags)
                        .intersection([.command, .option, .shift, .control])
                    if eventMods == configMods {
                        return nil // 이벤트 소비 (Carbon 핸들러가 처리)
                    }
                }
            }
            return event
        }

        logD("HotKeyService: Carbon 핫키 \(validShortcuts.count)개 + 로컬 모니터 등록 완료")
    }

    func unregister() {
        for ref in hotKeyRefs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }

        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }

        Self.registeredActions.removeAll()
        Self.currentHandler = nil

        logD("HotKeyService: 전체 해제 완료")
    }

    /// NSEvent.ModifierFlags → Carbon modifier mask 변환
    private static func toCarbonModifiers(nsFlags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if nsFlags.contains(.command) { carbon |= UInt32(cmdKey) }
        if nsFlags.contains(.option)  { carbon |= UInt32(optionKey) }
        if nsFlags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if nsFlags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}
