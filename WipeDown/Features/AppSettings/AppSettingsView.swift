//
//  AppSettingsView.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct AppSettingsView: View {
    @ObservedObject var store: WipeDownStore

    var body: some View {
        PreferencesSection(title: String(localized: .general)) {
            GlassCard {
                RowContainer {
                    ToggleRow(
                        title: String(localized: .startAtLoginTitle),
                        caption: String(localized: .startAtLoginCaption),
                        isOn: store.binding(
                            get: { $0.appSettings.startAtLogin },
                            send: { .appSettings(.setStartAtLogin($0)) }
                        )
                    )
                }

                RowDivider()

                RowContainer {
                    ToggleRow(
                        title: String(localized: .showMenuBarTitle),
                        caption: String(localized: .showMenuBarCaption),
                        isOn: store.binding(
                            get: { $0.appSettings.showMenuBarIcon },
                            send: { .appSettings(.setShowMenuBarIcon($0)) }
                        )
                    )
                }

                RowDivider()

                RowContainer {
                    ToggleRow(
                        title: String(localized: .openSettingsOnLaunchTitle),
                        caption: store.state.appSettings.showMenuBarIcon
                            ? String(localized: .openSettingsOnLaunchCaptionVisible)
                            : String(localized: .openSettingsOnLaunchCaptionHidden),
                        isOn: store.binding(
                            get: { $0.appSettings.openSettingsOnLaunch },
                            send: { .appSettings(.setOpenSettingsOnLaunch($0)) }
                        )
                    )
                    .disabled(!store.state.appSettings.showMenuBarIcon)
                }
            }
        }
    }
}
