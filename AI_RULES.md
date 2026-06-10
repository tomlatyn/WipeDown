# WipeDown AI Rules

- **Architecture**: The project uses The Composable Architecture (TCA).
- **Design System & Styling**: 
  - Colors are defined in the asset catalog ([Assets.xcassets](file:///Users/tom/git/WipeDown/WipeDown/Resources/Assets.xcassets)) and referenced as color constants (e.g., `Color.primaryText`, `Color.secondaryText`, `Color.tertiaryText`, `Color.divider`, `Color.glassSelection`).
  - Spacings, corner radii, and typography/fonts are defined and must be used from [AppTheme.swift](file:///Users/tom/git/WipeDown/WipeDown/Core/AppTheme.swift) namespaces:
    - `AppTheme.Spacing.*`
    - `AppTheme.CornerRadius.*`
    - `AppTheme.Fonts.*`
- **MARK Comments Formatting**: All `// MARK:` comments in Swift source files must be formatted with exactly one vertically empty line above and one vertically empty line below them.
- **Inline Comments**: No inline code comments should be used. Only file header comments and formatting-compliant MARK comments are allowed.
