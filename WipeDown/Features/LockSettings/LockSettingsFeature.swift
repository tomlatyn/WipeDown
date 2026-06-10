//
//  LockSettingsFeature.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import Foundation

enum UnlockCombination: String, CaseIterable, Identifiable {
    case escReturn = "Esc + Return"
    case shifts = "Left Shift + Right Shift"
    case spaceEsc = "Space + Esc"

    var id: String { rawValue }
    
    var displayString: String {
        switch self {
        case .escReturn: return String(localized: .combinationEscReturn)
        case .shifts: return String(localized: .combinationShifts)
        case .spaceEsc: return String(localized: .combinationSpaceEsc)
        }
    }

    var keyCodes: (UInt16, UInt16) {
        switch self {
        case .escReturn: return (53, 36)
        case .shifts: return (56, 60)
        case .spaceEsc: return (49, 53)
        }
    }
}

enum LockSettingsFeature {
    struct TestOverlayConfiguration {
        let overlayOpacity: Double
    }

    struct State {
        static let defaultScreenBrightness = 0.1

        var dimScreen: Bool
        var lockKeyboard: Bool
        var holdDuration: Double
        var safetyDuration: Double
        var selectedCombination: UnlockCombination
        var isTestingScreenDim = false

        init(defaults: UserDefaults = .standard) {
            dimScreen = defaults.bool(forKey: AppDefaults.Keys.dimScreen)
            lockKeyboard = defaults.bool(forKey: AppDefaults.Keys.lockKeyboard)
            holdDuration = defaults.double(forKey: AppDefaults.Keys.holdDuration)
            safetyDuration = Self.clampedSafetyDuration(defaults.double(forKey: AppDefaults.Keys.safetyDuration))

            if let savedCombination = defaults.string(forKey: AppDefaults.Keys.unlockCombination),
               let combination = UnlockCombination(rawValue: savedCombination) {
                selectedCombination = combination
            } else {
                selectedCombination = .shifts
            }
        }

        var holdDurationText: String {
            holdDuration == 0.0
                ? String(localized: .holdDurationInstant)
                : String(localized: .holdDurationSecondsFormat(String(format: "%.1f", holdDuration)))
        }

        var unlockPrompt: String {
            if holdDuration == 0.0 {
                return String(localized: .unlockPromptPressFormat(selectedCombination.displayString))
            } else {
                return String(localized: .unlockPromptHoldFormat(selectedCombination.displayString))
            }
        }

        var overlayOpacity: Double {
            dimScreen ? (1.0 - Self.defaultScreenBrightness) : 1.0
        }

        var safetyDurationText: String {
            Self.formattedDuration(safetyDuration)
        }

        static func clampedSafetyDuration(_ value: Double) -> Double {
            min(300.0, max(30.0, value))
        }

        static func formattedDuration(_ seconds: Double) -> String {
            let totalSeconds = Int(seconds.rounded())
            let minutes = totalSeconds / 60
            let remainingSeconds = totalSeconds % 60

            if minutes == 0 {
                return String(localized: .durationSecondsFormat(remainingSeconds))
            }

            if remainingSeconds == 0 {
                return String(localized: .durationMinutesFormat(minutes))
            }

            return String(localized: .durationMinutesSecondsFormat(minutes, remainingSeconds))
        }
    }

    enum Action {
        case setDimScreen(Bool)
        case setLockKeyboard(Bool)
        case setSelectedCombination(UnlockCombination)
        case setHoldDuration(Double)
        case setSafetyDuration(Double)
        case testScreenDimTapped
        case testScreenDimFinished
        case testKeyboardBlockTapped
    }

    static func reducer(
        lockManager: LockManager = .shared,
        defaults: UserDefaults = .standard
    ) -> (inout State, Action) -> Effect<Action> {
        { state, action in
            switch action {
            case let .setDimScreen(value):
                state.dimScreen = value
                defaults.set(value, forKey: AppDefaults.Keys.dimScreen)
                return .none

            case let .setLockKeyboard(value):
                state.lockKeyboard = value
                defaults.set(value, forKey: AppDefaults.Keys.lockKeyboard)
                return .none

            case let .setSelectedCombination(value):
                state.selectedCombination = value
                defaults.set(value.rawValue, forKey: AppDefaults.Keys.unlockCombination)
                return .none

            case let .setHoldDuration(value):
                state.holdDuration = value
                defaults.set(value, forKey: AppDefaults.Keys.holdDuration)
                return .none

            case let .setSafetyDuration(value):
                let clamped = State.clampedSafetyDuration(value)
                state.safetyDuration = clamped
                defaults.set(clamped, forKey: AppDefaults.Keys.safetyDuration)
                return .none

            case .testScreenDimTapped:
                guard !state.isTestingScreenDim else { return .none }
                state.isTestingScreenDim = true
                let configuration = TestOverlayConfiguration(
                    overlayOpacity: state.overlayOpacity
                )
                return Effect { send in
                    lockManager.testScreenDim(configuration: configuration) {
                        send(.testScreenDimFinished)
                    }
                }

            case .testScreenDimFinished:
                state.isTestingScreenDim = false
                return .none

            case .testKeyboardBlockTapped:
                return .fireAndForget {
                    lockManager.testKeyboardBlock()
                }
            }
        }
    }
}


