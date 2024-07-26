//
//  ControlPanelView.swift
//
//
//  Created by Wataru on 2024/7/22.
//

import UIKit
import AVFoundation
import AVKit
import SnapKit
import SatSwifty
import RxSwift
import RxRelay
import RxCocoa

func loadImage(named: String) -> UIImage? {
    return UIImage(named: named, in: .module, compatibleWith: nil)
}

class ControlPanelView: UIView {
    
    // MARK: - Properties
    let disposeBag = DisposeBag()
    var viewModel: PlayerViewModel
    
    var sliderValue = BehaviorRelay<Float>(value: 0.0)
    
    var settingTapped: ControlEvent<Void> {
        return btnSetting.rx.tap
    }
    
    var playTapped: ControlEvent<Void> {
        return btnPlay.rx.tap
    }
    
    var reverseTapped: ControlEvent<Void> {
        return btnReverse.rx.tap
    }
    
    var forwardTapped: ControlEvent<Void> {
        return btnForward.rx.tap
    }
    
    var fullScreenTapped: ControlEvent<Void> {
        return btnFullScreen.rx.tap
    }
    
    // MARK: - SubViews
    // header
    private lazy var lbTitle = UILabel()
        .text("單元名稱至多一行單元名稱至多一行單元名稱至多一行單元名稱至多一行單元名稱至多一行單元名稱至多一行")
        .font(.systemFont(ofSize: 14))
        .numberOfLines(1)
        .textColor(.white)
    
    private lazy var btnAirplay: AVRoutePickerView = {
        let rp = AVRoutePickerView()
        rp.activeTintColor = .white
        rp.tintColor = .white
        return rp
    }()
    
    private lazy var btnSetting = UIButton()
        .image(loadImage(named: "setting")!.withRenderingMode(.alwaysTemplate), for: .normal)
        .tintColor(.white)
    // header
    
    // Control Button
    private lazy var btnReverse = UIButton()
        .image(loadImage(named: "backward")!.withRenderingMode(.alwaysTemplate), for: .normal)
        .tintColor(.white)
    
    private lazy var btnPlay = UIButton()
        .image(loadImage(named: "play")!.withRenderingMode(.alwaysTemplate), for: .normal)
        .tintColor(.white)
        .backgroundColor(.black.withAlphaComponent(0.2))
        .cornerRadius(24)
    
    private lazy var btnPause = UIButton()
        .image(loadImage(named: "pause")!.withRenderingMode(.alwaysTemplate), for: .normal)
        .tintColor(.white)
        .backgroundColor(.black.withAlphaComponent(0.2))
        .cornerRadius(24)
        .isHidden(true)
    
    private lazy var btnForward = UIButton()
        .image(loadImage(named: "forward")!.withRenderingMode(.alwaysTemplate), for: .normal)
        .tintColor(.white)
    // Control Button
    
    // footer
    private lazy var lbCurrentDuration = UILabel()
        .text("--:--")
        .font(.systemFont(ofSize: 12))
        .textColor(.white)
    
