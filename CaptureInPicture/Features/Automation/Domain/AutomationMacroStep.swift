//
//  AutomationMacro.swift
//  CaptureInPicture
//
//  Created by Codex on 3/29/26.
//

import Foundation

struct AutomationMacroStep: Identifiable, Codable, Equatable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case up
        case down
        case left
        case right
        case wait
        case capture

        var id: String { rawValue }

        var title: String {
            switch self {
            case .up:
                return "Up Arrow"
            case .down:
                return "Down Arrow"
            case .left:
                return "Left Arrow"
            case .right:
                return "Right Arrow"
            case .wait:
                return "Wait"
            case .capture:
                return "Capture"
            }
        }

        var shortTitle: String {
            switch self {
            case .up:
                return "Up"
            case .down:
                return "Down"
            case .left:
                return "Left"
            case .right:
                return "Right"
            case .wait:
                return "Wait"
            case .capture:
                return "Capture"
            }
        }

        var systemImage: String {
            switch self {
            case .up:
                return "arrow.up.circle"
            case .down:
                return "arrow.down.circle"
            case .left:
                return "arrow.left.circle"
            case .right:
                return "arrow.right.circle"
            case .wait:
                return "timer"
            case .capture:
                return "camera.aperture"
            }
        }

        var detailText: String {
            switch self {
            case .up:
                return "Send Up Arrow to the focused app."
            case .down:
                return "Send Down Arrow to the focused app."
            case .left:
                return "Send Left Arrow to the focused app."
            case .right:
                return "Send Right Arrow to the focused app."
            case .wait:
                return "Pause before moving to the next step."
            case .capture:
                return "Save the currently selected window."
            }
        }
    }

    static let defaultWaitDuration = 0.5
    static let maxWaitDuration = 600.0
    static let defaultFlow: [AutomationMacroStep] = [
        AutomationMacroStep(kind: .right),
        AutomationMacroStep(kind: .wait, waitDuration: defaultWaitDuration),
        AutomationMacroStep(kind: .capture)
    ]

    var id: UUID
    var kind: Kind
    var waitDuration: Double?

    init(id: UUID = UUID(), kind: Kind, waitDuration: Double? = nil) {
        self.id = id
        self.kind = kind

        if kind == .wait {
            let resolvedWaitDuration = waitDuration ?? Self.defaultWaitDuration
            self.waitDuration = min(max(resolvedWaitDuration, 0.1), Self.maxWaitDuration)
        } else {
            self.waitDuration = nil
        }
    }

    var isCapture: Bool {
        kind == .capture
    }

    var isWait: Bool {
        kind == .wait
    }

    var resolvedWaitDuration: Double {
        min(max(waitDuration ?? Self.defaultWaitDuration, 0.1), Self.maxWaitDuration)
    }

    var shortSummary: String {
        guard isWait else {
            return kind.shortTitle
        }

        return "Wait \(formattedWaitDuration)"
    }

    var detailSummary: String {
        guard isWait else {
            return kind.detailText
        }

        return "Pause for \(formattedWaitDuration) before continuing."
    }

    private var formattedWaitDuration: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return "\(formatter.string(from: NSNumber(value: resolvedWaitDuration)) ?? "0.5")s"
    }
}
