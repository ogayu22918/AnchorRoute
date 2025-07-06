import ARKit
import SceneKit

// アンカー再現用のデータをまとめる構造体
struct ReplayAnchorData {
    let node: SCNNode          // 球体のSCNNode
    let worldPos: SCNVector3   // 球体のワールド座標
    var passed: Bool           // ユーザーが通り過ぎたかどうか
}

class Coordinator: NSObject, ARSCNViewDelegate, ARSessionDelegate {
    weak var sceneView: ARSCNView?
    var viewModel: ARViewModel

    // 記録時に生成される赤球ノード
    var recordingNodes: [SCNNode] = []

    // 再現時に生成される青球ノードと通過フラグを管理
    var replayAnchors: [ReplayAnchorData] = []

    var replayInitialTransform: simd_float4x4?
    var isReplayingRoute = false

    init(viewModel: ARViewModel) {
        self.viewModel = viewModel
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(startReplayingHandler),
            name: .startReplaying,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - ARSCNViewDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        // 記録中は赤球を連続配置
        if viewModel.isRecording {
            recordAnchors(frame: frame)
        }

        // 再現中はノードとユーザー位置の距離を検知し、通り過ぎたら色変更
        if isReplayingRoute {
            // ユーザー(カメラ)位置を取得
            let cameraTransform = frame.camera.transform
            let userPos = SCNVector3(cameraTransform.columns.3.x,
                                     cameraTransform.columns.3.y,
                                     cameraTransform.columns.3.z)

            // 各ReplayAnchorDataとの距離を測定
            for i in 0..<replayAnchors.count {
                // まだpassed=falseなら判定
                if !replayAnchors[i].passed {
                    let anchorPos = replayAnchors[i].worldPos
                    let dist = distance(userPos, anchorPos)
                    // しきい値 (1.0mなどを適宜調整)
                    if dist < 1.0 {
                        // 通過とみなし、色をグレーに変更
                        let node = replayAnchors[i].node
                        if let geom = node.geometry {
                            geom.firstMaterial?.diffuse.contents = UIColor.gray
                        }
                        // passedフラグをtrueに更新
                        replayAnchors[i].passed = true
                    }
                }
            }
        }
    }

    // MARK: - Recording (赤球)
    func recordAnchors(frame: ARFrame) {
        let currentTransform = frame.camera.transform
        // 初回
        if viewModel.initialPosition == nil {
            viewModel.initialPosition = currentTransform
            viewModel.lastRecordedPosition = currentTransform
            let relPos = Coordinate(x: 0, y: 0, z: 0)
            viewModel.recordPosition(relPos)
            addRedSphere(at: currentTransform)
            return
        }

        if let lastPos = viewModel.lastRecordedPosition {
            let dist = distance(from: lastPos, to: currentTransform)
            let threshold: Float = 2.0
            if dist >= threshold {
                viewModel.lastRecordedPosition = currentTransform
                let rel = Coordinate(
                    x: currentTransform.columns.3.x - viewModel.initialPosition!.columns.3.x,
                    y: currentTransform.columns.3.y - viewModel.initialPosition!.columns.3.y,
                    z: currentTransform.columns.3.z - viewModel.initialPosition!.columns.3.z
                )
                viewModel.recordPosition(rel)
                addRedSphere(at: currentTransform)
            }
        }
    }

    // 赤球を追加 (記録時)
    func addRedSphere(at transform: simd_float4x4) {
        let anchor = ARAnchor(transform: transform)
        sceneView?.session.add(anchor: anchor)

        // アンカーのサイズを大きくする（半径 0.1）
        let sphere = SCNSphere(radius: 0.1)
        sphere.firstMaterial?.diffuse.contents = UIColor.red

        let node = SCNNode(geometry: sphere)
        node.simdTransform = transform

        // フェードインのみ（スケールアニメーションは削除）
        node.opacity = 0.0
        let fadeIn = SCNAction.fadeIn(duration: 0.5)
        node.runAction(fadeIn)

        sceneView?.scene.rootNode.addChildNode(node)
        recordingNodes.append(node)
    }

    // MARK: - Replay (青球)
    @objc func startReplayingHandler() {
        replayInitialTransform = sceneView?.session.currentFrame?.camera.transform
        isReplayingRoute = true
        placeReplayAnchors()
    }

