//
//  StatusEnum.swift
//
//
//  Created by Wataru on 2024/7/22.
//

import Foundation
import UIKit

public enum PlayStatus {
    case play
    case pause
}

enum TimeJumpType {
    case reverse
    case forward
}

/// 初始化 player 資料
/// parameters:
/// - videoUrl: 影片 url
/// - videoTitle: 影片名稱
/// - videoImageUrl: 影片圖片
/// - teacherName: 影片作者名
/// - defaultSeekTime: 影片播放進度
/// - defaultSpeed: 預設影片播放速度
/// - defaultSubtitle: 預設影片字幕設定
public struct PlayerConfiguration {
    public let videoUrl: String?
    public let videoData: Data?
    public let videoTitle: String
    public let videoImage: UIImage
    public let teacherName: String
    public let defaultSeekTime: Int
    public var defaultSpeed: Float
    public var defaultSubtitle: String?
    
    public init(videoUrl: String?, videoData: Data?, videoTitle: String, videoImage: UIImage, teacherName: String, defaultSeekTime: Int, defaultSpeed: Float, defaultSubtitle: String? = nil) {
        self.videoUrl = videoUrl
        self.videoData = videoData
        self.videoTitle = videoTitle
        self.videoImage = videoImage
        self.teacherName = teacherName
        self.defaultSeekTime = defaultSeekTime
        self.defaultSpeed = defaultSpeed
        self.defaultSubtitle = defaultSubtitle
    }
}
