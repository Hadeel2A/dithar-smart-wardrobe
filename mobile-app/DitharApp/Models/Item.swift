//
//  Item.swift
//  DitharApp
//
//  Created by Hadeel Almutairi on 22/04/1447 AH.
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
