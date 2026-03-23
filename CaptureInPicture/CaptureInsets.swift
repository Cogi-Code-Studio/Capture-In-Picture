//
//  CaptureInsets.swift
//  CaptureInPicture
//
//  Created by Codex on 3/20/26.
//

import CoreGraphics

struct CaptureInsets: Equatable {
    var top: CGFloat
    var left: CGFloat
    var bottom: CGFloat
    var right: CGFloat

    static let zero = CaptureInsets()

    init(
        top: CGFloat = 0,
        left: CGFloat = 0,
        bottom: CGFloat = 0,
        right: CGFloat = 0
    ) {
        self.top = max(top, 0)
        self.left = max(left, 0)
        self.bottom = max(bottom, 0)
        self.right = max(right, 0)
    }

    var isZero: Bool {
        top == 0 && left == 0 && bottom == 0 && right == 0
    }
}
