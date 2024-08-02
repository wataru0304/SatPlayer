// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import AVFoundation
import AVKit
import RxSwift
import SatSwifty
import MediaPlayer

public protocol SatPlayerDelegate: AnyObject {
    /// NowPlaying Info next track 點擊事件回調
    func nextTrack()
    /// NowPlaying Info previous track 點擊事件回調
    func previousTrack()
    /// control panel 設定按鈕點擊事件回調
    func setting()
}

public class SatPlayer: UIView {
    
    // MARK: - Public Properties
    public weak var delegate: SatPlayerDelegate?
    
    // MARK: - Private Properteis
    private let disposeBag = DisposeBag()
    private let viewModel = PlayerViewModel()
    
    private let screenWidth = UIScreen.main.bounds.width
    private let screenHeight = UIScreen.main.bounds.height
    private var initialCenter: CGPoint?
    private var initialSliderValue: Float = 0.0
    private var initialTransform: CGAffineTransform = .identity

    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var playerLayer = AVPlayerLayer()
    private var defaultSeekTime: Int = 0
    private var subtitles = [Subtitle]()
    private var nowPlayingHelper = NowPlayingHelper()
    
    // Player Observer
    private var timeObserver: Any? = nil
    private var subTitleObserver: Any? = nil
    
    // Control Panel 顯示計時器
    private var inactivityTimer: Timer?
    private let inactivityInterval: TimeInterval = 3.0
    
