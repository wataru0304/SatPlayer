//
//  File.swift
//  
//
//  Created by User on 2024/7/22.
//

import UIKit

extension CGFloat {
    enum PaddingType {
        case top, bottom
    }
    enum ScaleType {
        case height, width
    }

    private static var heightRatio = UIScreen.main.bounds.height / 812.0
    private static var widthRatio = UIScreen.main.bounds.width / 375.0
    private static var safeAreaTop = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0
    private static var safeAreaBottom = UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0

    func scale(_ type: ScaleType) -> CGFloat {
        switch type {
        case .height:
            return (self * CGFloat.heightRatio)
        case .width:
            return (self * CGFloat.widthRatio)
        }
    }

    func paddingWithSafeArea(_ type: PaddingType) -> CGFloat {
        switch type {
        case .top:
            return (self + CGFloat.safeAreaTop)
        case .bottom:
            return (self + CGFloat.safeAreaBottom)
        }
    }
}

extension Double {
    func scale(_ type: CGFloat.ScaleType) -> CGFloat {
        return CGFloat(self).scale(type)
    }
    func paddingWithSafeArea(_ type: CGFloat.PaddingType) -> CGFloat {
        return CGFloat(self).paddingWithSafeArea(type)
    }
}

extension Int {
    func scale(_ type: CGFloat.ScaleType) -> CGFloat {
        return Double(self).scale(type)
    }
    func paddingWithSafeArea(_ type: CGFloat.PaddingType) -> CGFloat {
        return CGFloat(self).paddingWithSafeArea(type)
    }
}