    lazy var sliderBar: UISlider = {
        let sb = UISlider()
        sb.tintColor = #colorLiteral(red: 0, green: 0.3607843137, blue: 1, alpha: 1)
        sb.minimumTrackTintColor = #colorLiteral(red: 0.2, green: 0.4901960784, blue: 1, alpha: 1)
        sb.maximumTrackTintColor = .white
        sb.setThumbImage(loadImage(named: "sliderThumb")!, for: .normal)
        sb.addTarget(self, action: #selector(handleSliderValueChange(_:)), for: .valueChanged)
        return sb
    }()
    
    private lazy var lbTotalDuration = UILabel()
        .text("--:--")
        .font(.systemFont(ofSize: 12))
        .textColor(.white)
    
    private lazy var progressStack = UIStackView(arrangedSubviews: [lbCurrentDuration, sliderBar, lbTotalDuration])
        .axis(.horizontal)
        .spacing(6)
        .alignment(.center)
    
    private lazy var btnFullScreen = UIButton()
        .image(loadImage(named: "fullScreen")!.withRenderingMode(.alwaysTemplate), for: .normal)
        .tintColor(.white)
    // footer
    
    // MARK: - Lifecycle
    init(viewModel: PlayerViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        
        setupUI()
        bindViewModel()
        bindEvent()
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Helpers
    func setVideoTitle(_ title: String) {
        lbTitle.text = title
    }
    
    func setTotalTime(_ value: String) {
        lbTotalDuration.text = value
    }
    
    func updatePlayerTime(currentTimeInSecond: Float64, durationTimeInSecond: Float64) {
        sliderBar.value = Float(currentTimeInSecond / durationTimeInSecond)
        lbCurrentDuration.text = "\(Int(currentTimeInSecond).secondToMS())"
    }
}

// MARK: - Private Helpers
private extension ControlPanelView {
    func setupUI() {
        // Header
        addSubview(btnSetting)
        addSubview(btnAirplay)
        addSubview(lbTitle)
        
        btnSetting.snp.makeConstraints({
            $0.top.right.equalToSuperview().inset(12)
        })
        btnAirplay.snp.makeConstraints({
            $0.centerY.equalTo(btnSetting)
            $0.right.equalTo(btnSetting.snp.left).offset(-12)
        })
        lbTitle.snp.makeConstraints({
            $0.left.equalToSuperview().inset(12)
            $0.right.equalTo(btnSetting.snp.left).offset(-87)
            $0.centerY.equalTo(btnSetting.snp.centerY)
        })
        // Header

        // Control Button
        let btnStack = UIStackView(arrangedSubviews: [btnReverse, btnPlay, btnPause, btnForward])
            .axis(.horizontal)
            .spacing(32)
            .alignment(.center)

        addSubview(btnStack)
        btnPlay.snp.makeConstraints({
            $0.size.equalTo(48)
        })
        btnPause.snp.makeConstraints({
            $0.size.equalTo(48)
        })
        btnStack.snp.makeConstraints({
            $0.center.equalToSuperview()
        })
        // Control Button

        // Footer
        addSubview(btnFullScreen)
        addSubview(progressStack)

        btnFullScreen.snp.makeConstraints({
            $0.bottom.right.equalToSuperview().inset(12)
        })
        progressStack.snp.makeConstraints({
            $0.centerY.equalTo(btnFullScreen.snp.centerY)
            $0.left.equalToSuperview().inset(12)
            $0.right.equalTo(btnFullScreen.snp.left).offset(-12)
        })
        // Footer
    }
    
    func bindViewModel() {
        viewModel.orientation.subscribe(onNext: { [weak self] orientation in
            guard let self = self else { return }
            switch orientation {
            case .portrait:
                btnSetting.snp.remakeConstraints({
                    $0.top.right.equalToSuperview().inset(12)
                })
                lbTitle.snp.remakeConstraints({
                    $0.width.lessThanOrEqualTo(240.scale(.width))
                    $0.left.equalToSuperview().inset(12)
                    $0.centerY.equalTo(self.btnSetting.snp.centerY)
                })
                btnFullScreen.snp.remakeConstraints({
                    $0.bottom.right.equalToSuperview().inset(12)
                })
                progressStack.snp.remakeConstraints({
                    $0.centerY.equalTo(self.btnFullScreen.snp.centerY)
                    $0.left.equalToSuperview().inset(12)
                    $0.right.equalTo(self.btnFullScreen.snp.left).offset(-12)
                })
            case .landscapeLeft, .landscapeRight:
                btnSetting.snp.remakeConstraints({
                    $0.top.equalToSuperview().inset(20)
                    $0.right.equalToSuperview().inset(60)
                })
                lbTitle.snp.remakeConstraints({
                    $0.width.lessThanOrEqualTo(400.scale(.width))
                    $0.left.equalToSuperview().inset(60)
                    $0.centerY.equalTo(self.btnSetting.snp.centerY)
                })
                btnFullScreen.snp.remakeConstraints({
                    $0.bottom.equalToSuperview().inset(24)
                    $0.right.equalToSuperview().inset(60)
                })
                progressStack.snp.remakeConstraints({
                    $0.centerY.equalTo(self.btnFullScreen.snp.centerY)
                    $0.left.equalToSuperview().inset(60)
                    $0.right.equalTo(self.btnFullScreen.snp.left).offset(-12)
                })
            default:
                break
            }
        }).disposed(by: disposeBag)
        
        viewModel.playStatus.subscribe(onNext: { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .play:
                self.btnPlay.isHidden = true
                self.btnPause.isHidden = false
            case .pause:
                self.btnPlay.isHidden = false
                self.btnPause.isHidden = true
            }
        }).disposed(by: disposeBag)
    }
    
    func bindEvent() {
        btnPlay.rx.tap.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.playStatus.accept(.play)
        }).disposed(by: disposeBag)
        
        btnPause.rx.tap.subscribe(onNext: { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.playStatus.accept(.pause)
        }).disposed(by: disposeBag)
    }
    
    @objc func handleSliderValueChange(_ sender: UISlider) {
        sliderValue.accept(sender.value)
    }
}
