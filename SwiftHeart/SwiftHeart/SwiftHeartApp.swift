//
//  SwiftHeartApp.swift
//  SwiftHeart
//

import SwiftUI

@main
struct SwiftHeartApp: App {

    init() {
        // iOS / iPadOS only shows an app's Documents folder in the Files app
        // once at least one file exists inside it.  Create a small placeholder
        // on first launch so the folder is immediately visible and the user
        // can drop core.love into it.
        createDocumentsPlaceholderIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    // MARK: - Private

    private func createDocumentsPlaceholderIfNeeded() {
        guard let docs = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first
        else { return }

        let placeholder = docs.appendingPathComponent("README.txt")
        guard !FileManager.default.fileExists(atPath: placeholder.path) else { return }

        // Write an empty file so the Documents folder becomes visible in Files.
        try? Data().write(to: placeholder)
    }
}
