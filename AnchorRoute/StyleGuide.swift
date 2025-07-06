import SwiftUI

struct AppColor {
    static let background = Color.white
    static let primaryText = Color.black
    static let secondaryText = Color.gray
    static let accent = Color.blue
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red
    static let neutral = Color.gray
}

struct AppFont {
    static func titleFont() -> Font {
        Font.system(size: 24, weight: .bold, design: .default)
    }

    static func headlineFont() -> Font {
        Font.system(size: 18, weight: .semibold, design: .default)
    }

    static func bodyFont() -> Font {
        Font.system(size: 16, weight: .regular, design: .default)
    }

    static func footnoteFont() -> Font {
        Font.system(size: 14, weight: .regular, design: .default)
    }
}

struct AppPadding {
    static let regular: CGFloat = 16
    static let small: CGFloat = 8
    static let large: CGFloat = 24
}

struct AppCornerRadius {
    static let normal: CGFloat = 10
}
