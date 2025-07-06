

import SwiftUI
import CoreData
import ARKit

struct CreateRouteFlowView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    

    @StateObject private var visionProcessor = VisionProcessor()
    @StateObject private var arViewModel = ARViewModel(context: PersistenceController.shared.container.viewContext)
    
    @State private var statusMessage: String = ""
    @State private var countdown: Int = 0
    
    @State private var savedFeaturePrint: FeaturePrint?
    @State private var savedRoute: RouteEntity?
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var finalName = ""
    

    @State private var startThumbnail: Data? = nil
    
    enum FlowState {
        case idle
        case environmentRecording
        case environmentDone
        case routeRecording
        case routeDone
        case naming
        case finished
    }
    @State private var state: FlowState = .idle
    
    var body: some View {
        ZStack {
            backgroundView
            VStack(spacing: 16) {
                Text(instructionText)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
                    .padding(.top, 40)
                
                if countdown > 0 {
                    Text("あと \(countdown) 秒")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Spacer()
                controlButtons
            }
            .padding()
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(title: Text("通知"),
                  message: Text(saveAlertMessage),
                  dismissButton: .default(Text("OK")))
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingFinished)) { _ in
            if state == .environmentRecording {
                statusMessage = "環境記録が完了しました。"
                let snap = visionProcessor.getSnapshotData()
                if let fp = DataModel.shared.saveFeaturePrints(
                    visionProcessor.recordedFeaturePrints,
                    name: "HiddenFeaturePrint",
                    thumbnail: snap
                ) {
                    savedFeaturePrint = fp
                }
                state = .environmentDone
            }
        }
        .onDisappear {
            arViewModel.sceneView?.session.pause()
        }
    }
    
    var backgroundView: some View {
        switch state {
        case .idle, .environmentRecording, .environmentDone:
            return AnyView(
                CameraView(visionProcessor: visionProcessor)
                    .edgesIgnoringSafeArea(.all)
            )
        default:
            return AnyView(
                ARViewContainer(viewModel: arViewModel)
                    .edgesIgnoringSafeArea(.all)
            )
        }
    }
    
    var instructionText: String {
        switch state {
        case .idle:
            return "新しい経路を作成します。\n「記録開始」で環境を記録してください。"
        case .environmentRecording:
            return "環境を記録中...\nカメラを周囲に向けてください。"
        case .environmentDone:
            return "環境記録が完了しました。\n次に経路を記録します。"
        case .routeRecording:
            return "経路を記録中...\n移動してください。「停止」で終了します。"
        case .routeDone:
            return "経路記録が完了しました。名前を付けましょう。"
        case .naming:
            return "経路と環境に名前を付けてください。"
        case .finished:
            return "名前が保存されました。メインメニューに戻れます。"
        }
    }
    
    var controlButtons: some View {
        HStack {
            switch state {
            case .idle:
                Button("記録開始") {
                    let snap = visionProcessor.getSnapshotData()
                    self.startThumbnail = snap

                    startEnvironmentRecording()
                }
                .buttonStyle(AppButtonStyle(backgroundColor: .blue))
                
            case .environmentRecording:
                Button("終了") {
                    visionProcessor.stopRecording()
                }
                .buttonStyle(AppButtonStyle(backgroundColor: .red))
                
            case .environmentDone:
                Button("経路記録開始") {
                    startRouteRecording()
                }
                .buttonStyle(AppButtonStyle(backgroundColor: .blue))
                
            case .routeRecording:
                Button("停止") {
                    stopRouteRecording()
                }
                .buttonStyle(AppButtonStyle(backgroundColor: .red))
                
            case .routeDone:
                Button("名前付け") {
                    state = .naming
                }
                .buttonStyle(AppButtonStyle(backgroundColor: .blue))
                
            case .naming:
                namingControls
                
            case .finished:
                Button("メインメニューへ") {
                    dismiss()
                }
                .buttonStyle(AppButtonStyle(backgroundColor: .blue))
            }
        }
    }
    
    var namingControls: some View {
        HStack(spacing: 8) {
            TextField("経路名", text: $finalName)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
            Button("保存") {
                saveFinalName()
            }
            .buttonStyle(AppButtonStyle(backgroundColor: .green))
        }
    }
    
    func startEnvironmentRecording() {
        state = .environmentRecording
        countdown = 5
        visionProcessor.startRecording()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            countdown -= 1
            if countdown <= 0 {
                timer.invalidate()
            }
        }
    }
    
    func startRouteRecording() {
        state = .routeRecording
        arViewModel.recordedPositions.removeAll()
        arViewModel.initialPosition = nil
        arViewModel.lastRecordedPosition = nil
        arViewModel.startRecording()
    }
    
    func stopRouteRecording() {
        arViewModel.stopRecording()
        state = .routeDone
        saveRouteWithFeaturePrint()
    }
    
    func saveRouteWithFeaturePrint() {
        statusMessage = "ルートを保存しています..."
        arViewModel.getWorldMapAndSave(
            positions: arViewModel.recordedPositions,
            name: "Untitled Route",
            linkedFeaturePrint: savedFeaturePrint,
            startThumbnail: startThumbnail
        ) { newRoute in
            savedRoute = newRoute
            statusMessage = "ルート保存完了"
            saveAlertMessage = "ルートが正常に保存されました！"
            showSaveAlert = true
        }
    }
    
    func saveFinalName() {
        guard let route = savedRoute else {
            statusMessage = "名前付けするデータがありません"
            return
        }
        let newName = finalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalRouteName = newName.isEmpty ? "名称未設定" : newName
        
        viewContext.performAndWait {
            route.name = finalRouteName
            do {
                try viewContext.save()
                statusMessage = "名前が保存されました"
                saveAlertMessage = "名前が正常に保存されました！"
                showSaveAlert = true
                state = .finished
            } catch {
                statusMessage = "名前保存失敗: \(error.localizedDescription)"
            }
        }
    }
}
