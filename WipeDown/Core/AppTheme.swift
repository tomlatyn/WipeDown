//
//  AppTheme.swift
//  WipeDown
//
//  Created by Tomáš Latýn on 04.06.2026.
//

import SwiftUI

enum AppTheme {
    enum Spacing {
        /// 4 pt - Used for tight spacing between closely stacked elements (e.g., spacing between the app title and version string).
        static let tiny: CGFloat = 4
        
        /// 6 pt - Used for spacing between primary text titles and their corresponding captions in custom row text components.
        static let small: CGFloat = 6
        
        /// 8 pt - Used as the gap in vertical overlay stacks and lock screen status lists.
        static let listGap: CGFloat = 8
        
        /// 10 pt - Used as the vertical spacing between interactive control elements and their descriptive text inside rows (e.g., ButtonRow).
        static let rowSpacing: CGFloat = 10
        
        /// 12 pt - Used as the spacing between section headers and their respective card content, and as layout spacing in sliders.
        static let sectionSpacing: CGFloat = 12
        
        /// 14 pt - Used as the vertical padding inside standard card row containers.
        static let contentGap: CGFloat = 14
        
        /// 16 pt - Used as horizontal spacing/gap between labels and control controls in toggle rows, slider headers, etc.
        static let horizontalGap: CGFloat = 16
        
        /// 18 pt - Used as the horizontal padding inside glass cards and horizontal row dividers.
        static let rowPaddingHorizontal: CGFloat = 18
        
        /// 24 pt - Used as the standard spacing between main glass card containers, screen sections, and padding around overlay content.
        static let cardSpacing: CGFloat = 24
        
        /// 26 pt - Used as the outer horizontal padding of the screen scroll container.
        static let screenPaddingHorizontal: CGFloat = 26
    }
    
    enum CornerRadius {
        /// 8 pt - Used for interactive controls and standard bordered buttons.
        static let button: CGFloat = 8
        
        /// 18 pt - Used for all primary content panels and frosted glass card containers (GlassCard).
        static let card: CGFloat = 18
    }

    enum Fonts {
        /// Title in section headers (15pt, semibold) - Used for primary settings section category titles (e.g., "Settings", "About").
        static let sectionHeader = Font.system(size: 15, weight: .semibold)
        
        /// Primary Row title font (13pt, medium) - Used for the title of toggles, sliders, and button action items inside cards.
        static let rowTitle = Font.system(size: 13, weight: .medium)
        
        /// Secondary Row value or caption font (12pt, regular) - Used for secondary details, helper text, and values next to sliders.
        static let rowCaption = Font.system(size: 12)
        
        /// Smaller version / build tag (12pt, regular) - Used specifically for displaying the version details in the About block.
        static let version = Font.system(size: 12)
        
        /// App/Section main visual headers (17pt, semibold) - Used for major panel titles (e.g., the "WipeDown" branding header in About).
        static let appHeader = Font.system(size: 17, weight: .semibold)
        
        /// Display Title (22pt, bold, rounded) - Used for lock progress percentage text inside the unlock/safety ring.
        static let displayTitle = Font.system(size: 22, weight: .bold, design: .rounded)
        
        /// Display Semibold text (22pt, semibold, rounded) - Used for main warning prompts on the lock screen overlay.
        static let displaySemibold = Font.system(size: 22, weight: .semibold, design: .rounded)
        
        /// Large status test title (22pt, semibold, rounded) - Used for the main header text in the keyboard/dimming diagnostics screens.
        static let testHeader = Font.system(size: 22, weight: .semibold, design: .rounded)
        
        /// Display Regular (14pt, regular, rounded) - Used for primary instructions on the locked safety overlay screen.
        static let displayRegular = Font.system(size: 14, weight: .regular, design: .rounded)
        
        /// Display Muted (13pt, regular, rounded) - Used for secondary timer count metadata labels inside lock overlays.
        static let displayMuted = Font.system(size: 13, weight: .regular, design: .rounded)
        
        /// Large overlay icon font (36pt, regular)
        static let displayIcon = Font.system(size: 36)
        
        /// Fallback app placeholder icon font (32pt, semibold)
        static let placeholderIcon = Font.system(size: 32, weight: .semibold)
        
        /// Footer prompt font (12pt, medium)
        static let footerPrompt = Font.system(size: 12, weight: .medium)
    }
}
