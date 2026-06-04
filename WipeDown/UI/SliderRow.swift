//
//  SliderRow.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct SliderRow<SliderContent: View>: View {
    let title: String
    let valueText: String
    let caption: String
    @ViewBuilder let slider: () -> SliderContent

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sectionSpacing) {
            HStack(alignment: .center, spacing: AppTheme.Spacing.horizontalGap) {
                Text(title)
                    .font(AppTheme.Fonts.rowTitle)
                    .foregroundStyle(Color.primaryText)

                Spacer()

                Text(valueText)
                    .font(AppTheme.Fonts.rowCaption)
                    .foregroundStyle(Color.secondaryText)
            }

            slider()

            Text(caption)
                .font(AppTheme.Fonts.rowCaption)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
