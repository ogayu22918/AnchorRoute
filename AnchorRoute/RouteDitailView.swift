import SwiftUI

struct RouteDetailView: View {
    var route: RouteEntity
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var arViewModel = ARViewModel(context: PersistenceController.shared.container.viewContext)
    
    @State private var showShareAlert = false
    @State private var shareMessage = ""
    
    @State private var showDownloadSheet = false
    @State private var showCopyAlert = false
    
    var body: some View {
        VStack(spacing: AppPadding.regular) {
            AppTitleText(text: "経路の詳細")
            
            Text("名称: \(route.name ?? "名称未設定")")
                .font(AppFont.bodyFont())
                .foregroundColor(AppColor.primaryText)

            if let st = route.startThumbnail, let uiImg = UIImage(data: st) {
                Text("記録開始地点")
                    .font(AppFont.footnoteFont())
                    .foregroundColor(AppColor.secondaryText)
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else {
                Text("記録開始地点の画像がありません")
                    .font(AppFont.footnoteFont())
                    .foregroundColor(AppColor.secondaryText)
            }
            
            if let ts = route.timestamp {
                Text("保存日: \(ts, style: .date) \(ts, style: .time)")
                    .font(AppFont.footnoteFont())
                    .foregroundColor(AppColor.secondaryText)
            }

            if let docID = route.docID, !docID.isEmpty {
                VStack(spacing: AppPadding.small) {
                    Text("アクセスキー:")
                        .font(AppFont.footnoteFont())
                        .foregroundColor(AppColor.primaryText)
                    HStack(spacing: 8) {
                        Text(docID)
                            .font(AppFont.bodyFont())
                            .foregroundColor(AppColor.accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        
                        Button(action: {
                            UIPasteboard.general.string = docID
                            showCopyAlert = true
                        }) {
                            Image(systemName: "doc.on.doc")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                        .frame(width: 30, height: 30)
                        .background(AppColor.accent)
                        .cornerRadius(5)
                    }
                }
                .padding(.top, AppPadding.regular)
            }
            
            Spacer()
            
            HStack(spacing: AppPadding.regular) {
                NavigationLink(destination: EnvironmentMatchView(arViewModel: arViewModel, route: route)) {
                    Text("環境一致を確認")
                }
                .buttonStyle(AppButtonStyle(backgroundColor: AppColor.warning))
                
                Button("共有する") {
                    shareRoute()
                }
                .buttonStyle(AppButtonStyle(backgroundColor: (route.docID?.isEmpty ?? true) ? AppColor.accent : Color.gray))
                .disabled(!(route.docID?.isEmpty ?? true))
            }
            
            Spacer()
        }
        .appBackground()
        .alert(isPresented: $showCopyAlert) {
            Alert(title: Text("コピーしました"),
                  message: Text("クリップボードにコピーされました。"),
                  dismissButton: .default(Text("OK")))
        }
        .alert(isPresented: $showShareAlert) {
            Alert(title: Text("共有結果"),
                  message: Text(shareMessage),
                  dismissButton: .default(Text("OK")))
        }
    }
    
    private func shareRoute() {
        shareMessage = "共有機能は現在利用できません"
        showShareAlert = true
    }
}
