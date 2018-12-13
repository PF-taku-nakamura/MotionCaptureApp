//
//  AttitudeViewController.swift
//  CognitoYourUserPoolsSample
//
//  Created by 中村拓 on 2018/12/10.
//  Copyright © 2018年 Dubal, Rohan. All rights reserved.
//

import UIKit
import CoreMotion
import SceneKit

class AttitudeViewController: UIViewController {
    
    // EMAフィルター後データ変数保持
    var acceleration_EMA_X: Double? = 0.0
    var acceleration_EMA_Y: Double? = 0.0
    var acceleration_EMA_Z: Double? = 0.0
    let Alpha = 0.4
    
    // MotionManager
    let motionManager = CMMotionManager()
    
    // 表示
    @IBOutlet weak var acceleration_raw: UILabel! // 生加速度
    @IBOutlet weak var acceleration_highpass: UILabel! // EMA(ローパス)加速度
    @IBOutlet weak var geomagnetism_raw: UILabel! // 生地磁気
    @IBOutlet weak var gyroscope_raw: UILabel! // 生ジャイロ
    @IBOutlet weak var attitude_raw: UILabel! // ヨーピッチロール
    @IBOutlet weak var attitude_view: SCNView! // ヨーピッチロールを表示するView
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //contentsのサイズに合わせてobujectのサイズを変える
        self.acceleration_raw.sizeToFit()
        self.acceleration_highpass.sizeToFit()
        self.geomagnetism_raw.sizeToFit()
        self.gyroscope_raw.sizeToFit()
        self.attitude_raw.sizeToFit()
        //表示可能最大行数を指定
        self.acceleration_raw.numberOfLines = 0
        self.acceleration_highpass.numberOfLines = 0
        self.geomagnetism_raw.numberOfLines = 0
        self.gyroscope_raw.numberOfLines = 0
        self.attitude_raw.numberOfLines = 0
        
        if motionManager.isAccelerometerAvailable {
            // intervalの設定[sec]
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.magnetometerUpdateInterval = 0.1
            motionManager.gyroUpdateInterval = 0.1
            
            // 加速度センサー値の取得開始
            motionManager.startAccelerometerUpdates(
                to: OperationQueue.current!,
                withHandler: {(accelData: CMAccelerometerData?, errorOC: Error?) in self.outputAccelData(acceleration: accelData!.acceleration)
                    self.highpassFilter(acceleration: accelData!.acceleration)
            })
            // 地磁気センサー値の取得開始
            motionManager.startMagnetometerUpdates(
                to: OperationQueue.current!,
                withHandler: {(magnetoData: CMMagnetometerData?, errorOC: Error?) in self.outputMagnetoData(geomagnetism: magnetoData!.magneticField)
            })
            // ジャイロセンサー値の取得開始
            motionManager.startGyroUpdates(
                to:OperationQueue.current!,
                withHandler: {(gyroData: CMGyroData?, errorOC: Error?) in self.outputGyroData(gyro: gyroData!.rotationRate)
            })
            // ヨーピッチロール値の取得開始
            motionManager.startDeviceMotionUpdates(
                to: OperationQueue.current!,
                withHandler: {(motionData:CMDeviceMotion?, errorOC: Error?) in self.outputAttitudeData(attitude: motionData!.attitude)
            })
        }
        
        // ヨーピッチロールの可視化
        // シーン設定
        let scene = GameScene()
        // SCNView設定
        let scnView = self.attitude_view!
        scnView.scene = scene
        scnView.backgroundColor = UIColor.red
        scnView.showsStatistics = true
        scnView.allowsCameraControl = true
        // タップジェスチャー
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        scnView.addGestureRecognizer(tapGesture)
        
    }
    
    func outputAccelData(acceleration: CMAcceleration){
        // 加速度センサー[G]
        self.acceleration_raw.text =
        "加速度_X: \(String(format: "%06f", acceleration.x))\n加速度_Y: \(String(format: "%06f", acceleration.y))\n加速度_Z: \(String(format: "%06f", acceleration.z))"
    }
    func highpassFilter(acceleration: CMAcceleration){
        // ローパス(EMA)フィルター
        acceleration_EMA_X = Alpha*acceleration.x + acceleration_EMA_X!*(1.0-Alpha)
        acceleration_EMA_Y = Alpha*acceleration.y + acceleration_EMA_Y!*(1.0-Alpha)
        acceleration_EMA_Z = Alpha*acceleration.z + acceleration_EMA_Z!*(1.0-Alpha)
        
        // ハイパス後の値
        let xh = acceleration.x - acceleration_EMA_X!
        let yh = acceleration.y - acceleration_EMA_Y!
        let zh = acceleration.z - acceleration_EMA_Z!
        self.acceleration_highpass.text = "加速度_ハイパス_X: \(String(format: "%06f", xh))\n加速度_ハイパス_Y: \(String(format: "%06f", yh))\n加速度_ハイパス_Z: \(String(format: "%06f", zh))"
    }
    
    func outputMagnetoData(geomagnetism: CMMagneticField){
        // 地磁気センサー
        self.geomagnetism_raw.text = "地磁気_X: \(String(format: "%06f", geomagnetism.x))\n地磁気_Y: \(String(format: "%06f", geomagnetism.y))\n地磁気_Z: \(String(format: "%06f", geomagnetism.z))"
    }
    
    func outputGyroData(gyro: CMRotationRate){
        // ジャイロセンサー
        self.gyroscope_raw.text = "ジャイロ_X: \(String(format: "%06f", gyro.x))\nジャイロ_Y: \(String(format: "%06f", gyro.y))\nジャイロ_Z: \(String(format: "%06f", gyro.z))"
    }
    
    func outputAttitudeData(attitude: CMAttitude){
        // ヨーピッチロール
        self.attitude_raw.text = "Yaw: \(String(format: "%06f", attitude.yaw))\nPitch: \(String(format: "%06f", attitude.pitch))\nRoll: \(String(format: "%06f", attitude.roll))"
    }
    
    // センサー取得を止める関数
    func stopAccelerometor(){
        if(motionManager.isAccelerometerActive){
            motionManager.stopAccelerometerUpdates()
        }
    }
    
    // ヨーピッチロールの可視化
    @objc func handleTap(_ gestureRecognize: UIGestureRecognizer){
        print("タップされました")
        let d = 50 * (Float.pi / 180)
        self.attitude_view.scene?.rootNode.eulerAngles = SCNVector3(d, d, 0)

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    


}
