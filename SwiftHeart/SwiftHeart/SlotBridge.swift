//
//  SlotBridge.swift
//  SwiftHeart
//
//  C-callable bridge between LoveViewController.mm and InGameSlotCoordinator.
//
//  Two functions are exported:
//
//    swiftheart_request_slot(dirPath, isSave)
//      Presents the SwiftUI slot-picker sheet and returns immediately.
//      The game loop must poll swiftheart_poll_slot_result() each frame.
//
//    swiftheart_poll_slot_result(outSlot) -> Bool
//      Returns true when the user has made a choice (or cancelled).
//      outSlot is set to the chosen 1-based slot number, or 0 if cancelled.
//      Returns false while the sheet is still open.
//

import Foundation

/// Present the in-game slot picker sheet (non-blocking).
@_silgen_name("swiftheart_request_slot")
public func swiftheart_request_slot(_ dirPath: UnsafePointer<CChar>,
                                    _ isSave: Bool) {
    let path = String(cString: dirPath)
    InGameSlotCoordinator.shared.showSheet(dirPath: path, isSave: isSave)
}

/// Poll for the result of a previously requested slot dialog.
/// Returns true when done (result written to *outSlot: 1-based slot, or 0 = cancel).
/// Returns false while the sheet is still open.
@_silgen_name("swiftheart_poll_slot_result")
public func swiftheart_poll_slot_result(_ outSlot: UnsafeMutablePointer<Int32>) -> Bool {
    guard InGameSlotCoordinator.shared.isDone else { return false }
    outSlot.pointee = Int32(InGameSlotCoordinator.shared.pendingResult ?? 0)
    InGameSlotCoordinator.shared.reset()
    return true
}
