import Foundation
import CoreData

extension RouteEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<RouteEntity> {
        return NSFetchRequest<RouteEntity>(entityName: "RouteEntity")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var positions: Data?
    @NSManaged public var worldMapData: Data?
    @NSManaged public var featurePrint: FeaturePrint?
    @NSManaged public var docID: String? 
    @NSManaged public var startThumbnail: Data?
}

extension RouteEntity : Identifiable {
}
