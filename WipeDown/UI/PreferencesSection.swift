//
//  PreferencesSection.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct PreferencesSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sectionSpacing) {
            Text(title)
                .font(AppTheme.Fonts.sectionHeader)
                .foregroundStyle(Color.primaryText)

            content()
        }
    }
}
