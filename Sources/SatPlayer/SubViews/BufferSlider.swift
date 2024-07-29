//
//  File.swift
//  
//
//  Created by User on 2024/7/29.
//

import UIKit

class BufferSlider: UISlider {
    var bufferProgress: Float = 0.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.trackRect(forBounds: bounds)
        rect.size.height = 4 // 设置轨道高度
        return rect
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let bufferWidth = CGFloat(bufferProgress) * rect.width
        let bufferRect = CGRect(x: rect.origin.x + 4, y: rect.height / 2 - 2, width: bufferWidth, height: 4)
        
        context.setFillColor(UIColor.lightGray.cgColor)
        context.fill(bufferRect)
    }
}
