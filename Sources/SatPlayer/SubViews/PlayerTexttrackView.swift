//
//  PlayerTexttrackView.swift
//
//
//  Created by Wataru on 2024/7/23.
//

import UIKit

class PlayerTexttrackView: UIView {
    
    private lazy var lbSubtitle = UILabel()
        .font(.systemFont(ofSize: UIDevice.current.userInterfaceIdiom == .phone ? 16 : 28))
        .textColor(.white)
        .textAlignment(.center)
        .numberOfLines(0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .black.withAlphaComponent(0.4)
        
        addSubview(lbSubtitle)
        lbSubtitle.snp.makeConstraints({
            $0.width.lessThanOrEqualTo(UIScreen.main.bounds.width - 40)
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSubtitle(_ subtitle: String) {
        // 字幕為空要隱藏
        self.isHidden = subtitle.isEmpty
        
        // 部分課程字幕因不明原因，會出現 <b>, </b> 標籤，因此需手動排除不明標籤
        lbSubtitle.text = subtitle.replacingOccurrences(of: "<b>", with: "").replacingOccurrences(of: "</b>", with: "")
    }
}
