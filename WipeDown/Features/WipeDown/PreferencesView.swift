//
//  PreferencesView.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import AppKit
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: WipeDownStore
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                if let statusMessage = store.state.statusMessage {
                    Section {
                        Label(statusMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
                
                Section {
                    settingRow("Keeps the display visible enough for the overlay while making smudges and dust easier to see.") {
                        Toggle(
                            "Dim display",
                            isOn: store.binding(get: \.dimScreen, send: WipeDownFeature.Action.setDimScreen)
                        )
                    }
                    
                    if store.state.dimScreen {
                        settingRow("Preview how the lock overlay looks when display dimming is enabled.") {
                            Button("Test Display Dimming") {
                                store.send(.testScreenDimTapped)
                            }
                            .disabled(store.state.isTestingScreenDim)
                        }

                        settingRow("Temporarily blocks key input so you can confirm the unlock flow feels right.") {
                            Button("Test Keyboard Lock") {
                                store.send(.testKeyboardBlockTapped)
                            }
                        }
                    }
                } header: {
                    Text("Lock Behavior")
                }
                
                Section {
                    settingRow("Choose the key combination you will use to end the lock.") {
                        Picker(
                            "Unlock shortcut",
                            selection: store.binding(get: \.selectedCombination, send: WipeDownFeature.Action.setSelectedCombination)
                        ) {
                            ForEach(UnlockCombination.allCases) { combo in
                                Text(combo.displayString).tag(combo)
                            }
                        }
                    }
                    
                    settingRow("Sets how long the shortcut must be held before WipeDown unlocks.") {
                        LabeledContent("Hold duration") {
                            Text(store.state.holdDurationText)
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: store.binding(get: \.holdDuration, send: WipeDownFeature.Action.setHoldDuration),
                            in: 0.0...5.0,
                            step: 0.5
                        )
                        .onChange(of: store.state.holdDuration, initial: false) { _, _ in
                            performSliderHaptic()
                        }
                    }
                    
                    settingRow("Automatically ends the lock after this time, even if you do not use the shortcut.") {
                        LabeledContent("Safety timer") {
                            Text(store.state.safetyDurationText)
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: store.binding(get: \.safetyDuration, send: WipeDownFeature.Action.setSafetyDuration),
                            in: 30.0...300.0,
                            step: 30.0
                        )
                        .onChange(of: store.state.safetyDuration, initial: false) { _, _ in
                            performSliderHaptic()
                        }
                    }
                } header: {
                    Text("Unlock and Safety")
                } footer: {
                    Text("WipeDown will automatically end the lock after the safety timer, even if the unlock shortcut is not used.")
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(store.state.unlockPrompt).")
                        .font(.footnote)
                    Text("Safety timer: \(store.state.safetyDurationText)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    store.send(.startButtonTapped(store))
                } label: {
                    Label("Start WipeDown", systemImage: "lock.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            .background(.regularMaterial)
        }
        .frame(minWidth: 420, idealWidth: 460, minHeight: 520)
    }

    private func performSliderHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    @ViewBuilder
    private func settingRow<Content: View>(_ description: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
