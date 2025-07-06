import Foundation
import CoreData
import Vision

class DataModel {
    static let shared = DataModel()
    let persistentContainer: NSPersistentContainer

    private init() {
        persistentContainer = PersistenceController.shared.container
    }

    func saveFeaturePrints(_ featurePrints: [VNFeaturePrintObservation],
                           name: String,
                           thumbnail: Data?) -> FeaturePrint? {
        let context = persistentContainer.viewContext
        let newFeaturePrint = FeaturePrint(context: context)
        newFeaturePrint.id = UUID()
        newFeaturePrint.name = name
        newFeaturePrint.timestamp = Date()
        newFeaturePrint.thumbnail = thumbnail

        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: featurePrints, requiringSecureCoding: true)
            newFeaturePrint.featureData = data
            try context.save()
            return newFeaturePrint
        } catch {
            print("Error saving feature prints: \(error)")
            return nil
        }
    }


    func loadFeaturePrints(featurePrint: FeaturePrint) -> [VNFeaturePrintObservation]? {
        guard let data = featurePrint.featureData else { return nil }
        do {
            if let fps = try NSKeyedUnarchiver.unarchivedObject(
                ofClasses: [NSArray.self, VNFeaturePrintObservation.self],
                from: data
            ) as? [VNFeaturePrintObservation] {
                return fps
            }
        } catch {
            print("Error loading feature prints: \(error)")
        }
        return nil
    }
}
