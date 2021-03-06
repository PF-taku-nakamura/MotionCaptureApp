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
    @IBOutlet weak var idField: UITextField!
    
    // 機体idを指定するためのドラムロール
    var pickerView: UIPickerView = UIPickerView()
    let list: [String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11", "12", "13", "14", "15"]
    
    //タップ座標用変数
    var tapPoint = CGPoint(x: 0, y: 0)
    
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
        // 機体idを設定するためのドラムロール
        // ピッカー設定
        pickerView.delegate = self as? UIPickerViewDelegate
        pickerView.dataSource = self as? UIPickerViewDataSource
        pickerView.showsSelectionIndicator = true
        // 決定バーの生成
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 35))
        let spacelItem = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let doneItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
        toolbar.setItems([spacelItem, doneItem], animated: true)
        // インプットビュー設定
        idField.inputView = pickerView
        idField.inputAccessoryView = toolbar
        // 機体idのデフォルト値を設定
        idField.textAlignment = NSTextAlignment.center
        idField.text = "id未選択"
        
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
        
        // ジェスチャーの追加
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapAction))
        tapGesture.delegate = self as? UIGestureRecognizerDelegate
        videoView.addGestureRecognizer(tapGesture)
        
        // カメラの起動
        setupCamera(isBack: self.isBackCamera)
    }
    
    // 機体idを決定するボタンの押下
    @objc func done() {
        idField.endEditing(true)
        idField.text = "\(list[pickerView.selectedRow(inComponent: 0)])"
        let appDelegate:AppDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.deviceId = idField.text!
    }

    // カメラの準備をする関数
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
    
    //画像のどこの座標をタップしたかを取得する関数
    @objc func tapAction(sender:UITapGestureRecognizer){
        tapPoint = sender.location(in: videoView)
        do {
            try videoDevice.lockForConfiguration()
            //videoDevice.focusMode = AVCaptureDevice.FocusMode.locked // オートフォーカスを切る
            videoDevice.focusPointOfInterest = tapPoint
            videoDevice.focusMode = AVCaptureDevice.FocusMode.autoFocus
        } catch {
            print("ロック解除エラー")
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

extension MotionCaptureViewController : UIPickerViewDelegate, UIPickerViewDataSource {
    
    // ドラムロールの列数
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // ドラムロールの行数
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        /*
         列が複数ある場合は
         if component == 0 {
         } else {
         ...
         }
         こんな感じで分岐が可能
         */
        return list.count
    }
    
    // ドラムロールの各タイトル
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        /*
         列が複数ある場合は
         if component == 0 {
         } else {
         ...
         }
         こんな感じで分岐が可能
         */
        return list[row]
    }
    
    /*
     // ドラムロール選択時
     func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
     self.textField.text = list[row]
     }
     */
}

extension MotionCaptureViewController: AVCaptureFileOutputRecordingDelegate {
    
    func uploadVideo(){
        let start = Date()
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
                                   key: "input/\(String(describing: self.idField.text!))/\(self.motionCaptureVideoFileURL!.lastPathComponent)",
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
        let elapsed = Date().timeIntervalSince(start)
        print("アップロード処理時間", elapsed)
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

