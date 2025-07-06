//
//  FeaturePrint+CoreDataProperties.swift
//  AnchorRoute
//
//  Created by 小川悠 on 2024/12/16.
//
//

import Foundation
import CoreData


extension FeaturePrint {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FeaturePrint> {
        return NSFetchRequest<FeaturePrint>(entityName: "FeaturePrint")
    }

    @NSManaged public var featureData: Data?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var timestamp: Date?
    @NSManaged public var thumbnail: Data?
    @NSManaged public var route: RouteEntity?

}

extension FeaturePrint : Identifiable {

}
