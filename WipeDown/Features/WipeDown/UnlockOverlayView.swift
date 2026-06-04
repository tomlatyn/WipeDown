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
            
            VStack(spacing: 24) {
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
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "keyboard.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                VStack(spacing: 8) {
                    Text(store.state.unlockPrompt)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text("WipeDown is active. Clean your keyboard and display.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                    
                    Text("Ends automatically in \(store.state.remainingSafetyTimeText)")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