    // MARK: - SubViews
    private lazy var loadingView: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        return ai
    }()
    
    private lazy var panelContrainer = UIView()
        .backgroundColor(.black.withAlphaComponent(0.3))
        .alpha(0)
    
    private lazy var controlPanel = ControlPanelView(viewModel: viewModel)
    
    private lazy var subtitleView = PlayerTexttrackView()
    
    // Anthor control
    private lazy var reverseSkeletonView = SkeletonView()
        .alpha(0)
    
    private lazy var lbReverse10sec = UILabel()
        .text("<< \n10 sec")
        .font(.systemFont(ofSize: 14))
        .textColor(.white.withAlphaComponent(0.8))
        .textAlignment(.center)
        .numberOfLines(2)
    
    private lazy var forwardSkeletonView = SkeletonView()
        .alpha(0)
    
    private lazy var lbForward10sec = UILabel()
        .text(">> \n10 sec")
        .font(.systemFont(ofSize: 14))
        .textColor(.white.withAlphaComponent(0.8))
        .textAlignment(.center)
        .numberOfLines(2)
        
    // Anthor control
    
    // MARK: - Lifecycle
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .black

        setupUI()
        bindViewModel()
        bindEvent()
        
        // 註冊應用進入背景和返回前景的通知
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        nowPlayingHelper.setupRemoteTransportControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Video buffer observe
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "loadedTimeRanges" {
            guard let timeRanges = playerItem!.loadedTimeRanges as? [NSValue] else { return }
            if let timeRange = timeRanges.first?.timeRangeValue {
                let bufferedTime = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
                let duration = CMTimeGetSeconds(playerItem!.duration)
                let progress = bufferedTime / duration
                controlPanel.updateBufferProgress(bufferProgress: Float(progress))
            }
        }
        
        if keyPath == "status" {
            switch playerItem?.status {
            case .readyToPlay:
                print("DEBUG: readyToPlay")
                // 設定影片播放進度
                setupDefaultSeekTime(second: defaultSeekTime)
                // 開始播放
                viewModel.isLoading.accept(false)
                play()
                viewModel.playStatus.accept(.play)
                viewModel.isControlHidden.accept(false)
            case .failed:
                print("DEBUG: failed")
            case .unknown:
                viewModel.isLoading.accept(true)                    
            case .none:
                print("DEBUG: none")
            case .some(_):
                print("DEBUG: some")
            }
            
        }
    }
    
    // MARK: - Public Helpers
    /// 設定 nowPlaying data
    /// parameters:
    /// - config: PlayerConfiguration
    /**
     * videoUrl: 影片 url
     * videoTitle: 影片名稱
     * videoImageUrl: 影片圖片
     * teacherName: 影片作者名
     * defaultSeekTime: 影片播放進度
     */
    public func initVideoPlayer(config: PlayerConfiguration) {
        self.defaultSeekTime = config.defaultSeekTime
        // 設定影片名稱
        controlPanel.setVideoTitle(config.videoTitle)
        // 設定影片
        setupVideoData(videoUrl: config.videoUrl)
        // 設定鎖屏播放器資訊
        nowPlayingHelper.setNowPlayingInfo(config: config)
        nowPlayingHelper.delegate = self
        
        switch UIDevice.current.orientation {
        case .portrait:
            self.setDeviceOrientation(.portrait)
        case .landscapeLeft:
            self.setDeviceOrientation(.landscapeLeft)
        case .landscapeRight:
            self.setDeviceOrientation(.landscapeRight)
        default:
            break
        }
        
    }
    
    /// 設定影片Url
    /// Parameters
    /// - videoUrl: 影片檔案連結
    public func setupVideoData(videoUrl: String) {
        // 設定影片資料
        playerItem = AVPlayerItem(
            asset: AVAsset(url: URL(string: videoUrl)!),
            automaticallyLoadedAssetKeys: [.tracks, .duration, .commonMetadata]
        )
        
        playerItem!.addObserver(self, forKeyPath: "loadedTimeRanges", options: [.new, .initial], context: nil)
        playerItem!.addObserver(self, forKeyPath: "status", options: [.new, .initial], context: nil)
        
        player = AVPlayer(playerItem: playerItem)
        player?.replaceCurrentItem(with: playerItem)
        playerLayer.player = player
        layer.insertSublayer(playerLayer, at: 0)

        // 判斷當前螢幕方向
        configurePlayerLayout(.portrait)
        setObserverToPlayer()
    }
    
    /// 設定歷史播放進度
    /// Parameters
    /// - defaultSeekTime: 影片播放進度
    public func setupDefaultSeekTime(defaultSeekTime: Float) {
        if defaultSeekTime > 0 {
                self.controlPanel.sliderBar.setValue(defaultSeekTime, animated: true)
                self.controlPanel.sliderBar.sendActions(for: .valueChanged)
        }
    }
    
    public func setupDefaultSeekTime(second: Int) {
        player?.seek(to: CMTime(seconds: Double(second), preferredTimescale: CMTimeScale(NSEC_PER_SEC)))
//        if defaultSeekTime > 0 {
//                self.controlPanel.sliderBar.setValue(defaultSeekTime, animated: true)
//                self.controlPanel.sliderBar.sendActions(for: .valueChanged)
//        }
    }
    
    /// 取得當前播放進度
    public func getCurrentProgress() -> Float {
        return controlPanel.sliderBar.value
    }
    
    public func getCurrentSecond() -> Int {
        guard let currentTime = player?.currentTime() else { return 0 }
        let currentTimeInSecond = CMTimeGetSeconds(currentTime)
        return Int(ceilf((Float(currentTimeInSecond))))
    }
    
    /// 設定字幕檔案
    /// Parameters
    /// - vttUrl: 字幕檔案 url，如果傳入 nil 或空字串，將會移除字幕、字幕 timer
    public func configureTextTrack(vttUrl: String?) {
        viewModel.vttUrl.accept(vttUrl)
    }
    
    /// 切換影片畫質
    /// Parameters
    /// - url: 影片 url 
    public func switchRendition(url: String, defaultSeekTime: Int) {
        self.defaultSeekTime = defaultSeekTime
        startLoading()
        setupVideoData(videoUrl: url)
    }
    
    /// 設定影片播放速度
    /// Parameters
    /// - rate: 影片播放速度
    public func speedSetting(rate: Float) {
        guard let player = player else { return }
        player.rate = rate
    }
    
    /// 清除 player 資料
    /// 切換影片、deinit 或 terminate...等，需要釋放 player 資源時使用
    public func cleanPlayerData() {
        guard let player = player else { return }
        viewModel.playStatus.accept(.pause)
        player.pause()
        player.replaceCurrentItem(with: nil)
        
        // 清除 timer 監聽
        if let _ = self.timeObserver {
            player.removeTimeObserver(self.timeObserver as Any)
            self.timeObserver = nil
        }
        
        if let _ = self.subTitleObserver {
            player.removeTimeObserver(self.subTitleObserver as Any)
            self.subTitleObserver = nil
        }
        
        viewModel.isControlHidden.accept(true)
        viewModel.seekTime.accept(CMTime())
        viewModel.vttUrl.accept(nil)

        // 清除 player data
        self.playerItem = nil
        self.playerLayer.player = nil
        self.player = nil
    }
    
    /// 清除 nowPlaying data
    public func cleanNowPlayingData() {   
        nowPlayingHelper.cleanData()
    }
    
    /// Start Loading
    public func startLoading() {
        viewModel.isLoading.accept(true)
    }
    /// Stop Loading
    public func stopLoading() {
        viewModel.isLoading.accept(false)
    }
    
    /// 隱藏/開啟控制選項
    /// Parameters
    /// - isHidden: 如果要讓控制物件隱藏則帶入 true, 反之 false
    public func controlPanelHidden(_ isHidden: Bool) {
        viewModel.isControlHidden.accept(isHidden)
    }
    
    /// 依照裝置方向調整 player view 轉向
    /// Parameters
    /// - orientation: 引用 UIInterfaceOrientation
    /// .unknown = 0
    /// .portrait = 1 // Device oriented vertically, home button on the bottom
    /// .portraitUpsideDown = 2 // Device oriented vertically, home button on the top
    /// .landscapeRight = 3 // Device oriented horizontally, home button on the left
    /// .landscapeLeft = 4 // Device oriented horizontally, home button on the right
    public func setDeviceOrientation(_ orientation: UIInterfaceOrientation) {
        viewModel.deviceOrientation.accept(orientation)
    }
}

