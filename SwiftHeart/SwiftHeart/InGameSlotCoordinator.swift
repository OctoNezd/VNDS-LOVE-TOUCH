//
//  InGameSlotCoordinator.swift
//  SwiftHeart
//
//  A singleton ObservableObject that bridges the ObjC/Lua side (which runs on
//  the main thread inside a nested CFRunLoop) with SwiftUI sheet presentation.
//

import Combine
import SwiftUI
import UIKit

// MARK: - SlotSheetDelegate

/// Delegate that fires deliver(nil) when the user swipe-dismisses the sheet.
final class SlotSheetDelegate: NSObject, UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // Only fire if not already done (i.e. user swiped down without picking)
        if !InGameSlotCoordinator.shared.isDone {
            InGameSlotCoordinator.shared.isDone = true
            InGameSlotCoordinator.shared.pendingResult = nil
        }
    }
}

// MARK: - InGameSlotCoordinator

final class InGameSlotCoordinator: ObservableObject {

    static let shared = InGameSlotCoordinator()
    private init() {}

    // Keeps the delegate alive for the lifetime of the presented sheet.
    var sheetDelegate: SlotSheetDelegate?

    // MARK: Published state (SwiftUI observes these)

    /// Non-nil while a sheet should be shown.
    @Published var request: SlotRequest? = nil

    // MARK: Internal signalling (used by the nested-runloop bridge)

    /// Set by the sheet when the user makes a choice; read by the bridge.
    var pendingResult: Int? = nil   // chosen slot number (1-based), or nil = cancel
    var isDone: Bool = false

    // MARK: - Request type

    struct SlotRequest: Identifiable {
        let id = UUID()
        let directoryURL: URL
        let mode: SlotMode          // .save or .load
        let gameTitle: String
    }

    enum SlotMode { case save, load }

    // MARK: - Called from SlotBridge.swift (non-blocking)

    /// Present the sheet and return immediately.  Poll isDone / pendingResult
    /// from the game loop via swiftheart_poll_slot_result().
    func showSheet(dirPath: String, isSave: Bool) {
        let dirURL = URL(fileURLWithPath: dirPath)

        var gameTitle = dirURL.lastPathComponent
        let infoURL = dirURL.appendingPathComponent("info.txt")
        if let infoContent = try? String(contentsOf: infoURL, encoding: .utf8) {
            for line in infoContent.components(separatedBy: .newlines) {
                if let r = line.range(of: ":") {
                    let key = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces).lowercased()
                    let val = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if key == "title" { gameTitle = val; break }
                }
            }
        }

        pendingResult = nil
        isDone = false

        // SDL blocks the main thread, so DispatchQueue.main.async items never
        // fire while the game is running.  Instead we present the sheet
        // directly via UIKit — UIKit presentation is driven by the run loop
        // (CADisplayLink), which SDL keeps pumping.
        let req = SlotRequest(directoryURL: dirURL,
                              mode: isSave ? .save : .load,
                              gameTitle: gameTitle)

        // Find the topmost presented view controller.
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let rootVC = keyWindow.rootViewController else { return }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let sheetView = InGameSlotSheet(request: req)
        let hostingVC = UIHostingController(rootView: sheetView)
        hostingVC.modalPresentationStyle = .pageSheet
        // Wire up the delegate so swipe-dismiss is treated as cancel.
        let delegate = SlotSheetDelegate()
        sheetDelegate = delegate
        hostingVC.presentationController?.delegate = delegate
        topVC.present(hostingVC, animated: true) {
            // presentationController is only available after presentation begins.
            hostingVC.presentationController?.delegate = delegate
        }
    }

    /// Reset state after the C++ side has consumed the result.
    func reset() {
        pendingResult = nil
        isDone = false
    }

    // MARK: - Called by the sheet when the user picks a slot or cancels

    func deliver(slot: Int?) {
        pendingResult = slot
        isDone = true
        request = nil   // dismiss SwiftUI-driven sheet (game picker path)
        // Also dismiss any UIHostingController presented directly via UIKit
        // (in-game path — SDL blocks the main dispatch queue so we use UIKit).
        guard let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
              let rootVC = keyWindow.rootViewController else { return }
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        if topVC !== rootVC {
            topVC.dismiss(animated: true)
        }
    }
}