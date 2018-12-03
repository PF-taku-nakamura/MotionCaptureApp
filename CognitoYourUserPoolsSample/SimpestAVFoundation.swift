//
//  SimpestAVFoundation.swift
//  CognitoYourUserPoolsSample
//
//  Created by 中村拓 on 2018/12/02.
//  Copyright © 2018年 Dubal, Rohan. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation

@available(iOS 10.0, *)
class SimpestAVFoundation:NSObject, AVCaptureVideoDataOutputSampleBufferDelegate{
    let captureSession = AVCaptureSession() //済
    
    //フロントカメラにアクセスするためのデバイス。
    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera ,for: AVMediaType.video ,position:.back) //済
    //let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)//これだとバックのカメラ。
    
    //アウトプットを設定するためのインスタンス//済
    var videoOutput = AVCaptureVideoDataOutput()//済
    
    //ViewControllerからviewをもらっておく
    var view:UIView //済
    
    init(view:UIView)//済
    {
        self.view=view//済
        
        super.init()//済
        self.initialize()//済
    }
    
    func initialize(){
        do{//済
            let videoInput = try AVCaptureDeviceInput(device: self.videoDevice!) as AVCaptureDeviceInput//済
            self.captureSession.addInput(videoInput)//済
        }catch let error as NSError{//済
            print(error)//済
        }
        
        self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]//済
        
        self.setMaxFps()//済
        
        // dispatchQueueを用意して、AVCaptureVideoDataOutputSampleBufferDelegateを批准しているインスタンスを入力する
        // そうするとcaptureOutputが呼ばれるようになる。
        let queue:DispatchQueue = DispatchQueue(label: "myqueue", attributes: .concurrent)//済
        self.videoOutput.setSampleBufferDelegate(self, queue: queue)//済
        self.videoOutput.alwaysDiscardsLateVideoFrames = true//済
        
        self.captureSession.addOutput(self.videoOutput)//済
        
        //プレビューを生成してviewのレイヤーに追加してあげる。
        let videoLayer : AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
        videoLayer.frame = self.view.bounds
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.view.layer.addSublayer(videoLayer)
        
        self.captureSession.startRunning()
    }
    
    func setMaxFps(){
        //fpsをあげるためのルーチン
        //デバイスとsessionを繋げる前にfpsの設定とかはできない！
        var minFPS = 0.0
        var maxFPS = 0.0
        var maxWidth:Int32 = 0
        var selectedFormat:AVCaptureDevice.Format? = nil
        
        //デバイスから取得できるフォーマットを全探索。
        for format in (self.videoDevice?.formats)!{
            //フォーマットの中のフレームレートの情報を取得、fpsがでかい方を選んでいく。
            for range in format.videoSupportedFrameRateRanges{
                let desc = format.formatDescription
                let dimentions = CMVideoFormatDescriptionGetDimensions(desc)
                
                if(minFPS <= range.minFrameRate && maxFPS <= range.maxFrameRate && maxWidth <= dimentions.width){
                    minFPS = range.minFrameRate
                    maxFPS = range.maxFrameRate
                    maxWidth = dimentions.width
                    selectedFormat = format
                }
            }
        }
        
        do{
            try self.videoDevice?.lockForConfiguration()
            self.videoDevice?.activeFormat = selectedFormat!
            self.videoDevice?.activeVideoMinFrameDuration = CMTimeMake(value: 1,timescale: Int32(minFPS))
            self.videoDevice?.activeVideoMaxFrameDuration = CMTimeMake(value: 1,timescale: Int32(maxFPS))
            self.videoDevice?.unlockForConfiguration()
        }catch{
            
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        //毎フレーム呼ばれる。
    }
    
    
}