// MARK: - Private Helpers
private extension SatPlayer {
    func setupUI() {
        // 設定中心起始點
        self.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        
        // Anthor control
        reverseSkeletonView.addSubview(lbReverse10sec)
        addSubview(reverseSkeletonView)
        forwardSkeletonView.addSubview(lbForward10sec)
        addSubview(forwardSkeletonView)
        
        lbReverse10sec.snp.makeConstraints({
            $0.center.equalToSuperview()
        })

        lbForward10sec.snp.makeConstraints({
            $0.center.equalToSuperview()
        })

        reverseSkeletonView.snp.makeConstraints({
            $0.width.equalTo(UIScreen.main.bounds.width / 4)
            $0.top.left.bottom.equalToSuperview()
        })
        forwardSkeletonView.snp.makeConstraints({
            $0.width.equalTo(UIScreen.main.bounds.width / 4)
            $0.top.right.bottom.equalToSuperview()
        })
        // Anthor control
        
        addSubview(subtitleView)
        
        panelContrainer.addSubview(controlPanel)
        panelContrainer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 211.scale(.height))
        addSubview(panelContrainer)
        addSubview(loadingView)
        
        controlPanel.snp.makeConstraints({
            $0.edges.equalToSuperview()
        })
   
        subtitleView.snp.makeConstraints({
            $0.bottom.equalToSuperview().inset(24)
            $0.centerX.equalToSuperview()
        })
        
        loadingView.snp.makeConstraints({
            $0.center.equalToSuperview()
        })
        
