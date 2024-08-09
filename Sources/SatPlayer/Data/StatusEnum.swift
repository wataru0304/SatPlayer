//
//  StatusEnum.swift
//
//
//  Created by Wataru on 2024/7/22.
//

import Foundation
import UIKit

enum PlayStatus {
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
public struct PlayerConfiguration {
    public let videoUrl: String
    public let videoData: Data?
    public let videoTitle: String
    public let videoImage: UIImage
    public let teacherName: String
    public let defaultSeekTime: Int
    
    public init(videoUrl: String, videoData: Data?, videoTitle: String, videoImage: UIImage, teacherName: String, defaultSeekTime: Int) {
        self.videoUrl = videoUrl
        self.videoData = videoData
        self.videoTitle = videoTitle
        self.videoImage = videoImage
        self.teacherName = teacherName
        self.defaultSeekTime = defaultSeekTime
    }
}