    /// positionsを元に青球を配置し、replayAnchors配列に登録
    func placeReplayAnchors() {
        guard let initialTransform = replayInitialTransform else { return }

        let positions = viewModel.recordedPositions
        let n = positions.count
        if n == 0 { return }

        // 逆順ラベルで配置する例
        for (i, pos) in positions.enumerated() {
            // ワールド座標へ変換
            let tf = simd_float4x4.translation(
                x: initialTransform.columns.3.x + pos.x,
                y: initialTransform.columns.3.y + pos.y,
                z: initialTransform.columns.3.z + pos.z
            )
            let labelIndex = n - i  // 逆順ラベル

            addReplaySphere(at: tf, label: "\(labelIndex)")
        }
    }

    func addReplaySphere(at transform: simd_float4x4, label: String) {
        let anchor = ARAnchor(transform: transform)
        sceneView?.session.add(anchor: anchor)

        // アンカーのサイズを大きくする（半径 0.1）
        let sphere = SCNSphere(radius: 0.1)
        sphere.firstMaterial?.diffuse.contents = UIColor.blue

        let node = SCNNode(geometry: sphere)
        node.simdTransform = transform

        // フェードインのみ（スケールアニメーションは削除）
        node.opacity = 0.0
        let fadeIn = SCNAction.fadeIn(duration: 0.5)
        node.runAction(fadeIn)

        sceneView?.scene.rootNode.addChildNode(node)

        // 球体の上に数字を表示
        let textNode = makeTextNode(label)
        // Billboard制約を追加して、常にカメラに向くようにする（Y軸は固定）
        let billboardConstraint = SCNBillboardConstraint()
        billboardConstraint.freeAxes = [.Y]
        textNode.constraints = [billboardConstraint]

        // テキストのピボット調整で、底辺中央が原点になるように設定
        let (minBound, maxBound) = textNode.boundingBox
        let dx = (maxBound.x + minBound.x) / 2
        textNode.pivot = SCNMatrix4MakeTranslation(dx, minBound.y, 0)

        textNode.simdTransform = transform
        // 球体の半径0.1の上端に合わせて少し上に配置（必要に応じて調整）
        textNode.position.y += 0.11
        textNode.opacity = 0.0
        textNode.runAction(fadeIn)

        sceneView?.scene.rootNode.addChildNode(textNode)

        // replayAnchors に登録 (まだpassed=false)
        let spherePos = SCNVector3(transform.columns.3.x,
                                   transform.columns.3.y,
                                   transform.columns.3.z)
        let data = ReplayAnchorData(node: node,
                                    worldPos: spherePos,
                                    passed: false)
        replayAnchors.append(data)
    }

    func makeTextNode(_ label: String) -> SCNNode {
        let scnText = SCNText(string: label, extrusionDepth: 0.01)
        scnText.font = UIFont.systemFont(ofSize: 0.2)
        scnText.firstMaterial?.diffuse.contents = UIColor.white
        let textNode = SCNNode(geometry: scnText)
        return textNode
    }

    // MARK: - Cleanup / Reset
    @objc func deleteObjects() {
        guard let sceneView = sceneView else { return }
        sceneView.session.currentFrame?.anchors.forEach { sceneView.session.remove(anchor: $0) }
        recordingNodes.forEach { $0.removeFromParentNode() }
        replayAnchors.forEach { $0.node.removeFromParentNode() }
        recordingNodes.removeAll()
        replayAnchors.removeAll()
    }

    @objc func resetSession() {
        guard let sceneView = sceneView else { return }

        let config = ARWorldTrackingConfiguration()
        // LiDARオクルージョン
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.sceneReconstruction = .mesh
        }
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic

        sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])

        recordingNodes.forEach { $0.removeFromParentNode() }
        replayAnchors.forEach { $0.node.removeFromParentNode() }
        recordingNodes.removeAll()
        replayAnchors.removeAll()
        isReplayingRoute = false
    }

    // MARK: - Utility
    // カメラ位置→アンカー位置 の距離
    func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let dz = b.z - a.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }

    // simd版との距離計算
    func distance(from: simd_float4x4, to: simd_float4x4) -> Float {
        let dx = to.columns.3.x - from.columns.3.x
        let dy = to.columns.3.y - from.columns.3.y
        let dz = to.columns.3.z - from.columns.3.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
}

// MARK: - simd_float4x4 extension
extension simd_float4x4 {
    static func translation(x: Float, y: Float, z: Float) -> simd_float4x4 {
        var mat = matrix_identity_float4x4
        mat.columns.3.x = x
        mat.columns.3.y = y
        mat.columns.3.z = z
        return mat
    }
}


