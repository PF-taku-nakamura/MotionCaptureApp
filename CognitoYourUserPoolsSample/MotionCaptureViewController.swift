//
//  MotionCaptureViewController.swift
//  CognitoYourUserPoolsSample
//
//  Created by 中村拓 on 2018/12/01.
//  Copyright © 2018年 Dubal, Rohan. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import AWSCore
import AWSS3
import AWSMobileClient

class MotionCaptureViewController: UIViewController {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var showFpsLabel: UILabel!
    @IBOutlet weak var changeFpsButton: UISegmentedControl!
    
    // 動画情報の表示
    var isRecoding = false
    var fileOutput: AVCaptureMovieFileOutput?
    var isBackCamera: Bool = true
    var textMCVC: String?
    var decidedFps: Double? = 30.0
    // 処理中のクルクル
    var ActivityIndicator: UIActivityIndicatorView!
    
    // カメラとマイクを入れるための箱（セッションのインスタンス作成）
    var captureSession = AVCaptureSession()
    var filePath: String?
    var motionCaptureVideoFileURL: URL?
    // カメラにアクセスするためのデバイス
    var videoDevice: AVCaptureDevice!

    override func viewDidLoad() {
        super.viewDidLoad()
        // AppDelegateから録画関数を呼び出すため
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.motionCaptureViewController = self
        // Cognitoの認証データを取得
        AWSMobileClient.sharedInstance().initialize { (userState, error) in
            if let userState = userState {
                print("UserState: \(userState.rawValue)")
            } else if let error = error {
                print("error: \(error.localizedDescription)")
            }
        }
        // ActivityIndicatorを作成&中央に配置
        ActivityIndicator = UIActivityIndicatorView()
        ActivityIndicator.backgroundColor = .lightGray
        ActivityIndicator.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        ActivityIndicator.center = self.view.center
        // クルクルをStopした時に非表示にする
        ActivityIndicator.hidesWhenStopped = true
        // 色を設定
        ActivityIndicator.style = UIActivityIndicatorView.Style.gray
        // Viewに追加
        self.view.addSubview(ActivityIndicator)
        
        // FPSの表示
        // 表示内容の初期化
        self.showFpsLabel.text="---"
        //表示可能最大行数を指定
        self.showFpsLabel.numberOfLines = 0
        
        // カメラの起動
        setupCamera(isBack: self.isBackCamera)
    }

    func setupCamera(isBack: Bool) {
        self.isRecoding = false
        self.captureSession = AVCaptureSession()

        // 入力（映像を撮影するカメラ）
        if #available(iOS 10.0, *) {
            let deviceDescoverySession = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                               mediaType: AVMediaType.video,
                                                                               position: AVCaptureDevice.Position.unspecified)
            for device in deviceDescoverySession.devices {
                let devicePosition: AVCaptureDevice.Position = isBack ? .back : .front
                if device.position == devicePosition {
                    videoDevice = device
                }
            }
        } else {
            print("You Need Update")
        }

        do{
            let videoInput = try AVCaptureDeviceInput(device: videoDevice!) as AVCaptureDeviceInput
            self.captureSession.addInput(videoInput)
            setMaxFps(maxFps: self.decidedFps!)
        }catch let error as NSError{
            print(error)
        }

        // 入力（音声を録音するマイク）
        let audioDevice = AVCaptureDevice.default(for: AVMediaType.audio)
        let audioInput = try! AVCaptureDeviceInput.init(device: audioDevice!)
        self.captureSession.addInput(audioInput)
        // 出力（動画ファイル）
        self.fileOutput = AVCaptureMovieFileOutput()
        self.captureSession.canAddOutput(self.fileOutput!)
        self.captureSession.addOutput(self.fileOutput!)
        //self.captureSession.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160

        // プレビュー(撮影している映像を表示するための画面)
        let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        // レイアウト
        videoLayer.frame = self.videoView.bounds
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoLayer.connection?.videoOrientation = .portrait
        self.videoView.layer.addSublayer(videoLayer)

        // セッションの開始
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    @IBAction func tapStartStopButton(_ sender: Any) {
        if self.isRecoding { // 録画終了
            print("録画終了！")
            self.fileOutput?.stopRecording()
            // アップロード
            uploadVideo()
        }
        else{ // 録画開始
            print("録画開始！")
            let fileName = "\(Date().timeIntervalSince1970).mov"
            self.filePath = NSHomeDirectory() + "/tmp/" + fileName
            self.motionCaptureVideoFileURL = NSURL(fileURLWithPath: self.filePath!) as URL
            self.fileOutput?.startRecording(to: self.motionCaptureVideoFileURL!, recordingDelegate: self as AVCaptureFileOutputRecordingDelegate)
        }
    }
    
    @IBAction func selectChangeFpsButton(_ sender: UISegmentedControl) {
        //セグメント番号で条件分岐させる
        switch sender.selectedSegmentIndex {
        case 0:
            self.decidedFps=30.0
            setMaxFps(maxFps: self.decidedFps!)
        case 1:
            self.decidedFps=60.0
            setMaxFps(maxFps: self.decidedFps!)
        case 2:
            self.decidedFps=120.0
            setMaxFps(maxFps: self.decidedFps!)
        default:
            self.decidedFps=240.0
            setMaxFps(maxFps: self.decidedFps!)
        }
    }
    
}

