//
//  Item.swift
//  Qenet
//
//  Created by Bikila Diriba on 3/5/26.
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
