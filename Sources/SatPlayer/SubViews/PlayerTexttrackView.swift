//
//  PlayerTexttrackView.swift
//
//
//  Created by Wataru on 2024/7/23.
//

import UIKit

class PlayerTexttrackView: UIView {
    
    private lazy var lbSubtitle = UILabel()
        .font(.systemFont(ofSize: 16))
        .textColor(.white)
        .textAlignment(.center)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = .black.withAlphaComponent(0.4)
        
        addSubview(lbSubtitle)
        lbSubtitle.snp.makeConstraints({
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8))
        })
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setSubtitle(_ subtitle: String) {
        lbSubtitle.text = subtitle
    }
}
