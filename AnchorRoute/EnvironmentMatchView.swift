import SwiftUI
import ARKit
import CoreData

@available(iOS 12.0, *)
struct EnvironmentMatchView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject var visionProcessor = VisionProcessor()
    @ObservedObject var arViewModel: ARViewModel
    var route: RouteEntity

    @State private var matchingScore: Float = 0.0
    @State private var isReplaying = false
    @State private var statusMessage = "カメラを環境に向けてください..."
    @State private var showAR = false
    @State private var canReplay = false

    var body: some View {
        ZStack {
            if showAR {
                ARViewContainer(viewModel: arViewModel)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        stabilizeAndReplay()
                    }
            } else {
                CameraView(visionProcessor: visionProcessor)
                    .edgesIgnoringSafeArea(.all)
            }
            
            VStack {
                Spacer()
                if !showAR {
                    environmentMatchingUI
                }
                
                Spacer()
                Group {
                    if isReplaying {
                        Button("終了") {
                            endReplay()
                        }
                        .buttonStyle(AppButtonStyle(backgroundColor: AppColor.danger))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 50)
                    } else {
                        Button("経路再現") {
                            startReplayTransition()
                        }
                        .buttonStyle(AppButtonStyle(backgroundColor: AppColor.accent))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 50)
                    }
                }
                .padding(.bottom, 50)
            }
            if !statusMessage.isEmpty && !showAR {
                VStack {
                    HStack {
                        Spacer()
                        Text(statusMessage)
                            .font(AppFont.bodyFont())
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(AppCornerRadius.normal)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            startMatching()
        }
        .onReceive(visionProcessor.$matchingScore) { score in
            matchingScore = score
            if !showAR {
                statusMessage = "一致度: \(Int(score * 100))%"
            }
            if score >= 0.75 && !isReplaying && !showAR {
                canReplay = true
            }
        }
    }
    var environmentMatchingUI: some View {
        let progress = Double(matchingScore)
        return ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .foregroundColor(AppColor.secondaryText.opacity(0.5))
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(AppColor.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)
            Text(String(format: "%.0f%%", matchingScore * 100))
                .font(AppFont.headlineFont())
                .foregroundColor(.white)
        }
    }
    
    func startMatching() {
        guard let fp = route.featurePrint,
              let featurePrints = DataModel.shared.loadFeaturePrints(featurePrint: fp) else {
            statusMessage = "特徴点データがありません。"
            return
        }
        visionProcessor.startDetecting(with: featurePrints)
        statusMessage = "環境との一致度を計測中..."
    }

    func startReplayTransition() {
        statusMessage = "ARモードに切り替えています..."
        showAR = true
    }
    
    func stabilizeAndReplay() {
        guard let sceneView = arViewModel.sceneView else {
            statusMessage = "再現可能なシーンがありません"
            return
        }
        
        statusMessage = "ワールドマップを読み込み中..."
        guard let wmData = route.worldMapData else {
            statusMessage = "ワールドマップデータがありません。"
            return
        }
        
        if let wm = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: wmData) {
            arViewModel.loadWorldMap(wm)
            statusMessage = "ARセッションを安定化しています..."
            arViewModel.waitUntilTrackingNormal(sceneView: sceneView) {
                if let posData = route.positions {
                    let decoder = JSONDecoder()
                    if let decodedPositions = try? decoder.decode([Coordinate].self, from: posData) {
                        arViewModel.recordedPositions = decodedPositions
                    } else {
                        statusMessage = "座標データの復元に失敗しました。"
                        return
                    }
                } else {
                    statusMessage = "座標データがありません。"
                    return
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    statusMessage = "経路を再現します..."
                    isReplaying = true
                    NotificationCenter.default.post(name: .startReplaying, object: nil)
                }
            }
        } else {
            statusMessage = "ワールドマップの読み込みに失敗しました。"
        }
    }
    
    func endReplay() {
        arViewModel.sceneView?.session.pause()
        presentationMode.wrappedValue.dismiss()
    }
}
