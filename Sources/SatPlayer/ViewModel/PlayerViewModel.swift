//
//  PlayerViewModel.swift
//  
//
//  Created by Wataru on 2024/7/22.
//

import Foundation
import RxRelay
import UIKit
import AVFoundation

class PlayerViewModel {
    var playStatus = BehaviorRelay<PlayStatus>(value: .play)
    var isLoading = BehaviorRelay<Bool>(value: false)
    var deviceOrientation = BehaviorRelay<UIInterfaceOrientation>(value: .portrait)
    var isControlHidden = BehaviorRelay<Bool>(value: true)
    var orientation = BehaviorRelay<UIDeviceOrientation>(value: .portrait)
    var seekTime = BehaviorRelay<CMTime>(value: CMTime())
    var vttUrl = PublishRelay<String?>()
}
