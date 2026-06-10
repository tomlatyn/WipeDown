//
//  UnlockOverlayView.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 03.06.2026.
//

import SwiftUI

struct UnlockOverlayView: View {
    @ObservedObject var store: WipeDownStore
    
    var body: some View {
        ZStack {
            Color.black
                .opacity(store.state.overlayOpacity)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: AppTheme.Spacing.cardSpacing) {
                ZStack {
                    Circle()
                        .trim(from: 0.0, to: CGFloat(store.state.unlockProgress))
                        .stroke(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.linear(duration: 0.05), value: store.state.unlockProgress)
                    
                    if store.state.unlockProgress > 0 {
                        Text("\(Int(store.state.unlockProgress * 100))%")
                            .font(AppTheme.Fonts.displayTitle)
                            .foregroundColor(Color.primaryText)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "keyboard.fill")
                            .font(AppTheme.Fonts.displayIcon)
                            .foregroundColor(Color.secondaryText)
                    }
                }
                
                VStack(spacing: AppTheme.Spacing.listGap) {
                    Text(store.state.unlockPrompt)
                        .font(AppTheme.Fonts.displaySemibold)
                        .foregroundColor(Color.primaryText)
                    
                    Text(String(localized: .overlayActiveMessage))
                        .font(AppTheme.Fonts.displayRegular)
                        .foregroundColor(Color.tertiaryText)
                    
                    Text(String(localized: .overlayEndsAutomaticallyFormat(store.state.remainingSafetyTimeText)))
                        .font(AppTheme.Fonts.displayMuted)
                        .foregroundColor(Color.tertiaryText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