        setupGesture()
    }
    
    func bindViewModel() {
        viewModel.isLoading.subscribe(onNext: { [weak self] isLoading in
            guard let self = self else { return }
            if isLoading {
                self.loadingView.startAnimating()
            } else {
                self.loadingView.stopAnimating()
            }
        }).disposed(by: disposeBag)
        
        viewModel.playStatus.subscribe(onNext: { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .play:
                self.play()
            case .pause:
                self.pause()
            }
        }).disposed(by: disposeBag)
        
        viewModel.deviceOrientation.subscribe(onNext: { [weak self] orientation in
            guard let self = self else { return }
            switch orientation {
            case .portrait:
                UIView.animate(withDuration: 0.3) {
                    self.frame = CGRect(x: 0, y: 52.paddingWithSafeArea(.top), width: UIScreen.main.bounds.width, height: 211.scale(.width))
                }
            case .landscapeLeft, .landscapeRight:
                UIView.animate(withDuration: 0.3) {
                    self.frame = CGRect(x: 0, y: 0, width: self.screenHeight, height: self.screenWidth)
                }
            default:
                break
            }
            self.configurePlayerLayout(orientation)
        }).disposed(by: disposeBag)
        
        viewModel.isControlHidden.subscribe(onNext: { [weak self] isHidden in
            guard let self = self else { return }
            if isHidden {
                inactivityTimer?.invalidate()
                UIView.animate(withDuration: 0.2) {
                    self.panelContrainer.alpha = 0
                }
            } else {
                startInactivityTimer()
                UIView.animate(withDuration: 0.2) {
                    self.panelContrainer.alpha = 1
                }
            }
        }).disposed(by: disposeBag)
        
        viewModel.seekTime.subscribe(onNext: { [weak self] seekTime in
            guard let self = self, let player = self.player else { return }
            player.seek(to: seekTime)
        }).disposed(by: disposeBag)
        
        viewModel.vttUrl.subscribe(onNext: { [weak self] vttUrl in
            guard let self = self else { return }
            if let vttUrl = vttUrl {
                self.loadAndParseSubtitles(from: vttUrl)
                self.subTitleObserver = self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
                    self?.updateSubtitles(for: time.seconds)
                }
                self.subtitleView.isHidden = false
            } else {
                self.subtitles = []
                self.subtitleView.setSubtitle("")
                self.subtitleView.isHidden = true
            }
        }).disposed(by: disposeBag)
    }
    
    func bindEvent() {
        controlPanel.sliderValue.subscribe(onNext: { [weak self] value in
            guard let self = self, let duration = self.player?.currentItem?.duration else { return }
            let value = Float64(value) * CMTimeGetSeconds(duration)
            if value.isNaN == false {
                let seekTime = CMTime(value: CMTimeValue(value), timescale: 1)
                self.viewModel.seekTime.accept(seekTime)
            }
        }).disposed(by: disposeBag)
        
        controlPanel.settingTapped.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.setting()
        }).disposed(by: disposeBag)
        
        controlPanel.fullScreenTapped.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            guard let windowScene = self.window?.windowScene else { return }

            let currentOrientation = windowScene.interfaceOrientation
            switch currentOrientation {
            case .portrait:
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
                windowScene.requestGeometryUpdate(geometryPreferences) { error in
                    debugPrint("Error updating geometry: \(error.localizedDescription)")
                }
            default:
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                windowScene.requestGeometryUpdate(geometryPreferences) { error in
                    debugPrint("Error updating geometry: \(error.localizedDescription)")
                }
            }
        }).disposed(by: disposeBag)
        
        controlPanel.reverseTapped.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.isControlHidden.accept(false)
            self.timeJumpHelper(type: .reverse)
        }).disposed(by: disposeBag)

        controlPanel.forwardTapped.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.isControlHidden.accept(false)
            self.timeJumpHelper(type: .forward)
        }).disposed(by: disposeBag)
    }
    
    // Configure Tap Gesture
    func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        
//        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
//        doubleTap.numberOfTapsRequired = 2
//        doubleTap.delegate = self
                
//        tap.require(toFail: doubleTap)
        
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        press.delegate = self
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        
        self.addGestureRecognizer(tap)
