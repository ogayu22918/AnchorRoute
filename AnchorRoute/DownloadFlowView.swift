import SwiftUI
import CoreData

struct DownloadFlowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var docID: String = ""
    @State private var statusMessage: String = ""
    @State private var showAlert = false

    var body: some View {
        VStack(spacing: AppPadding.regular) {
            AppTitleText(text: "共有コードを入力してダウンロード")

            TextField("共有コード", text: $docID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button("ダウンロード") {
                downloadSharedRoute()
            }
            .buttonStyle(AppButtonStyle(backgroundColor: AppColor.accent))

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .foregroundColor(AppColor.primaryText)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Spacer()
        }
        .appBackground()
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("通知"),
                message: Text(statusMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    func downloadSharedRoute() {
        statusMessage = "ダウンロード機能は現在利用できません"
        showAlert = true
    }
}
