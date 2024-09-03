//
//  File.swift
//  
//
//  Created by User on 2024/7/22.
//

import Foundation
import MediaPlayer

protocol NowPlayingHelperDelegate: AnyObject {
    /// NowPlaying Info play / pause 點擊事件回調
    func playStatus(_ status: PlayStatus)
    /// NowPlaying Info slider var 拖曳事件回調
    func seekTime(_ seekTime: CMTime)
    /// NowPlaying Info next track 點擊事件回調
    func nextTrack()
    /// NowPlaying Info previous track 點擊事件回調
    func previousTrack()
}

class NowPlayingHelper {
    
    weak var delegate: NowPlayingHelperDelegate?
    
    private var nowPlayingInfo = [String: Any]()
    
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    // 更新當前播放進度
    func updateNowPlayingInfo(player: AVPlayer) {
        if let currentItem = player.currentItem {
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = CMTimeGetSeconds(currentItem.currentTime())
            nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = CMTimeGetSeconds(currentItem.duration)
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player.rate
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    func cleanData() {
        nowPlayingInfo = [:]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
//        commandCenter.playCommand.removeTarget(nil)
//        commandCenter.pauseCommand.removeTarget(nil)
//        commandCenter.nextTrackCommand.removeTarget(nil)
//        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
    }
    
    // Configure Media player now playing info
    func setNowPlayingInfo(config: PlayerConfiguration) {
        nowPlayingInfo[MPMediaItemPropertyTitle] = config.videoTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = config.teacherName
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue)
        
        var videoImage = config.videoImage
        DispatchQueue.main.async {
            self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: videoImage.size) { _ in
                return videoImage
            }
        }
        
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // Configure media player click action
    func setupRemoteTransportControls() {
        // Add handler for Play Command
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.delegate?.playStatus(.play)
            return .success
        }

        // Add handler for Pause Command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.delegate?.playStatus(.pause)
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
                        
            let newTime = CMTime(seconds: event.positionTime, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            self.delegate?.seekTime(newTime)
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.delegate?.nextTrack()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            guard let self = self else { return .commandFailed }
            self.delegate?.previousTrack()
            return .success
        }
    }
}
