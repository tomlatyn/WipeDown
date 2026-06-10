//
//  TestBlockOverlayView.swift
//  WipeDown
//
//  Created by Antigravity on 06.10.2026.
//

import SwiftUI

struct TestBlockOverlayView: View {
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let countdown = max(0, Int(ceil(endsAt.timeIntervalSince(context.date))))

            ZStack {
                Color.black
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: AppTheme.Spacing.cardSpacing) {
                    Image(systemName: "keyboard")
                        .font(AppTheme.Fonts.displayIcon)
                        .foregroundColor(Color.secondaryText)

                    Text(String(localized: .keyboardBlockTesting))
                        .font(AppTheme.Fonts.testHeader)
                        .foregroundColor(Color.primaryText)

                    Text(String(localized: .allKeypressesBlocked))
                        .font(AppTheme.Fonts.displayRegular)
                        .foregroundColor(Color.tertiaryText)

                    Text(String(localized: .endsAutomaticallySecondsFormat(countdown)))
                        .font(AppTheme.Fonts.displayMuted)
                        .foregroundColor(Color.tertiaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}
