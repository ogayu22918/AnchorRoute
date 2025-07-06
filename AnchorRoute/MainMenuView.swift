import SwiftUI
import CoreData

struct MainMenuView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var arViewModel = ARViewModel(context: PersistenceController.shared.container.viewContext)

    var body: some View {
        VStack(spacing: AppPadding.regular*2) {
            AppTitleText(text: "AnchorRoute")
            AppBodyText(text: "環境と経路を記録し、それをでARを用いて再現します。")
                .multilineTextAlignment(.center)

            Spacer()

            NavigationLink(destination: CreateRouteFlowView()) {
                Text("新しい経路を作成")
            }
            .buttonStyle(AppButtonStyle(backgroundColor: AppColor.accent))
            .padding(.horizontal)

            NavigationLink(destination: SavedRoutesView(viewModel: arViewModel)) {
                Text("保存された経路を見る")
            }
            .buttonStyle(AppButtonStyle(backgroundColor: AppColor.success))
            .padding(.horizontal)

            Spacer()
        }
        .appBackground()
    }
}
