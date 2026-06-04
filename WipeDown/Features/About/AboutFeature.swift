//
//  AboutFeature.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import Foundation

enum AboutFeature {
    struct State {}

    enum Action {
        case openRepositoryTapped
        case openSupportTapped
    }

    static func reducer(
        workspace: NSWorkspace = .shared
    ) -> (inout State, Action) -> Effect<Action> {
        { _, action in
            switch action {
            case .openRepositoryTapped:
                return .fireAndForget {
                    workspace.open(AppLinks.repository)
                }

            case .openSupportTapped:
                return .fireAndForget {
                    workspace.open(AppLinks.support)
                }
            }
        }
    }
}

private enum AppLinks {
    static let repository = URL(string: "https://github.com/tomlatyn/WipeDown")!
    static let support = URL(string: "https://buymeacoffee.com/tomlatyn")!
}
