//
//  LoveGameView.swift
//  SwiftVN
//

import SwiftUI

struct LoveGameView: UIViewControllerRepresentable {
    let gamePath: String
    var extraArgs: [String] = []
    let onQuit: () -> Void

    func makeUIViewController(context: Context) -> LoveViewController {
        LoveViewController(gamePath: gamePath, extraArgs: extraArgs, onQuit: onQuit)
    }

    func updateUIViewController(_ uiViewController: LoveViewController, context: Context) {}
}