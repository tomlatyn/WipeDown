//
//  PreferencesView.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct PreferencesView: View {
    @ObservedObject var store: WipeDownStore
    private let sidebarWidth: CGFloat = 54

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)

            VStack(spacing: 0) {
                contentScroll
                footerBar
            }
        }
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .frame(minWidth: 580, idealWidth: 760, minHeight: 600)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.listGap) {
            ForEach(PreferencesScreen.allCases) { screen in
                sidebarItem(screen)
            }

            Spacer()
        }
        .padding(.horizontal, AppTheme.Spacing.listGap)
        .padding(.top, AppTheme.Spacing.cardSpacing)
        .frame(width: sidebarWidth)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private func sidebarItem(_ screen: PreferencesScreen) -> some View {
        let isSelected = store.state.preferences.selectedScreen == screen

        Button {
            store.send(.preferences(.setSelectedScreen(screen)))
        } label: {
            Image(systemName: screen.systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.listGap)
                .contentShape(Rectangle())
                .background {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppTheme.CornerRadius.button, style: .continuous)
                            .fill(Color.glassSelection)
                    }
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.primaryText : Color.secondaryText)
        .contentShape(Rectangle())
        .help(screen.title)
    }

    private var contentScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.cardSpacing) {
                if let statusMessage = store.state.statusMessage {
                    StatusCard(message: statusMessage)
                }

                switch store.state.preferences.selectedScreen {
                case .lock:
                    LockSettingsView(store: store)
                case .settings:
                    AppSettingsView(store: store)
                case .about:
                    AboutView(store: store)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.screenPaddingHorizontal)
            .padding(.top, AppTheme.Spacing.cardSpacing)
            .padding(.bottom, AppTheme.Spacing.cardSpacing)
        }
        .scrollIndicators(.hidden)
    }

    private var footerBar: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.rowPaddingHorizontal) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.tiny) {
                Text("\(store.state.unlockPrompt).")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.primaryText)

                Text(String(localized: .safetyTimerFooterFormat(store.state.safetyDurationText)))
                    .font(AppTheme.Fonts.rowCaption)
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()

            Button {
                store.send(.startButtonTapped(store))
            } label: {
                Label(String(localized: .lockForCleaning), systemImage: "lock.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, AppTheme.Spacing.cardSpacing)
        .padding(.vertical, AppTheme.Spacing.horizontalGap)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.divider)
                .frame(height: 1)
        }
    }
}

struct StatusCard: View {
    let message: String

    var body: some View {
        GlassCard {
            RowContainer {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
    }
}
