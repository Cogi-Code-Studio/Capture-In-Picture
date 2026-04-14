//
//  SaveFolderStore.swift
//  CaptureInPicture
//
//  Created by Codex on 3/20/26.
//

import AppKit
import Foundation

enum SaveFolderError: LocalizedError {
    case bookmarkRestoreFailed
    case folderSelectionCancelled
    case folderAccessDenied

    var errorDescription: String? {
        switch self {
        case .bookmarkRestoreFailed:
            return "The saved folder could not be restored. Choose the folder again."
        case .folderSelectionCancelled:
            return "Folder selection was cancelled."
        case .folderAccessDenied:
            return "The app could not access the selected folder."
        }
    }
}

@MainActor
final class SaveFolderStore {
    private let bookmarkKey = "selectedOutputFolderBookmark"
    private var activeFolderURL: URL?

    func restoreFolder() throws -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }

        var isStale = false

        do {
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            guard folderURL.startAccessingSecurityScopedResource() else {
                throw SaveFolderError.folderAccessDenied
            }

            stopAccessingActiveFolder()
            activeFolderURL = folderURL

            if isStale {
                try saveBookmark(for: folderURL)
            }

            return folderURL
        } catch {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            stopAccessingActiveFolder()
            throw SaveFolderError.bookmarkRestoreFailed
        }
    }

    func chooseFolder() throws -> URL {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if let activeFolderURL {
            panel.directoryURL = activeFolderURL
        } else {
            panel.directoryURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
        }

        guard panel.runModal() == .OK, let folderURL = panel.url else {
            throw SaveFolderError.folderSelectionCancelled
        }

        guard folderURL.startAccessingSecurityScopedResource() else {
            throw SaveFolderError.folderAccessDenied
        }

        stopAccessingActiveFolder()
        activeFolderURL = folderURL
        try saveBookmark(for: folderURL)
        return folderURL
    }

    func clearFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        stopAccessingActiveFolder()
    }

    private func saveBookmark(for folderURL: URL) throws {
        let bookmarkData = try folderURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }

    private func stopAccessingActiveFolder() {
        activeFolderURL?.stopAccessingSecurityScopedResource()
        activeFolderURL = nil
    }
}
