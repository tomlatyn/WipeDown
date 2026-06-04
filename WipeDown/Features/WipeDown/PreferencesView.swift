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
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.18))
            .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let statusMessage = store.state.statusMessage {
                            statusCard(statusMessage)
                        }

                        settingsSection("Lock Behavior") {
                            glassCard {
                                rowContainer {
                                    HStack(alignment: .center, spacing: 16) {
                                        rowText(
                                            title: "Dim display",
                                            caption: "Keeps the display visible enough for the overlay while making smudges and dust easier to see."
                                        )

                                        Spacer(minLength: 16)

                                        Toggle("", isOn: store.binding(get: \.dimScreen, send: WipeDownFeature.Action.setDimScreen))
                                            .labelsHidden()
                                            .toggleStyle(.switch)
                                            .tint(.blue)
                                    }
                                }

                                if store.state.dimScreen {
                                    rowDivider

                                    rowContainer {
                                        buttonRow(
                                            title: "Test Display Dimming",
                                            caption: "Preview how the lock overlay looks when display dimming is enabled.",
                                            isDisabled: store.state.isTestingScreenDim
                                        ) {
                                            store.send(.testScreenDimTapped)
                                        }
                                    }

                                    rowDivider

                                    rowContainer {
                                        buttonRow(
                                            title: "Test Keyboard Lock",
                                            caption: "Blocks keyboard input for 3 seconds so you can verify the lock behavior."
                                        ) {
                                            store.send(.testKeyboardBlockTapped)
                                        }
                                    }
                                }
                            }
                        }

                        settingsSection("Unlock and Safety") {
                            glassCard {
                                rowContainer {
                                    HStack(alignment: .center, spacing: 16) {
                                        rowText(
                                            title: "Unlock shortcut",
                                            caption: "Choose the key combination you will use to end the lock."
                                        )

                                        Spacer(minLength: 16)

                                        Picker(
                                            "",
                                            selection: store.binding(get: \.selectedCombination, send: WipeDownFeature.Action.setSelectedCombination)
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

                                rowDivider

                                rowContainer {
                                    sliderRow(
                                        title: "Hold duration",
                                        valueText: store.state.holdDurationText,
                                        caption: "Sets how long the shortcut must be held before WipeDown unlocks."
                                    ) {
                                        Slider(
                                            value: store.binding(get: \.holdDuration, send: WipeDownFeature.Action.setHoldDuration),
                                            in: 0.0...5.0,
                                            step: 0.5
                                        )
                                        .onChange(of: store.state.holdDuration, initial: false) { _, _ in
                                            performSliderHaptic()
                                        }
                                    }
                                }

                                rowDivider

                                rowContainer {
                                    sliderRow(
                                        title: "Safety timer",
                                        valueText: store.state.safetyDurationText,
                                        caption: "Automatically ends the lock after this time, even if you do not use the shortcut."
                                    ) {
                                        Slider(
                                            value: store.binding(get: \.safetyDuration, send: WipeDownFeature.Action.setSafetyDuration),
                                            in: 30.0...300.0,
                                            step: 30.0
                                        )
                                        .onChange(of: store.state.safetyDuration, initial: false) { _, _ in
                                            performSliderHaptic()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.top, 24)
                    .padding(.bottom, 22)
                }
                .scrollIndicators(.hidden)

                footerBar
            }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 500, idealWidth: 540, minHeight: 600)
    }

    private var footerBar: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(store.state.unlockPrompt).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.92))

                Text("Safety timer: \(store.state.safetyDurationText)")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))

            content()
        }
    }

    @ViewBuilder
    private func statusCard(_ message: String) -> some View {
        glassCard {
            rowContainer {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder
    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.035))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
            .padding(.horizontal, 18)
    }

    @ViewBuilder
    private func rowContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowText(title: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.96))

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func buttonRow(
        title: String,
        caption: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isDisabled)

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func sliderRow<SliderContent: View>(
        title: String,
        valueText: String,
        caption: String,
        @ViewBuilder slider: () -> SliderContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 16) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.96))

                Spacer()

                Text(valueText)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.62))
            }

            slider()

            Text(caption)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func performSliderHaptic() {
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
