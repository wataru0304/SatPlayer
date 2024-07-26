//
//  StatusEnum.swift
//
//
//  Created by Wataru on 2024/7/22.
//

import Foundation

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
    public let videoTitle: String
    public let videoImageUrl: String
    public let teacherName: String
    public let defaultSeekTime: Float
    
    public init(videoUrl: String, videoTitle: String, videoImageUrl: String, teacherName: String, defaultSeekTime: Float) {
        self.videoUrl = videoUrl
        self.videoTitle = videoTitle
        self.videoImageUrl = videoImageUrl
        self.teacherName = teacherName
        self.defaultSeekTime = defaultSeekTime
    }
}