//        self.addGestureRecognizer(doubleTap)
        self.addGestureRecognizer(press)
        self.addGestureRecognizer(pan)
    }
    
    // 播放
    func play() {
        guard let player = player else { return }
        player.play()
    }
    
    // 暫停
    func pause() {
        guard let player = player else { return }
        player.pause()
    }
    
    // 設定 Player's time observer
    func setObserverToPlayer() {
        let interval = CMTime(seconds: 1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main, using: { elapsed in
            self.updatePlayerTime()
            if let player = self.player {
                self.nowPlayingHelper.updateNowPlayingInfo(player: player)
            }
        })
    }
    
    // 根據 Time observer 的監聽更新 Slider & lbCurrentDuration
    func updatePlayerTime() {
        guard let currentTime = player?.currentTime() else { return }
        guard let duration = player?.currentItem?.duration else { return }
        
        let currentTimeInSecond = CMTimeGetSeconds(currentTime)
        let durationTimeInSecond = CMTimeGetSeconds(duration)
        
        controlPanel.updatePlayerTime(currentTimeInSecond: currentTimeInSecond,
                                            durationTimeInSecond: durationTimeInSecond)
        
        if let duration = player?.currentItem?.duration {
            let durationTimeInSecond = CMTimeGetSeconds(duration)
            if durationTimeInSecond.isFinite {
                controlPanel.setTotalTime("\(Int(durationTimeInSecond).secondToMS())")
            } else {
                controlPanel.setTotalTime("00:00")
            }
        } else {
            controlPanel.setTotalTime("00:00")
        }
    }
    
    // 快轉/倒轉點擊
    func timeJumpHelper(type: TimeJumpType) {
        guard let currentTime = self.player?.currentTime() else { return }
        let seekTime10Sec = CMTimeGetSeconds(currentTime).advanced(by: type == .forward ? 10 : -10)
        let seekTime = CMTime(value: CMTimeValue(seekTime10Sec), timescale: 1)
        self.viewModel.seekTime.accept(seekTime)
    }
}

// MARK: - 螢幕轉向 Helper
private extension SatPlayer {
    /// 依照螢幕方向 Resize, parameter: UIInterfaceOrientation
    func configurePlayerLayout(_ orientation: UIInterfaceOrientation) {
        playerLayer.videoGravity = .resizeAspect
        playerLayer.frame = self.bounds
        panelContrainer.frame = self.bounds
        
        switch orientation {
        case .portrait:
            viewModel.orientation.accept(.portrait)
        case .landscapeLeft:
            viewModel.orientation.accept(.landscapeLeft)
        case .landscapeRight:
            viewModel.orientation.accept(.landscapeRight)
        default:
            break
        }
        
        layoutIfNeeded()
    }
}

// MARK: - VTT Helper
private extension SatPlayer {
    // 讀取 VTT 檔案
    func loadAndParseSubtitles(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                print("Failed to load subtitles: \(error)")
                return
            }

            guard let data = data, let content = String(data: data, encoding: .utf8) else { return }
            let parser = WebVTTParser()
            self.subtitles = parser.parseVTT(content)
        }.resume()
    }
    
    // 依照播放進度更新字幕
    func updateSubtitles(for currentTime: TimeInterval) {
        let currentSubtitle = subtitles.first { currentTime >= $0.startTime && currentTime <= $0.endTime }
        subtitleView.setSubtitle(currentSubtitle?.text ?? "")
    }
}

// MARK: - Selectors
private extension SatPlayer {
    @objc func applicationDidEnterBackground() {
        // 解決：進入背景時 Media center 會與 AVPlayLayer 中的 Player 衝突，導致背景播放中斷問題
        playerLayer.player = nil
    }

    @objc func applicationWillEnterForeground() {
        // 解決：進入背景時 Media center 會與 AVPlayLayer 中的 Player 衝突，導致背景播放中斷問題
        playerLayer.player = player
    }
    
    // Player 控制面板顯示 / 消失
    @objc func handleSingleTap(_ sender: UITapGestureRecognizer) {
        viewModel.isControlHidden.accept(!viewModel.isControlHidden.value)
    }
    
