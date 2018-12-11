//
//  AttitudeViewController.swift
//  CognitoYourUserPoolsSample
//
//  Created by 中村拓 on 2018/12/10.
//  Copyright © 2018年 Dubal, Rohan. All rights reserved.
//

import UIKit
import CoreMotion

class AttitudeViewController: UIViewController {
    
    // 変数保持
    var acceleration_raw_x: Double? = 0.0
    var acceleration_raw_y: Double? = 0.0
    var acceleration_raw_z: Double? = 0.0
    
    // MotionManager
    let motionManager = CMMotionManager()
    
    @IBOutlet weak var acceleration_raw: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //contentsのサイズに合わせてobujectのサイズを変える
        self.acceleration_raw.sizeToFit()
        //表示可能最大行数を指定
        self.acceleration_raw.numberOfLines = 0
        
        if motionManager.isAccelerometerAvailable {
            // intervalの設定[sec]
            motionManager.accelerometerUpdateInterval = 0.2
            
            // センサー値の取得開始
            motionManager.startAccelerometerUpdates(
                to: OperationQueue.current!,
                withHandler: {(accelData: CMAccelerometerData?, errorOC: Error?) in self.outputAccelData(acceleration: accelData!.acceleration)
                    
            })

        }
        // Do any additional setup after loading the view.
    }
    
    func outputAccelData(acceleration: CMAcceleration){
        // 加速度センサー[G]
        self.acceleration_raw_x = acceleration.x
        self.acceleration_raw_y = acceleration.y
        self.acceleration_raw_z = acceleration.z
        self.acceleration_raw.text =
        "加速度_X: \(String(format: "%06f", acceleration.x))\n加速度_Y: \(String(format: "%06f", acceleration.y))\n加速度_Z: \(String(format: "%06f", acceleration.z))"
        
    }
    
    // センサー取得を止める関数
    func stopAccelerometor(){
        if(motionManager.isAccelerometerActive){
            motionManager.stopAccelerometerUpdates()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    


}
