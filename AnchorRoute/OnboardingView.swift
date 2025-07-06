import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false

    var body: some View {
        VStack(spacing: AppPadding.regular) {
            AppTitleText(text: "Welcome to AnchorRoute")
            AppBodyText(text: "This app helps you record and replay routes in AR.\n\n- Record environment features\n- Record your route\n- Save and name\n- Revisit and replay!\n\nLet's get started!")
                .multilineTextAlignment(.center)

            Spacer()

            Button("Continue") {
                hasSeenOnboarding = true
            }
            .buttonStyle(AppButtonStyle(backgroundColor: AppColor.success))
        }
        .appBackground()
    }
}
