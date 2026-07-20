//
//  Models.swift
//  SwiftVN
//

import Foundation

struct Game: Identifiable {
    let id = UUID()
    let dirName: String
    let title: String
    let author: String?
    let iconPath: String?
    let previewPath: String?
    let directoryURL: URL
    var saves: [SaveSlot] = []

    init?(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.dirName = directoryURL.lastPathComponent

        let infoURL = directoryURL.appendingPathComponent("info.txt")
        guard let infoContent = try? String(contentsOf: infoURL, encoding: .utf8) else {
            return nil
        }

        var parsedTitle: String?
        var parsedAuthor: String?
        for line in infoContent.components(separatedBy: .newlines) {
            if let colonRange = line.range(of: ":") {
                let key = String(line[..<colonRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if key == "title"       { parsedTitle  = value }
                else if key == "author" { parsedAuthor = value }
            } else if let eqRange = line.range(of: "=") {
                let key = String(line[..<eqRange.lowerBound])
                    .trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(line[eqRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                if key == "title"  && parsedTitle  == nil { parsedTitle  = value }
                if key == "author" && parsedAuthor == nil { parsedAuthor = value }
            }
        }

        self.title  = parsedTitle ?? dirName
        self.author = parsedAuthor

        let iconURL = directoryURL.appendingPathComponent("icon.png")
        self.iconPath = FileManager.default.fileExists(atPath: iconURL.path) ? iconURL.path : nil

        let previewURL = directoryURL.appendingPathComponent("dialog_preview.png")
        if FileManager.default.fileExists(atPath: previewURL.path) {
            self.previewPath = previewURL.path
        } else {
            let thumbURL = directoryURL.appendingPathComponent("thumbnail.png")
            self.previewPath = FileManager.default.fileExists(atPath: thumbURL.path)
                ? thumbURL.path : nil
        }

        self.saves = Game.scanSaves(in: directoryURL)
    }

    /// Scans save1.json … save30.json.
    /// Screenshot is stored at save1.json.png (same path + ".png").
    static func scanSaves(in dir: URL) -> [SaveSlot] {
        (1...30).map { i in
            let saveURL = dir.appendingPathComponent("save\(i).json")
            guard FileManager.default.fileExists(atPath: saveURL.path) else {
                return SaveSlot(number: i, exists: false,
                                timestamp: nil, lastLine: nil, screenshotPath: nil)
            }
            var timestamp: Date?
            var lastLine: String?
            if let data = try? Data(contentsOf: saveURL),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let ts = json["timestamp"] as? Double {
                    timestamp = Date(timeIntervalSince1970: ts)
                }
                lastLine = json["last_line"] as? String
            }
            // Screenshot: same path as the JSON file + ".png"
            let screenshotURL = saveURL.appendingPathExtension("png")
            let screenshotPath = FileManager.default.fileExists(atPath: screenshotURL.path)
                ? screenshotURL.path : nil
            return SaveSlot(number: i, exists: true,
                            timestamp: timestamp, lastLine: lastLine,
                            screenshotPath: screenshotPath)
        }
    }
}

struct SaveSlot: Identifiable {
    let id = UUID()
    let number: Int
    let exists: Bool
    let timestamp: Date?
    let lastLine: String?
    let screenshotPath: String?
}