import SwiftUI

struct SavedRoutesView: View {
    @ObservedObject var viewModel: ARViewModel

    @State private var showDownloadSheet = false

    var body: some View {
        VStack {
            HStack {
                AppTitleText(text: "保存された経路")
                Spacer()
                Button(action: {
                    showDownloadSheet = true
                }) {
                    Image(systemName: "plus")
                }
                .padding()
                .sheet(isPresented: $showDownloadSheet) {
                    DownloadFlowView()
                }
            }

            if viewModel.savedRoutes.isEmpty {
                AppBodyText(text: "保存された経路はありません。")
            } else {
                List {
                    ForEach(viewModel.savedRoutes) { route in
                        NavigationLink(destination: RouteDetailView(route: route)) {
                            VStack(alignment: .leading, spacing: AppPadding.small) {
                                Text(route.name ?? "名称未設定")
                                    .font(AppFont.headlineFont())
                                    .foregroundColor(AppColor.primaryText)
                                if let ts = route.timestamp {
                                    Text("保存日: \(ts, style: .date) \(ts, style: .time)")
                                        .font(AppFont.footnoteFont())
                                        .foregroundColor(AppColor.secondaryText)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteRoute)
                }
            }
            Spacer()
        }
        .appBackground()
        .onAppear {
            viewModel.fetchSavedRoutes()
        }
    }

    func deleteRoute(at offsets: IndexSet) {
        for index in offsets {
            let route = viewModel.savedRoutes[index]
            viewModel.deleteRoute(route)
        }
    }
}
