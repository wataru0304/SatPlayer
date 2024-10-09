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
        
        // 過濾 html 標籤
        lbSubtitle.text = replaceHTMLTag(value: subtitle)
    }
    
    func replaceHTMLTag(value: String) -> String {
        if let data = value.data(using: .utf8) {
            if let attributedString = try? NSAttributedString(data: data,
                                                              options: [.documentType: NSAttributedString.DocumentType.html,
                                                                        .characterEncoding: String.Encoding.utf8.rawValue],
                                                              documentAttributes: nil) {
                let plainText = attributedString.string
                return plainText
            }
        }
        return value
    }
}
