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

class MotionCaptureViewController: UIViewController {
    
    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var startStopButton: UIButton!
    
    var isRecoding = false
    var fileOutput: AVCaptureMovieFileOutput?
    var isBackCamera: Bool = true
    var textMCVC: String?
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
            setMaxFps(maxFps: 120.0)
        }catch let error as NSError{
            print(error)
        }
        // FPSの設定
        setMaxFps(maxFps: 120.0)

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
            self.fileOutput?.stopRecording()
            self.ActivityIndicator.startAnimating()

            DispatchQueue.global(qos: .userInitiated).async {
                // setup S3 configuration
                let credentialsProvider = AWSCognitoCredentialsProvider(regionType: .APNortheast1, identityPoolId: "ap-northeast-1:0b87cb12-8ca5-431b-9866-b964b04f65a2")
                let configuration = AWSServiceConfiguration(region: .APNortheast1, credentialsProvider: credentialsProvider)
                AWSServiceManager.default().defaultServiceConfiguration = configuration
                let request = AWSS3TransferManagerUploadRequest()
                request?.bucket="poc-motioncapture-app"
                request?.key="input/\(Date().timeIntervalSince1970).mov"
                request?.body = self.motionCaptureVideoFileURL!
                AWSS3TransferManager.default().upload(request!)
                print("aaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
                print(self.motionCaptureVideoFileURL!)
                print("aaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
                // クルクルの終了
                self.captureSession.stopRunning()
            }
        }
        else{ // 録画開始

            let fileName = "\(Date().timeIntervalSince1970).mov"
            self.filePath = NSHomeDirectory() + "/tmp/" + fileName
            self.motionCaptureVideoFileURL = NSURL(fileURLWithPath: self.filePath!) as URL
            self.fileOutput?.startRecording(to: self.motionCaptureVideoFileURL!, recordingDelegate: self as AVCaptureFileOutputRecordingDelegate)
        }
    }

}

extension MotionCaptureViewController: AVCaptureFileOutputRecordingDelegate {

    func setMaxFps(maxFps: Double) {
        // fpsを上げるためのルーチン
        // デバイスとsessionを繋げる前にfpsの設定は出来ない.
        var minFPS = 0.0
        var maxFPS = maxFps
        var maxWidth:Int32 = 0
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
                
                if(minFPS <= range.minFrameRate && maxFPS <= range.maxFrameRate && maxWidth <= dimentions.width){
                    minFPS = range.minFrameRate
                    maxFPS = range.maxFrameRate
                    maxWidth = dimentions.width
                    selectedFormat = format
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
                self.ActivityIndicator.stopAnimating()
                print("Video is saved!")
            }
        }
    }

}

