//
//  HapticFeedbackGenerator.swift
//  
//
//  Created by Wataru on 2024/7/23.
//

import Foundation
import UIKit

class HapticFeedbackGenerator {
    static func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }

    static func impact(type: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: type)
        generator.impactOccurred()
    }
}
