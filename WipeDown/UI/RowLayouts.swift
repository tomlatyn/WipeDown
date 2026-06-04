//
//  RowLayouts.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct RowDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.divider)
            .frame(height: 1)
            .padding(.horizontal, AppTheme.Spacing.rowPaddingHorizontal)
    }
}

struct RowContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, AppTheme.Spacing.rowPaddingHorizontal)
            .padding(.vertical, AppTheme.Spacing.contentGap)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RowText: View {
    let title: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.small) {
            Text(title)
                .font(AppTheme.Fonts.rowTitle)
                .foregroundStyle(Color.primaryText)

            Text(caption)
                .font(AppTheme.Fonts.rowCaption)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
