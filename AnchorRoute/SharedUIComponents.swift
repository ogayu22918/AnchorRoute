import SwiftUI

struct AppButtonStyle: ButtonStyle {
    var backgroundColor: Color = AppColor.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.headlineFont())
            .foregroundColor(.white)
            .padding(AppPadding.regular)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(AppCornerRadius.normal)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct AppTitleText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppFont.titleFont())
            .foregroundColor(AppColor.primaryText)
            .padding(.top, AppPadding.large)
    }
}

struct AppBodyText: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppFont.bodyFont())
            .foregroundColor(AppColor.primaryText)
    }
}

struct AppBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppColor.background.edgesIgnoringSafeArea(.all))
    }
}

extension View {
    func appBackground() -> some View {
        self.modifier(AppBackground())
    }
}