    // 雙擊快轉 / 倒轉
    @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
        viewModel.isControlHidden.accept(false)
        let location = sender.location(in: sender.view)
        if let viewWidth = sender.view?.bounds.width {
            timeJumpHelper(type: location.x > viewWidth / 2 ? .forward : .reverse)
            UIView.animate(withDuration: 0.3) {
                if location.x > viewWidth / 2 {
                    self.forwardSkeletonView.alpha = 1
                } else {
                    self.reverseSkeletonView.alpha = 1
                }
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0.6) {
                    if location.x > viewWidth / 2 {
                        self.forwardSkeletonView.alpha = 0
                    } else {
                        self.reverseSkeletonView.alpha = 0
                    }
                }
            }
        }
    }
    
    // 長按拖曳 Slider Bar
    @objc func handleLongPress(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            HapticFeedbackGenerator.notification(type: .success)
            initialCenter = sender.location(in: self)
            initialSliderValue = controlPanel.sliderBar.value
            viewModel.playStatus.accept(.pause)
            viewModel.isControlHidden.accept(false)
        case .changed:
            let currentLocation = sender.location(in: self)
            let deltaX = currentLocation.x - initialCenter!.x
            let sliderWidth = controlPanel.sliderBar.frame.width
            let sliderRange = controlPanel.sliderBar.maximumValue - controlPanel.sliderBar.minimumValue
            let deltaValue = Float(deltaX / sliderWidth) * sliderRange
            
            controlPanel.sliderBar.value = initialSliderValue + deltaValue
            controlPanel.sliderBar.value = min(max(controlPanel.sliderBar.value, controlPanel.sliderBar.minimumValue), controlPanel.sliderBar.maximumValue)
            viewModel.isControlHidden.accept(false)
        case .ended:
            controlPanel.sliderBar.sendActions(for: .valueChanged)
            initialCenter = nil
            initialSliderValue = 0.0
            viewModel.playStatus.accept(.play)
            viewModel.isControlHidden.accept(false)
        default:
            break
        }
    }
    
    @objc func handlePan(_ sender: UIPanGestureRecognizer) {
        let translation = sender.translation(in: self)
        let horizontalTranslation = translation.x
        let verticalTranslation = translation.y

        // 判斷手勢是否為上下滑動
        if abs(horizontalTranslation) < abs(verticalTranslation) {
            guard let windowScene = self.window?.windowScene else { return }
            let currentOrientation = windowScene.interfaceOrientation
            
            switch sender.state {
            case .changed:
                if translation.y < 0 {
                    if currentOrientation == .portrait {
                        let scale = min(1.0 + abs(translation.y) / 200, 1.3)
                        self.transform = initialTransform.scaledBy(x: scale, y: scale)
                    }
                } else {
                    if currentOrientation == .landscapeLeft || currentOrientation == .landscapeRight {
                        // 由於中心起始點被設定為中下，因此全螢幕中心點計算要從螢幕寬開始計算
                        let newCenterY = screenWidth + translation.y / 2
                        self.center = CGPoint(x: screenHeight / 2, y: newCenterY)
                    }
                }
            case .ended:
                self.transform = initialTransform
                if translation.y < 0 {
                    if currentOrientation == .portrait {
                        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscapeRight)
                        windowScene.requestGeometryUpdate(geometryPreferences) { error in
                            debugPrint("Error updating geometry: \(error.localizedDescription)")
                        }
                    }
                } else {
                    if currentOrientation == .landscapeLeft || currentOrientation == .landscapeRight {
                        let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                        windowScene.requestGeometryUpdate(geometryPreferences) { error in
                            debugPrint("Error updating geometry: \(error.localizedDescription)")
                        }
                    }
                }
            default:
                break
            }
        }
    }
}

private extension SatPlayer {
    func startInactivityTimer() {
        // 如果计时器已经存在，先取消
        inactivityTimer?.invalidate()
        
        // 创建新的计时器
        inactivityTimer = Timer.scheduledTimer(timeInterval: inactivityInterval, target: self, selector: #selector(inactivityTimerFired), userInfo: nil, repeats: false)
    }
    
    @objc func inactivityTimerFired() {
        viewModel.isControlHidden.accept(true)
    }
}

extension SatPlayer: UIGestureRecognizerDelegate {
    // 允許多個手勢同時識別
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }
}

// MARK: - NowPlayingHelperDelegate
extension SatPlayer: NowPlayingHelperDelegate {
    func playStatus(_ status: PlayStatus) {
        viewModel.playStatus.accept(status)
    }
    
    func seekTime(_ seekTime: CMTime) {
        self.viewModel.seekTime.accept(seekTime)
    }
    
    func nextTrack() {
        print("DEBUG: next!!!")
        delegate?.nextTrack()
    }
    
    func previousTrack() {
        guard let currentTime = player?.currentTime() else { return }
        let currentTimeInSecond = CMTimeGetSeconds(currentTime)
        
        if currentTimeInSecond < 5.0 {
            delegate?.previousTrack()
        } else {
            let newTime = CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            self.viewModel.seekTime.accept(newTime)
        }
    }
}
