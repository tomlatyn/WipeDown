//
//  TestDimOverlayView.swift
//  WipeDown
//
//  Created by Antigravity on 06.10.2026.
//

import SwiftUI

struct TestDimOverlayView: View {
    let configuration: WipeDownFeature.TestOverlayConfiguration
    let endsAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let countdown = max(0, Int(ceil(endsAt.timeIntervalSince(context.date))))

            ZStack {
                Color.black
                    .opacity(configuration.overlayOpacity)
                    .edgesIgnoringSafeArea(.all)

                VStack(spacing: AppTheme.Spacing.cardSpacing) {
                    ZStack {
                        Image(systemName: "display")
                            .font(AppTheme.Fonts.displayIcon)
                            .foregroundColor(Color.secondaryText)
                    }

                    VStack(spacing: AppTheme.Spacing.listGap) {
                        Text(String(localized: .dimmingTestActive))
                            .font(AppTheme.Fonts.testHeader)
                            .foregroundColor(Color.primaryText)

                        Text(String(localized: .endsAutomaticallySecondsFormat(countdown)))
                            .font(AppTheme.Fonts.displayRegular)
                            .foregroundColor(Color.tertiaryText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }
}
