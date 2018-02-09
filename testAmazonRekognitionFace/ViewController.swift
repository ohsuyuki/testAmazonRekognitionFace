//
//  ViewController.swift
//  testCameraSimple
//
//  Created by osu on 2018/02/08.
//  Copyright © 2018 osu. All rights reserved.
//

import UIKit
import AVFoundation
import AWSRekognition

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var imageViewSrc: UIImageView!
    @IBOutlet weak var imageViewTrg: UIImageView!
    @IBOutlet weak var labelSimilarity: UILabel!
    @IBOutlet weak var labelError: UILabel!
    
    var session : AVCaptureSession? = nil
    var device : AVCaptureDevice? = nil
    var output : AVCaptureVideoDataOutput? = nil

    var srcImgRekognition: AWSRekognitionImage? = nil

    let queueImageProcess = DispatchQueue(label: "imageProcess")
    let storeImage = Store()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        initSession()
        initsrcImg()
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let image = imageFromSampleBuffer(sampleBuffer: sampleBuffer) else {
            return
        }
        
        DispatchQueue.main.sync {
            imageView.image = image
        }
        
        guard storeImage.get() == nil else {
            return
        }

        storeImage.set(image)
        queueImageProcess.async {
            self.imageProcess()
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        guard let session = self.session else {
            return
        }
        session.startRunning()
    }
    
    private func initSession() {
        // 全面のカメラを取得
        guard let device = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front).devices.first else {
            clean()
            return
        }
        self.device = device
        
        // セッション作成
        self.session = AVCaptureSession()
        guard let session = self.session else {
            return
        }
        // 解像度の設定
        session.sessionPreset = .high
        
        // カメラをinputに
        var inputTmp: AVCaptureDeviceInput? = nil
        do {
            inputTmp = try AVCaptureDeviceInput(device: device)
        } catch {
            print(error.localizedDescription)
            clean()
            return
        }
        guard let input = inputTmp else {
            clean()
            return
        }
        guard session.canAddInput(input) == true else {
            clean()
            return
        }
        session.addInput(input)
        
        // outputの構成と設定
        self.output = AVCaptureVideoDataOutput()
        guard let output = self.output else {
            clean()
            return
        }
        output.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA ]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "tatsdxkpcg"))
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) == true else {
            clean()
            return
        }
        session.addOutput(output)
        
        #if false
            // ouputの向きを縦向きに
            for connection in output.connections {
                guard connection.isVideoOrientationSupported == true else {
                    continue
                }
                connection.videoOrientation = .portrait
            }
        #endif
    }

    private func initsrcImg() {
        let srcImg = UIImage(named: "image0")
        imageViewSrc.image = srcImg
        srcImgRekognition = AWSRekognitionImage()
        srcImgRekognition!.bytes = UIImageJPEGRepresentation(srcImg!, 0)
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage? {
        #if true
        guard let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let baseAddress: UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0) else {
            return nil
        }
        
        let bytesPerRow: UInt = UInt(CVPixelBufferGetBytesPerRow(imageBuffer))
        let width: UInt = UInt(CVPixelBufferGetWidth(imageBuffer))
        let height: UInt = UInt(CVPixelBufferGetHeight(imageBuffer))
        
        let bitsPerCompornent: UInt = 8
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue).union(CGBitmapInfo.byteOrder32Little)
        guard let newContext: CGContext = CGContext(data: baseAddress, width: Int(width), height: Int(height), bitsPerComponent: Int(bitsPerCompornent), bytesPerRow: Int(bytesPerRow), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo.rawValue) else {
            return nil
        }
        
        guard let cgImage = newContext.makeImage() else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
        #else
            return UIImage(named: "image1")
        #endif
    }
    
    private func imageProcess() {
        guard let image = storeImage.get() else {
            return
        }
        
        let trgImgRekognition = AWSRekognitionImage()!
        trgImgRekognition.bytes = UIImageJPEGRepresentation(image, 0)

        let request = AWSRekognitionCompareFacesRequest()!
        request.sourceImage = srcImgRekognition
        request.targetImage = trgImgRekognition
        
        print("compareFaces")
        
        do {
            AWSRekognition.default().compareFaces(request) { (response, error) in
                defer {
                    self.storeImage.set(nil)
                    DispatchQueue.main.sync {
                        self.imageViewTrg.image = image
                    }
                }

                print("compareFaces finish")

                guard error == nil else {
                    print("compareFaces error")
                    DispatchQueue.main.sync {
                        self.labelError.text = error?.localizedDescription
                        self.labelSimilarity.text = "unmatch..."
                    }
                    return
                }
                
                if let response = response {
                    print("compareFaces complete")
                    var similarity: String = "unmatch..."
                    if let faceMathes = response.faceMatches {
                        for faceMatch in faceMathes {
                            similarity = "\(faceMatch.similarity)"
                        }
                    }

                    DispatchQueue.main.sync {
                        self.labelSimilarity.text = similarity
                        self.labelError.text = "no error"
                    }
                }
            }
        } catch {
            print("copmareFaces error")
        }
    }
    
    private func clean() {
        session = nil
        device = nil
        output = nil
    }
}

class Store {

    private let queue = DispatchQueue(label: "store")
    private var store: UIImage? = nil

    func set(_ image: UIImage?) {
        queue.sync {
            self.store = image
        }
    }

    func get() -> UIImage? {
        return queue.sync {
            return self.store
        }
    }
}