extension MotionCaptureViewController: AVCaptureFileOutputRecordingDelegate {
    
    func uploadVideo(){
        // 処理中のクルクルスタート
        DispatchQueue.main.async(execute: {
            self.ActivityIndicator.startAnimating()
        })
        // setup S3 configuration
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: .APNortheast1, identityPoolId: "ap-northeast-1:0b87cb12-8ca5-431b-9866-b964b04f65a2")
        let configuration = AWSServiceConfiguration(region: .APNortheast1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        // File to be uploaded
        let url = self.motionCaptureVideoFileURL!
        let expression = AWSS3TransferUtilityUploadExpression()
        expression.progressBlock = {(task, progress) in
            DispatchQueue.main.async(execute: {
                // Do something e.g. Update a progress bar.
            })
        }
        var completionHandler: AWSS3TransferUtilityUploadCompletionHandlerBlock?
        completionHandler = { (task, error) -> Void in
            DispatchQueue.main.async(execute: {
                // クルクルの終了
                self.captureSession.stopRunning()
                // Do something e.g. Alert a user for transfer completion.
                // On failed uploads, `error` contains the error object.
            })
        }
        let transferUtility = AWSS3TransferUtility.default()
        transferUtility.uploadFile(url,
                                   bucket: "poc-motioncapture-app",
                                   key: "input/\(self.motionCaptureVideoFileURL!.lastPathComponent)",
                                   contentType: "video/quicktime",
                                   expression: expression,
                                   completionHandler: completionHandler).continueWith {
                                    (task) -> AnyObject? in
                                    if let error = task.error {
                                        print("Error: \(error.localizedDescription)")
                                    }
                                    if let _ = task.result {
                                        // Do something with uploadTask.
                                    }
                                    return nil;
        }
    }

    func setMaxFps(maxFps: Double) {
        // fpsを上げるためのルーチン
        // デバイスとsessionを繋げる前にfpsの設定は出来ない.
        var minFPS = 0.0
        var maxFPS = maxFps
        var maxWidth:Int32 = 0
        var maxHeight:Int32 = 0
        var selectedFormat:AVCaptureDevice.Format? = nil
        // セッションが始動中なら止める
        if isRecoding {
            self.captureSession.stopRunning()
        }
        // デバイスから取得できるフォーマットを全探索
        for format in (self.videoDevice?.formats)! {
            //フォーマットの中のフレームレートの情報を取得、fpsがでかい方を選んでいく。
            for range in format.videoSupportedFrameRateRanges{
                let desc = format.formatDescription
                let dimentions = CMVideoFormatDescriptionGetDimensions(desc)
                print("フォーマット情報： \(desc)")
                print("min:\(range.minFrameRate),max:\(range.maxFrameRate),maxWidth:\(dimentions.width),maxHeight:\(dimentions.height)")
                
                if(minFPS <= range.minFrameRate && maxFPS == range.maxFrameRate && maxWidth <= dimentions.width){
                    minFPS = range.minFrameRate
                    maxFPS = range.maxFrameRate
                    maxWidth = dimentions.width
                    maxHeight = dimentions.height
                    selectedFormat = format
                    print("更新！！")
                }
            }
        }
        if selectedFormat != nil {
            do{
                try self.videoDevice?.lockForConfiguration()
                self.videoDevice?.activeFormat = selectedFormat!
                self.videoDevice?.activeVideoMinFrameDuration = CMTimeMake(value: 1,timescale: Int32(minFPS))
                self.videoDevice?.activeVideoMaxFrameDuration = CMTimeMake(value: 1,timescale: Int32(maxFPS))
                self.videoDevice?.unlockForConfiguration()
                print("フォーマット・フレームレートを設定 : \(maxFPS) fps・\(maxWidth) px")
                self.showFpsLabel.text="FPS: \(maxFPS)\nImage Quality: \(maxWidth)*\(maxHeight)"
                //contentsのサイズに合わせてobujectのサイズを変える
                self.showFpsLabel.sizeToFit()
            }catch{
                print("フォーマット・フレームレートが指定できなかった")
            }
        } else {
            print("指定のフォーマットが取得できなかった")
        }
        // セッションが始動中だったら再開する
        if isRecoding {
            self.captureSession.startRunning()
        }
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        self.isRecoding = true
    }

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        self.isRecoding = false

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputFileURL)
        }) { completed, error in
            if completed {
                DispatchQueue.main.async {
                    self.ActivityIndicator.stopAnimating()
                    print("Video is saved!")
                }
            }
        }
    }

}

