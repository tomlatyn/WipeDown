//
//  LockSettingsView.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import SwiftUI

struct LockSettingsView: View {
    @ObservedObject var store: WipeDownStore

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            PreferencesSection(title: String(localized: .lockBehavior)) {
                GlassCard {
                    RowContainer {
                        ToggleRow(
                            title: String(localized: .dimDisplay),
                            caption: String(localized: .dimDisplayCaption),
                            isOn: store.binding(
                                get: { $0.lockSettings.dimScreen },
                                send: { .lockSettings(.setDimScreen($0)) }
                            )
                        )
                    }

                    if store.state.lockSettings.dimScreen {
                        RowDivider()

                        RowContainer {
                            ButtonRow(
                                title: String(localized: .testDisplayDimming),
                                caption: String(localized: .testDisplayDimmingCaption),
                                isDisabled: store.state.lockSettings.isTestingScreenDim
                            ) {
                                store.send(.lockSettings(.testScreenDimTapped))
                            }
                        }
                    }

                    RowDivider()

                    RowContainer {
                        ToggleRow(
                            title: String(localized: .lockKeyboard),
                            caption: String(localized: .lockKeyboardCaption),
                            isOn: store.binding(
                                get: { $0.lockSettings.lockKeyboard },
                                send: { .lockSettings(.setLockKeyboard($0)) }
                            )
                        )
                    }

                    if store.state.lockSettings.lockKeyboard {
                        RowDivider()

                        RowContainer {
                            ButtonRow(
                                title: String(localized: .testKeyboardLock),
                                caption: String(localized: .testKeyboardLockCaption)
                            ) {
                                store.send(.lockSettings(.testKeyboardBlockTapped))
                            }
                        }
                    }

                    RowDivider()

                    RowContainer {
                        ToggleRow(
                            title: String(localized: .keyboardBacklight),
                            caption: String(localized: .keyboardBacklightCaption),
                            isOn: store.binding(
                                get: { $0.lockSettings.adjustKeyboardBacklight },
                                send: { .lockSettings(.setAdjustKeyboardBacklight($0)) }
                            )
                        )
                    }

                    if store.state.lockSettings.adjustKeyboardBacklight {
                        RowDivider()

                        RowContainer {
                            SliderRow(
                                title: String(localized: .keyboardBrightness),
                                valueText: store.state.lockSettings.keyboardBrightnessText,
                                caption: String(localized: .keyboardBrightnessCaption)
                            ) {
                                Slider(
                                    value: store.binding(
                                        get: { $0.lockSettings.keyboardBrightness },
                                        send: { .lockSettings(.setKeyboardBrightness($0)) }
                                    ),
                                    in: 0.0...1.0,
                                    step: 0.1
                                )
                                .onChange(of: store.state.lockSettings.keyboardBrightness) { _ in
                                    performSliderHaptic()
                                }
                            }
                        }

                        RowDivider()

                        RowContainer {
                            ButtonRow(
                                title: String(localized: .testKeyboardBacklight),
                                caption: String(localized: .testKeyboardBacklightCaption),
                                isDisabled: store.state.lockSettings.isTestingKeyboardBacklight
                            ) {
                                store.send(.lockSettings(.testKeyboardBacklightTapped))
                            }
                        }
                    }
                }
            }

            PreferencesSection(title: String(localized: .unlockAndSafety)) {
                GlassCard {
                    RowContainer {
                        HStack(alignment: .center, spacing: 16) {
                            RowText(
                                title: String(localized: .unlockShortcut),
                                caption: String(localized: .unlockShortcutCaption)
                            )

                            Spacer(minLength: 16)

                            Picker(
                                "",
                                selection: store.binding(
                                    get: { $0.lockSettings.selectedCombination },
                                    send: { .lockSettings(.setSelectedCombination($0)) }
                                )
                            ) {
                                ForEach(UnlockCombination.allCases) { combo in
                                    Text(combo.displayString).tag(combo)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(width: 176)
                        }
                    }

                    RowDivider()

                    RowContainer {
                        SliderRow(
                            title: String(localized: .holdDuration),
                            valueText: store.state.lockSettings.holdDurationText,
                            caption: String(localized: .holdDurationCaption)
                        ) {
                            Slider(
                                value: store.binding(
                                    get: { $0.lockSettings.holdDuration },
                                    send: { .lockSettings(.setHoldDuration($0)) }
                                ),
                                in: 0.0...5.0,
                                step: 0.5
                            )
                            .onChange(of: store.state.lockSettings.holdDuration) { _ in
                                performSliderHaptic()
                            }
                        }
                    }

                    RowDivider()

                    RowContainer {
                        SliderRow(
                            title: String(localized: .safetyTimer),
                            valueText: store.state.lockSettings.safetyDurationText,
                            caption: String(localized: .safetyTimerCaption)
                        ) {
                            Slider(
                                value: store.binding(
                                    get: { $0.lockSettings.safetyDuration },
                                    send: { .lockSettings(.setSafetyDuration($0)) }
                                ),
                                in: 30.0...300.0,
                                step: 30.0
                            )
                            .onChange(of: store.state.lockSettings.safetyDuration) { _ in
                                performSliderHaptic()
                            }
                        }
                    }
                }
            }
        }
    }

    private func performSliderHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
