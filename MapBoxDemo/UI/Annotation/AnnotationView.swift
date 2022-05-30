//
//  AnnotationView.swift
//  MapBoxDemo
//
//  Created by gannha on 23/05/2022.
//

import UIKit

class AnnotationView: UIView {
    typealias OnClickButton = (_ sender: UIButton, _ event: UIEvent) -> ()
    @IBOutlet private weak var contentView: UIView!
    @IBOutlet weak var title: UILabel!
    @IBOutlet weak var button: UIButton!
    var onClickButton: OnClickButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    convenience init() {
        self.init(frame: .zero)
    }
    
    private func setupView() {
        Bundle.main.loadNibNamed(String(describing: Self.self), owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = bounds
    }
    
    @IBAction func buttonTap(_ sender: UIButton, forEvent event: UIEvent) {
        onClickButton?(sender, event)
    }
}
