//
//  WindowInfo.swift
//  CaptureInPicture
//
//  Created by Codex on 3/20/26.
//

import CoreGraphics
import ScreenCaptureKit

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let title: String
    let appName: String
    let sizeDescription: String
    let isActive: Bool
    let rawWindow: SCWindow

    var processID: pid_t? {
        rawWindow.owningApplication?.processID
    }

    init(window: SCWindow) {
        id = window.windowID
        title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Untitled Window"
        appName = window.owningApplication?.applicationName.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unknown App"
        sizeDescription = "\(Int(window.frame.width)) x \(Int(window.frame.height))"
        isActive = window.isActive
        rawWindow = window
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
