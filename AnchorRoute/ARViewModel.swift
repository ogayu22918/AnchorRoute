import SwiftUI
import CoreData
import ARKit

class ARViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isReplaying = false
    @Published var savedRoutes: [RouteEntity] = []
    @Published var showingSaveError = false
    @Published var saveErrorMessage = ""

    var recordedPositions: [Coordinate] = []
    var initialPosition: simd_float4x4?
    var lastRecordedPosition: simd_float4x4?

    private let context: NSManagedObjectContext
    weak var sceneView: ARSCNView?

    init(context: NSManagedObjectContext) {
        self.context = context
        fetchSavedRoutes()
    }

    func startRecording() {
        NotificationCenter.default.post(name: .resetARSession, object: nil)
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }

    func fetchSavedRoutes() {
        let request: NSFetchRequest<RouteEntity> = RouteEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        do {
            savedRoutes = try context.fetch(request)
        } catch {
            saveErrorMessage = "データ取得に失敗: \(error.localizedDescription)"
            showingSaveError = true
        }
    }

    func startEnvironmentRecord() -> Data? {
        guard let sceneView = sceneView else { return nil }
        guard let frame = sceneView.session.currentFrame else { return nil }
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let ctx = CIContext()
        if let cgImage = ctx.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            return uiImage.jpegData(compressionQuality: 0.8)
        }
        return nil
    }

    func getWorldMapAndSave(
        positions: [Coordinate],
        name: String,
        linkedFeaturePrint: FeaturePrint?,
        startThumbnail: Data?,
        completion: @escaping (RouteEntity)->Void
    ) {
        guard let sceneView = sceneView else {
            self.saveErrorMessage = "シーンが利用できません。"
            self.showingSaveError = true
            return
        }

        sceneView.session.getCurrentWorldMap { worldMap, error in
            if let map = worldMap,
               let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true) {
                self.saveRoute(positions: positions,
                               worldMapData: data,
                               name: name,
                               linkedFeaturePrint: linkedFeaturePrint,
                               startThumbnail: startThumbnail,
                               completion: completion)
            } else {
                self.saveErrorMessage = "ワールドマップ取得に失敗しました。"
                self.showingSaveError = true
            }
        }
    }

    func saveRoute(
        positions: [Coordinate],
        worldMapData: Data?,
        name: String,
        linkedFeaturePrint: FeaturePrint?,
        startThumbnail: Data?,
        completion: @escaping (RouteEntity)->Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let encoder = JSONEncoder()
            do {
                let positionsData = try encoder.encode(positions)
                let newRoute = RouteEntity(context: self.context)
                newRoute.id = UUID()
                newRoute.name = name
                newRoute.timestamp = Date()
                newRoute.positions = positionsData
                newRoute.worldMapData = worldMapData
                newRoute.startThumbnail = startThumbnail

                if let fp = linkedFeaturePrint {
                    newRoute.featurePrint = fp
                }

                try self.context.save()

                DispatchQueue.main.async {
                    self.fetchSavedRoutes()
                    completion(newRoute)
                }
            } catch {
                DispatchQueue.main.async {
                    self.saveErrorMessage = "ルートの保存に失敗: \(error.localizedDescription)"
                    self.showingSaveError = true
                }
            }
        }
    }

    func loadWorldMap(_ worldMap: ARWorldMap) {
        guard let sceneView = sceneView else { return }
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func takeSnapshot() -> Data? {
        guard let sceneView = sceneView else { return nil }
        guard let frame = sceneView.session.currentFrame else { return nil }
        let ciImage = CIImage(cvPixelBuffer: frame.capturedImage)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            let uiImage = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
            return uiImage.jpegData(compressionQuality: 0.8)
        }
        return nil
    }

    func recordPosition(_ position: Coordinate) {
        recordedPositions.append(position)
    }

    func clearAnchors() {
        recordedPositions.removeAll()
        NotificationCenter.default.post(name: .deleteObjects, object: nil)
    }

    func waitUntilTrackingNormal(sceneView: ARSCNView, completion: @escaping () -> Void) {
        let checkInterval: TimeInterval = 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) {
            if let frame = sceneView.session.currentFrame {
                switch frame.camera.trackingState {
                case .normal, .limited(_):
                    completion()
                default:
                    self.waitUntilTrackingNormal(sceneView: sceneView, completion: completion)
                }
            } else {
                self.waitUntilTrackingNormal(sceneView: sceneView, completion: completion)
            }
        }
    }

    func deleteRoute(_ route: RouteEntity) {
        context.delete(route)
        do {
            try context.save()
            fetchSavedRoutes()
        } catch {
            saveErrorMessage = "削除に失敗: \(error.localizedDescription)"
            showingSaveError = true
        }
    }
}
