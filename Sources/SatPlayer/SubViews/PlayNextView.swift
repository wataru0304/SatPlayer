//
//  File.swift
//  
//
//  Created by User on 2024/9/23.
//

import UIKit

class PlayNextView: UIView {
    
    // MARK: - Properties
    var timeLeftShapeLayer = CAShapeLayer()
    var bgShapeLayer = CAShapeLayer()
    var timeLeft: TimeInterval = 6
    var endTime: Date?
    var timer = Timer()
    let strokeIt = CABasicAnimation(keyPath: "strokeEnd")
    
    var playHandler: (() -> Void)?
    var replayHandler: (() -> Void)?
    
    // MARK: - SubViews
    private lazy var lbPlayNext = UILabel()
        .text("自動播放下一單元")
        .font(.systemFont(ofSize: 14, weight: .medium))
        .textColor(.white)
    
    private lazy var playBgView = UIView()
        .backgroundColor(.clear)
    
    private lazy var ivPlay: UIImageView = {
        let iv = UIImageView()
        iv.image = loadImage(named: "play")!.withRenderingMode(.alwaysTemplate)
        iv.tintColor = .white
        iv.contentMode = .scaleAspectFill
        iv.isUserInteractionEnabled = true
        let imgTap = UITapGestureRecognizer(target: self, action: #selector(playBtnClicked))
        iv.addGestureRecognizer(imgTap)
        return iv
    }()
        
    private lazy var btnReplay = UIButton()
        .title("再看一次", for: .normal)
        .font(.systemFont(ofSize: 14, weight: .medium))
        .titleColor(.white, for: .normal)
        .target(self, action: #selector(replayBtnClicked), for: .touchUpInside)
    
    // MARK: - Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupUI()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.createCircle()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Public Helpers
    func createCircle() {
        playBgView.backgroundColor = .clear
        drawBgShape()
        drawTimeLeftShape()
        strokeIt.fromValue = 0
        strokeIt.toValue = 1
        strokeIt.duration = 6
        timeLeftShapeLayer.add(strokeIt, forKey: nil)
        endTime = Date().addingTimeInterval(timeLeft)
        
        let startTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updateTime), userInfo: nil, repeats: true)
        timer = startTimer
        RunLoop.main.add(startTimer, forMode: .common)
    }
    
    func stopTimer() {
        timer.invalidate()
    }
}

// MARK: - Private Helpers
private extension PlayNextView {
    func setupUI() {
        backgroundColor = .clear

        addSubview(lbPlayNext)
        playBgView.addSubview(ivPlay)
        addSubview(playBgView)
        addSubview(btnReplay)
        
        lbPlayNext.snp.makeConstraints({
            $0.top.left.right.equalToSuperview()
        })
        
        ivPlay.snp.makeConstraints({
            $0.size.equalTo(17)
            $0.center.equalToSuperview()
        })
        
        playBgView.snp.makeConstraints({
            $0.size.equalTo(56)
            $0.top.equalTo(lbPlayNext.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
        })
        
        btnReplay.snp.makeConstraints({
            $0.top.equalTo(playBgView.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview()
        })
    }
    
    func drawBgShape() {
        bgShapeLayer = createLayerPath(color: .white.withAlphaComponent(0.2))
        playBgView.layer.addSublayer(bgShapeLayer)
    }
    
    func drawTimeLeftShape() {
        timeLeftShapeLayer = createLayerPath(color: .white)
        playBgView.layer.addSublayer(timeLeftShapeLayer)
    }
    
    func createLayerPath(color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.path = UIBezierPath(arcCenter: CGPoint(x: playBgView.bounds.midX , y: playBgView.bounds.midY),
                                  radius: 22,
                                  startAngle: -90.degreesToRadians,
                                  endAngle: 270.degreesToRadians,
                                  clockwise: true).cgPath
        layer.strokeColor = color.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 4
        return layer
    }
}

// MARK: - Selectors
private extension PlayNextView {
    @objc func updateTime() {
        if timeLeft > 0 {
            timeLeft = endTime?.timeIntervalSinceNow ?? 0
        } else {
            timer.invalidate()
            playHandler?()
        }
    }
    
    @objc func playBtnClicked() {
        timer.invalidate()
        playHandler?()
    }
    
    @objc func replayBtnClicked() {
        timer.invalidate()
        replayHandler?()
    }
}

extension Int {
    var degreesToRadians : CGFloat {
        return CGFloat(self) * .pi / 180
    }
}
