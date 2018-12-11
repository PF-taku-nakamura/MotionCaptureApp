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
    
    // EMAフィルター後データ変数保持
    var acceleration_EMA_X: Double? = 0.0
    var acceleration_EMA_Y: Double? = 0.0
    var acceleration_EMA_Z: Double? = 0.0
    let Alpha = 0.4
    //
    
    // MotionManager
    let motionManager = CMMotionManager()
    
    // 表示
    @IBOutlet weak var acceleration_raw: UILabel! // 生加速度
    @IBOutlet weak var acceleration_EMA: UILabel! // EMA(ローパス)加速度
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //contentsのサイズに合わせてobujectのサイズを変える
        self.acceleration_raw.sizeToFit()
        self.acceleration_EMA.sizeToFit()
        //表示可能最大行数を指定
        self.acceleration_raw.numberOfLines = 0
        self.acceleration_EMA.numberOfLines = 0
        
        if motionManager.isAccelerometerAvailable {
            // intervalの設定[sec]
            motionManager.accelerometerUpdateInterval = 0.1
            
            // センサー生の値の取得開始
            motionManager.startAccelerometerUpdates(
                to: OperationQueue.current!,
                withHandler: {(accelData: CMAccelerometerData?, errorOC: Error?) in self.outputAccelData(acceleration: accelData!.acceleration)
                    self.highpassFilter(acceleration: accelData!.acceleration)
            })
            
        }
        // Do any additional setup after loading the view.
    }
    
    func outputAccelData(acceleration: CMAcceleration){
        // 加速度センサー[G]
        self.acceleration_raw.text =
        "加速度_X: \(String(format: "%06f", acceleration.x))\n加速度_Y: \(String(format: "%06f", acceleration.y))\n加速度_Z: \(String(format: "%06f", acceleration.z))"
    }
    
    func highpassFilter(acceleration: CMAcceleration){
        acceleration_EMA_X = Alpha*acceleration.x + acceleration_EMA_X!*(1.0-Alpha)
        acceleration_EMA_Y = Alpha*acceleration.y + acceleration_EMA_Y!*(1.0-Alpha)
        acceleration_EMA_Z = Alpha*acceleration.z + acceleration_EMA_Z!*(1.0-Alpha)
        
        // ハイパス後の値
        let xh = acceleration.x - acceleration_EMA_X!
        let yh = acceleration.y - acceleration_EMA_Y!
        let zh = acceleration.z - acceleration_EMA_Z!
        self.acceleration_EMA.text = "加速度_ハイパス_X: \(String(format: "%06f", xh))\n加速度_ハイパス_Y: \(String(format: "%06f", yh))\n加速度_ハイパス_Z: \(String(format: "%06f", zh))"
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
