//
//  Item.swift
//  FuelLanka
//
//  Created by Thisara Madhubashana Edirisingha on 2026-10-17.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
