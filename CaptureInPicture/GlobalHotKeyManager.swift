//
//  GlobalHotKeyManager.swift
//  CaptureInPicture
//
//  Created by Codex on 3/20/26.
//

import Carbon
import Foundation

final class GlobalHotKeyManager {
    private static let signature = OSType(0x43495048) // "CIPH"
    private static let eventHandler: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else {
            return noErr
        }

        let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        return manager.handleHotKeyEvent(event)
    }

    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var actions: [UInt32: @MainActor () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?

    init() {
        installEventHandler()
    }

    deinit {
        cleanup()
    }

    func register(id: UInt32, keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        unregister(id: id)

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, let hotKeyRef else {
            return
        }

        hotKeyRefs[id] = hotKeyRef
        actions[id] = action
    }

    func unregister(id: UInt32) {
        if let hotKeyRef = hotKeyRefs.removeValue(forKey: id) {
            UnregisterEventHotKey(hotKeyRef)
        }

        actions[id] = nil
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func cleanup() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }

        hotKeyRefs.removeAll()
        actions.removeAll()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    private func handleHotKeyEvent(_ event: EventRef) -> OSStatus {
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

        guard status == noErr, let action = actions[hotKeyID.id] else {
            return noErr
        }

        Task { @MainActor in
            action()
        }

        return noErr
    }
}
