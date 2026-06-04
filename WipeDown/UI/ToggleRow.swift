//
//  ToggleRow.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct ToggleRow: View {
    let title: String
    let caption: String
    let isOn: Binding<Bool>

    var body: some View {
        HStack(alignment: .center, spacing: AppTheme.Spacing.horizontalGap) {
            RowText(title: title, caption: caption)

            Spacer(minLength: AppTheme.Spacing.horizontalGap)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.blue)
        }
    }
}
