//
//  ViewController.swift
//  SphereView
//
//  Created by Noah Plützer on 23.08.24.
//

import UIKit

class ViewController: UIViewController {
    
    private let numberOfSphereElements = 100
    private let sphereView = SphereView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(sphereView)
        sphereView.frame = view.frame
        
        sphereView.sphereRadius = 150
        sphereView.scrollSensitivity = 0.005
        
        for _ in 0...numberOfSphereElements {
            let elementView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 50, height: 50)))
            elementView.backgroundColor = .orange
            elementView.layer.cornerRadius = 25
            sphereView.contentView.addSubview(elementView)
        }
    }
}

