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
import AWSDynamoDB

class AttitudeViewController: UIViewController {
    
    // EMAフィルター後データ変数保持
    var acceleration_EMA_X: Double? = 0.0
    var acceleration_EMA_Y: Double? = 0.0
    var acceleration_EMA_Z: Double? = 0.0
    let Alpha = 0.4
    // ヨーピッチロールの値を一時的に保存
    var attitude_yaw: Double? = 0.0
    var attitude_pitch: Double? = 0.0
    var attitude_roll: Double? = 0.0
    var attitude_timestamp: Double? = 0.0
    
    // MotionManager
    let motionManager = CMMotionManager()
    
    // Altimeter(高度の取得のため)
    let altimeterManager = CMAltimeter()
    
    // 表示
    @IBOutlet weak var acceleration_raw: UILabel! // 生加速度
    @IBOutlet weak var acceleration_highpass: UILabel! // EMA(ローパス)加速度
    @IBOutlet weak var geomagnetism_raw: UILabel! // 生地磁気
    @IBOutlet weak var gyroscope_raw: UILabel! // 生ジャイロ
    @IBOutlet weak var attitude_raw: UILabel! // ヨーピッチロール
    @IBOutlet weak var attitude_view: SCNView! // ヨーピッチロールを表示するView
    @IBOutlet weak var altitude_raw: UILabel! // 高度
    @IBOutlet weak var timestamp_value: UILabel! // タイムスタンプ
    
    
    var isUploaded: Bool = false
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //contentsのサイズに合わせてobujectのサイズを変える
        self.acceleration_raw.sizeToFit()
        self.acceleration_highpass.sizeToFit()
        self.geomagnetism_raw.sizeToFit()
        self.gyroscope_raw.sizeToFit()
        self.attitude_raw.sizeToFit()
        self.altitude_raw.sizeToFit()
        self.timestamp_value.sizeToFit()
        //表示可能最大行数を指定
        self.acceleration_raw.numberOfLines = 0
        self.acceleration_highpass.numberOfLines = 0
        self.geomagnetism_raw.numberOfLines = 0
        self.gyroscope_raw.numberOfLines = 0
        self.attitude_raw.numberOfLines = 0
        self.altitude_raw.numberOfLines = 0
        self.timestamp_value.numberOfLines = 0
        
        if motionManager.isAccelerometerAvailable {
            // intervalの設定[sec]
            motionManager.accelerometerUpdateInterval = 0.1
            motionManager.magnetometerUpdateInterval = 0.1
            motionManager.gyroUpdateInterval = 0.1
            motionManager.deviceMotionUpdateInterval = 0.01
            
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
            // 高度値の取得(iPhone6以上)
            altimeterManager.startRelativeAltitudeUpdates(
                to: OperationQueue.current!,
                withHandler: {(altitudeData:CMAltitudeData?, errorOC: Error?) in
                    self.outputAltitudeData(altitude: altitudeData!)
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
        // 時刻
        // 現在時刻の表示
        let t = Double(Date().timeIntervalSince1970)
        self.timestamp_value.text = "Timestamp: \(String(format: "%06f", t))"
        // ヨーピッチロール
        self.attitude_raw.text = "Yaw: \(String(format: "%06f", attitude.yaw))\nPitch: \(String(format: "%06f", attitude.pitch))\nRoll: \(String(format: "%06f", attitude.roll))"
        self.attitude_yaw=attitude.yaw
        self.attitude_pitch=attitude.pitch
        self.attitude_roll=(-1.0)*attitude.roll
        self.attitude_timestamp=t
        // DynamoDBにヨーピッチロールとタイムスタンプデータをアップロードする(このViewに来たらずっと上げ続ける)
//        let awsAttitude = Attitude()
//        awsAttitude?.TimeStamp = t as NSNumber
//        awsAttitude?.Yaw = attitude.yaw as NSNumber
//        awsAttitude?.Pitch = attitude.pitch as NSNumber
//        awsAttitude?.Roll = attitude.roll as NSNumber
//
//        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
//        if !self.isUploaded {
//            if let at = awsAttitude {
//                dynamoDBObjectMapper.save(at).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
//                    if let error = task.error as NSError? {
//                        print("The request failed. Error: \(error)")
//                    } else {
//                        print(task.result)
//                    }
//                    self.isUploaded = true
//                    return nil
//                })
//            }
//        }
        
    }
    
    func outputAltitudeData(altitude: CMAltitudeData){
        self.altitude_raw.text = "高度: \(altitude.relativeAltitude)"
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
        let d = 50 * (Float.pi / 180) // rad = theta * (pi / 180)
        self.attitude_view.scene?.rootNode.eulerAngles = SCNVector3(self.attitude_pitch!, self.attitude_yaw!, self.attitude_roll!)
        print(d)
        // DynamoDBにヨーピッチロールとタイムスタンプデータをアップロードする(タップされたらその時のヨーピッチロールをDynamoDBに上げる)
        let awsAttitude = Attitude()
        awsAttitude?.TimeStamp = self.attitude_timestamp! as NSNumber
        awsAttitude?.Yaw = self.attitude_yaw! as NSNumber
        awsAttitude?.Pitch = self.attitude_pitch! as NSNumber
        awsAttitude?.Roll = self.attitude_roll! as NSNumber
        
        let dynamoDBObjectMapper = AWSDynamoDBObjectMapper.default()
        if let at = awsAttitude {
            dynamoDBObjectMapper.save(at).continueWith(block: { (task:AWSTask<AnyObject>!) -> Any? in
                if let error = task.error as NSError? {
                    print("The request failed. Error: \(error)")
                } else {
                    print(task.result!)
                }
                return nil
            })
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    


}
