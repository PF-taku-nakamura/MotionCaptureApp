//
//  GameScene.swift
//  CognitoYourUserPoolsSample
//
//  Created by 中村拓 on 2018/12/13.
//  Copyright © 2018年 Dubal, Rohan. All rights reserved.
//

import SceneKit

class GameScene: SCNScene {
    
    override init() {
        super.init()
        self.setUpScene()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setUpScene() {
        
        // iPhone
        let box:SCNGeometry = SCNBox(width: 1, height: 2, length: 3, chamferRadius: 0.4)
        let geometryNode = SCNNode(geometry: box)
        // iPhoneをオイラー角で回転
        let d = 30.0 * Double(Float.pi / 180)
        geometryNode.eulerAngles = SCNVector3(d, d, 0)
        // iPhoneの描画
        self.rootNode.addChildNode(geometryNode)
        
        // オムニライト
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        self.rootNode.addChildNode(lightNode)
        
        // アンビエント ライト
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        self.rootNode.addChildNode(ambientLightNode)
        
        // カメラ
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 10)
        self.rootNode.addChildNode(cameraNode)
        
    }
    
}
