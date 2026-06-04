//
//  ButtonRow.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct ButtonRow: View {
    let title: String
    let caption: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.rowSpacing) {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isDisabled)

            Text(caption)
                .font(AppTheme.Fonts.rowCaption)
                .foregroundStyle(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
