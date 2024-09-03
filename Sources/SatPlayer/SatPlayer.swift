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
    public var isPlayFinish: (() -> Void)?
    
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
    private var defaultSpeed: Float = 1.0
    private var defaultSubtitle: String?
    private var subtitles = [Subtitle]()
    private var nowPlayingHelper = NowPlayingHelper()
    
    // Player Observer
    private var timeObserver: Any? = nil
    private var subTitleObserver: Any? = nil
    
    // Control Panel 顯示計時器
    private var inactivityTimer: Timer?
    private let inactivityInterval: TimeInterval = 3.0
    
    // 處理單擊 / 雙擊衝突延遲問題
    private var tapCount = 0
    private var tapTimer: Timer?
    
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
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
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
        
        // 監聽 AirPlay 切換事件
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        nowPlayingHelper.setupRemoteTransportControls()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Video buffer observe
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = playerItem else { return }
        if keyPath == "loadedTimeRanges" {
            guard let timeRanges = playerItem.loadedTimeRanges as? [NSValue] else { return }
            if let timeRange = timeRanges.first?.timeRangeValue {
                let bufferedTime = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
                let duration = CMTimeGetSeconds(playerItem.duration)
                let progress = bufferedTime / duration
                controlPanel.updateBufferProgress(bufferProgress: Float(progress))
            }
        }
        
        if keyPath == "status" {
            switch playerItem.status {
            case .readyToPlay:
                print("DEBUG: readyToPlay")
                // 設定影片播放進度
                setupDefaultSeekTime(second: defaultSeekTime)
                configureTextTrack(vttUrl: defaultSubtitle)
            case .failed:
                print("DEBUG: failed")
            case .unknown:
                viewModel.isLoading.accept(true)
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
     * defaultSpeed: 預設影片播放速度
     * defaultSubtitle: 預設影片字幕設定
     */
    public func initVideoPlayer(config: PlayerConfiguration) {
        self.defaultSeekTime = config.defaultSeekTime
        // 設定影片名稱
        controlPanel.setVideoTitle(config.videoTitle)
        // 設定影片
        if let videoData = config.videoData {
            setupLocalVideoData(data: videoData)
        } else if let videoUrl = config.videoUrl {
            setupVideoData(videoUrl: videoUrl)
        }

        // 設定鎖屏播放器資訊
        nowPlayingHelper.setNowPlayingInfo(config: config)
        nowPlayingHelper.delegate = self
        
        if let windowScene = self.window?.windowScene {
            let currentOrientation = windowScene.interfaceOrientation
            self.setDeviceOrientation(currentOrientation)
        }
        
        // 設定預設影片播放速度，當影片正在播放時才能設定，因此在 public func setupDefaultSeekTime(second: Int) 後執行
        self.defaultSpeed = config.defaultSpeed
        
        // 設定預設影片字幕，當影片 ready 後才能設定，
        // 因此在 override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
        // 當中的 status 監聽倒 readyToPlay 後執行
        self.defaultSubtitle = config.defaultSubtitle
    }
    
    /// 設定影片Url
    /// Parameters
    /// - videoUrl: 影片檔案連結
    public func setupVideoData(videoUrl: String) {
        self.playerLayer.isHidden = true
        // 設定影片資料
        playerItem = AVPlayerItem(
            asset: AVAsset(url: URL(string: videoUrl)!)
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
    public func setupDefaultSeekTime(second: Int) {
        player?.seek(to: CMTime(seconds: Double(second), preferredTimescale: CMTimeScale(NSEC_PER_SEC)), completionHandler: { _ in
            self.playerLayer.isHidden = false
            // 開始播放
            self.viewModel.isLoading.accept(false)
            self.viewModel.isControlHidden.accept(false)
            self.speedSetting(rate: self.defaultSpeed)
            self.setAirPlaySubtitle(show: self.isAirPlayConnected())
        })
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
        self.defaultSubtitle = vttUrl
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
        
        playerItem!.removeObserver(self, forKeyPath: "status")
        playerItem!.removeObserver(self, forKeyPath: "loadedTimeRanges")

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
    
    public func setPlayStatue(_ status: PlayStatus) {
        viewModel.playStatus.accept(status)
    }
    
    /// 重播當前影片
    public func replayVideo() {
        let newTime = CMTime(seconds: 0.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        self.viewModel.seekTime.accept(newTime)
        viewModel.playStatus.accept(.play)
        
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
                    self.frame = CGRect(x: 0, y: 56.paddingWithSafeArea(.top), width: UIScreen.main.bounds.width, height: 211.scale(.width))
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
            player.seek(to: seekTime) { _ in
                if self.viewModel.playStatus.value == .pause {
                    self.viewModel.playStatus.accept(.play)
                }
            }
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
            viewModel.isControlHidden.accept(false)
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
        
        controlPanel.previousTapped.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.playPrevious()
        }).disposed(by: disposeBag)

        controlPanel.nextTapped.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.nextTrack()
        }).disposed(by: disposeBag)
    }
    
    // Configure Tap Gesture
    func setupGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = self
        
        let press = UILongPressGestureRecognizer(target: self, action: #selector(handleViewLongPress))
        press.delegate = self
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        
        self.addGestureRecognizer(tap)
        self.addGestureRecognizer(doubleTap)
        self.addGestureRecognizer(press)
        self.addGestureRecognizer(pan)
        
        let sliderLongPress = UILongPressGestureRecognizer(target: self, action: #selector(handleSliderLongPress))
        sliderLongPress.minimumPressDuration = 0.05
        sliderLongPress.delegate = self
        controlPanel.sliderCoverView.addGestureRecognizer(sliderLongPress)
    }
    
    // 播放
    func play() {
        guard let player = player else { return }
        player.play()
        player.rate = defaultSpeed
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
        
        // 監聽是否播放完畢
        if durationTimeInSecond.isFinite {
            if Int(currentTimeInSecond) >= Int(durationTimeInSecond) { isPlayFinish?() }
        }
        
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
    
    // 快 / 倒轉點擊
    func timeJumpHelper(type: TimeJumpType) {
        guard let currentTime = self.player?.currentTime() else { return }
        let seekTime10Sec = CMTimeGetSeconds(currentTime).advanced(by: type == .forward ? 10 : -10)
        let seekTime = CMTime(value: CMTimeValue(seekTime10Sec), timescale: 1)
        self.viewModel.seekTime.accept(seekTime)
    }
    
    // 播放上一首
    func playPrevious() {
        guard let currentTime = player?.currentTime() else { return }
        let currentTimeInSecond = CMTimeGetSeconds(currentTime)
        
        if currentTimeInSecond < 5.0 {
            delegate?.previousTrack()
        } else {
            replayVideo()
        }
    }
    
    func setupLocalVideoData(data: Data) {
        if let fileURL = saveDataToTemporaryFile(data: data, fileName: "temporary_video.mp4") {
            print("DEBUG: setupLocalVideoData - \(fileURL)")
            // 設定影片資料
            playerItem = AVPlayerItem(
                asset: AVAsset(url: fileURL)
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
        } else {
            print("DEBUG: data nil")
        }
    }
            
    func saveDataToTemporaryFile(data: Data, fileName: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Failed to save data to temporary file: \(error.localizedDescription)")
            return nil
        }
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
            reverseSkeletonView.snp.remakeConstraints({
                $0.width.equalTo(screenWidth / 4)
                $0.top.left.bottom.equalToSuperview()
            })
            forwardSkeletonView.snp.remakeConstraints({
                $0.width.equalTo(screenWidth / 4)
                $0.top.right.bottom.equalToSuperview()
            })
        case .landscapeLeft:
            viewModel.orientation.accept(.landscapeLeft)
            reverseSkeletonView.snp.remakeConstraints({
                $0.width.equalTo(screenHeight / 4)
                $0.top.left.bottom.equalToSuperview()
            })
            forwardSkeletonView.snp.remakeConstraints({
                $0.width.equalTo(screenHeight / 4)
                $0.top.right.bottom.equalToSuperview()
            })
        case .landscapeRight:
            viewModel.orientation.accept(.landscapeRight)
            reverseSkeletonView.snp.remakeConstraints({
                $0.width.equalTo(screenHeight / 4)
                $0.top.left.bottom.equalToSuperview()
            })
            forwardSkeletonView.snp.remakeConstraints({
                $0.width.equalTo(screenHeight / 4)
                $0.top.right.bottom.equalToSuperview()
            })
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
        var content = String()
        if url.scheme == "file" {
            // 離線播放，讀取本地字幕
            do {
                let data = try String(contentsOf: URL(string: urlString)!)
                content = data
            } catch {
                print("Failed to load subtitles: \(error)")
            }
        } else {
            URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
                guard let self = self else { return }
                if let error = error {
                    print("Failed to load subtitles: \(error)")
                    return
                }

                guard let data = data, let data = String(data: data, encoding: .utf8) else { return }
                content = content
            }.resume()
        }
        
        let parser = WebVTTParser()
        self.subtitles = parser.parseVTT(content)
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
        // 處理單擊 / 雙擊衝突延遲問題
        tapCount += 1
        if tapCount == 1 {
            tapTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(handleTapTimeout), userInfo: nil, repeats: false)
        }
    }
    
    // 雙擊快轉 / 倒轉
    @objc func handleDoubleTap(_ sender: UITapGestureRecognizer) {
        // 處理單擊 / 雙擊衝突延遲問題
        tapCount = 0
        tapTimer?.invalidate()
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
                self.viewModel.isControlHidden.accept(true)
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
    
    // 處理單擊 / 雙擊衝突延遲問題
    @objc func handleTapTimeout() {
        if tapCount == 1 {
            viewModel.isControlHidden.accept(!viewModel.isControlHidden.value)
        }
        tapCount = 0
    }
    
    // 長按拖曳 Slider Bar
    @objc func handleViewLongPress(_ sender: UILongPressGestureRecognizer) {
        longPressHandler(sender: sender, setHapticFeedback: true)
    }
    
    // 設定 Slider Bar 長按拖曳
    @objc func handleSliderLongPress(_ sender: UILongPressGestureRecognizer) {
        longPressHandler(sender: sender, setHapticFeedback: false)
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
    
    private func longPressHandler(sender: UILongPressGestureRecognizer, setHapticFeedback: Bool) {
        switch sender.state {
        case .began:
            if setHapticFeedback {
                HapticFeedbackGenerator.notification(type: .success)
            }
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
}

// MARK: - AirPlay Control
private extension SatPlayer {
    // 監聽 AirPlay 切換事件
    @objc func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        viewModel.playStatus.accept(.pause)
        setAirPlaySubtitle(show: isAirPlayConnected())
    }
    
    // 判斷是否啟用 .m3u8 字幕
    func setAirPlaySubtitle(show: Bool) {
        guard let player = player, let currentItem = player.currentItem,
              let legibleGroup = currentItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else { return }
        if show {
            if let option = legibleGroup.options.first {
                currentItem.select(option, in: legibleGroup)
            }
        } else {
            // 尝试禁用字幕
            DispatchQueue.main.async {
                currentItem.select(nil, in: legibleGroup)
                let noSubtitlesOption = AVMediaSelectionOption()
                currentItem.select(noSubtitlesOption, in: legibleGroup)
                // 加入 play button 狀態切換機制，防止 AirPlay 選擇畫面未消失的狀態下 UI 無法更新問題
                self.controlPanel.changePlayButton(status: .play)
            }
        }
        viewModel.playStatus.accept(.play)
    }
    
    // 判斷當前是否啟用 AirPlay
    func isAirPlayConnected() -> Bool {
        let currentRoute = AVAudioSession.sharedInstance().currentRoute
        for output in currentRoute.outputs {
            if output.portType == .airPlay {
                return true
            }
        }
        return false
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
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // 檢查觸摸是否發生在按鈕上
        let touchView = touch.view
        if touchView == controlPanel.btnPlay ||
            touchView == controlPanel.btnPause ||
            touchView == controlPanel.btnNext ||
            touchView == controlPanel.btnPrevious ||
            touchView == controlPanel.btnAirplay ||
            touchView == controlPanel.btnSetting ||
            touchView == controlPanel.btnFullScreen {
            return false
        }
        return true
    }
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
        delegate?.nextTrack()
    }
    
    func previousTrack() {
        playPrevious()
    }
}
