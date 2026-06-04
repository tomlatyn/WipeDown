//
//  AboutView.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct AboutView: View {
    @ObservedObject var store: WipeDownStore

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return String(localized: .aboutVersionFormat(version, build))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.cardSpacing) {
            PreferencesSection(title: String(localized: .wipedown)) {
                GlassCard {
                    RowContainer {
                        HStack(alignment: .center, spacing: AppTheme.Spacing.contentGap) {
                            if let icon = NSImage(named: NSImage.applicationIconName) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 64, height: 64)
                            } else {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(.blue)
                                    .frame(width: 64, height: 64)
                            }

                            VStack(alignment: .leading, spacing: AppTheme.Spacing.tiny) {
                                Text(String(localized: .appName))
                                    .font(AppTheme.Fonts.appHeader)
                                    .foregroundStyle(Color.primaryText)

                                Text(versionString)
                                    .font(AppTheme.Fonts.version)
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                    }
                }
            }

            PreferencesSection(title: String(localized: .information)) {
                GlassCard {
                    RowContainer {
                        RowText(
                            title: String(localized: .author),
                            caption: String(localized: .authorName)
                        )
                    }

                    RowDivider()

                    RowContainer {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.rowSpacing) {
                            RowText(
                                title: String(localized: .support),
                                caption: String(localized: .supportCaption)
                            )

                            Button(String(localized: .buyMeACoffee)) {
                                store.send(.about(.openSupportTapped))
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    RowDivider()

                    RowContainer {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.rowSpacing) {
                            RowText(
                                title: String(localized: .repository),
                                caption: String(localized: .repositoryUrl)
                            )

                            Button(String(localized: .githubRepository)) {
                                store.send(.about(.openRepositoryTapped))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}
