//
//  PreferencesFeature.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import Foundation

enum PreferencesScreen: String, CaseIterable, Identifiable {
    case lock
    case settings
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lock: return String(localized: .screenTitleLock)
        case .settings: return String(localized: .screenTitleSettings)
        case .about: return String(localized: .screenTitleAbout)
        }
    }

    var systemImage: String {
        switch self {
        case .lock: return "lock.shield"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }
}

enum PreferencesFeature {
    struct State {
        var selectedScreen: PreferencesScreen = .lock
    }

    enum Action {
        case setSelectedScreen(PreferencesScreen)
    }

    static func reducer() -> (inout State, Action) -> Effect<Action> {
        { state, action in
            switch action {
            case let .setSelectedScreen(screen):
                state.selectedScreen = screen
                return .none
            }
        }
    }
}
