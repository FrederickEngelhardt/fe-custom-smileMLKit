//
//  ViewController.swift
//  SmileMLKit
//
//  Created by Martin Mitrevski on 11.05.18.
//  Copyright © 2018 Mitrevski. All rights reserved.
//

import UIKit
import Firebase
import Dispatch

struct imageArray {
    static var images: [UIImage] = []
    static var active: Bool = false
    static var multiplier: Int = 1
}
class ViewController: UIViewController {
    let threshold: CGFloat = 0.75
    
    lazy var faceDetector = Vision.vision().faceDetector(options: faceDetectionOptions())
    var startTimeStamp = Date()
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var detectedInfo: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    @IBAction func selectImageTapped(_ sender: UIButton) {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(sourceType: .photoLibrary)
            return
        }
        
        let photoSourcePicker = UIAlertController()
        let takePhoto = UIAlertAction(title: "Take Photo", style: .default) {
            [unowned self] _ in
            self.presentPhotoPicker(sourceType: .camera)
        }
        let choosePhoto = UIAlertAction(title: "Choose Photo", style: .default) {
            [unowned self] _ in
            imageArray.multiplier = 1
            imageArray.active = true
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        let choose10Photos = UIAlertAction(title: "Choose 10 Photos", style: .default) {
            [unowned self] _ in
            imageArray.active = true
            imageArray.multiplier = 10
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        let clear = UIAlertAction(title: "Clear Array", style: .default) {
            [unowned self] _ in
            imageArray.active = false
            imageArray.images = []
        }
        
        
        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(choose10Photos)
        photoSourcePicker.addAction(clear)
        photoSourcePicker.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        present(photoSourcePicker, animated: true)
    }
    
    // MARK: - Photo picker
    
    private func presentPhotoPicker(sourceType: UIImagePickerControllerSourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        present(picker, animated: true)
    }
    
    // MARK: - Face Detection
    
    private func faceDetection(fromImage image: UIImage) {
        startTimeStamp = Date()
        let visionImage = VisionImage(image: image)
        faceDetector.detect(in: visionImage) { [unowned self] (faces, error) in
            guard error == nil, let detectedFaces = faces else {
                self.showAlert("An error occured", alertMessage: "The face detection failed.")
                return
            }
            
            let faceStates = self.faceStates(forDetectedFaces: detectedFaces)
            self.updateDetectedInfo(forFaceStates: faceStates)
        }
    }
    
    private func faceStates(forDetectedFaces faces: [VisionFace]) -> [FaceState] {
        var states = [FaceState]()
        for face in faces {
            var isSmiling = false
            var leftEyeOpen = false
            var rightEyeOpen = false
            if face.hasSmilingProbability {
                isSmiling = self.isPositive(forProbability: face.smilingProbability)
            }
            
            if face.hasRightEyeOpenProbability {
                rightEyeOpen = self.isPositive(forProbability: face.rightEyeOpenProbability)
            }
            
            if face.hasLeftEyeOpenProbability {
                leftEyeOpen = self.isPositive(forProbability: face.leftEyeOpenProbability)
            }
            
            let faceState = FaceState(smiling: isSmiling,
                                      leftEyeOpen: leftEyeOpen,
                                      rightEyeOpen: rightEyeOpen)
            states.append(faceState)
        }
        
        return states
    }
    
    private func isPositive(forProbability probability: CGFloat) -> Bool {
        return probability > threshold
    }
    
    private func updateDetectedInfo(forFaceStates faceStates: [FaceState]) {
        var text = ""
        for (index, faceState) in faceStates.enumerated() {
            let next = personText(forState: faceState, index: index)
            text = text + next + " "
        }
        detectedInfo.text = text
    }
    
    private func personText(forState state: FaceState, index: Int) -> String {
        let isSmiling = state.smiling ? "is smiling" : "not smiling"
        var eyesOpened = ""
        if state.leftEyeOpen == state.rightEyeOpen {
            eyesOpened =
                state.leftEyeOpen && state.rightEyeOpen ? "both eyes opened" : "both eyes closed"
        } else {
            eyesOpened = "one eye closed and one opened"
        }
        let personText = "Person number \(index + 1) \(isSmiling), with \(eyesOpened)."
        let elapsed = Date().timeIntervalSince(startTimeStamp)
//        _ = "Test took: \(elapsed) \(personText)"
        return "\(index+1) \(elapsed)"
    }
    
    //MARK: - Alerts
    
    func showAlert(_ alertTitle: String, alertMessage: String) {
        let alert = UIAlertController(title: alertTitle, message: alertMessage,
                                      preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "Dismiss", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
}

func faceDetectionOptions() -> VisionFaceDetectorOptions {
    let options = VisionFaceDetectorOptions()
    options.modeType = .accurate
    options.landmarkType = .all
    options.classificationType = .all
    options.minFaceSize = CGFloat(0.1)
    options.isTrackingEnabled = false
    
    
    // fast 4 variations
    // none none 0.1
    // none none 0.2
    // all none 0.1
    // all all 0.1
    // none all 0.1
    
    // accurate 4 variations
    // none none 0.1
    // none none 0.2
    // all none 0.1
    // all all 0.1
    // none all 0.1
    
    return options
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - Handling Image Picker Selection
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [String: Any]) {
        picker.dismiss(animated: true)
        let image = info[UIImagePickerControllerOriginalImage] as! UIImage
        imageView.contentMode = UIViewContentMode.scaleAspectFit
        imageView.image = image
        
        // Adds a number of images into the array depending on the multiplier.
        var i = 0
        while i < imageArray.multiplier {
            print(i)
            imageArray.images.append(image)
            i += 1
        }
        // Loops through the array and does detection on each photo
        if (imageArray.active == true) {
            imageArray.images.map {
                value in
//                DispatchQueue.main.async(execute: { () -> Void in
//                    return self.faceDetection(fromImage: value)
//                })
//                let core1 = DispatchQueue.global(qos: .userInitiated)
//                let core2 = DispatchQueue.global(qos: .userInitiated)
//                let dw = DispatchWorkItem {
//                    self.faceDetection(fromImage: value)
//                }
//                core1.async(execute: dw)
//                core2.async(execute: dw)
                let core1 = DispatchQueue(label: "core1", qos: .userInitiated)
                let core2 = DispatchQueue(label: "core2", qos: .userInitiated)
//                let dw = DispatchWorkItem {
//                    self.faceDetection(fromImage: value)
//                }
                core1.async {
                    self.faceDetection(fromImage: value)
                }
                core1.async {
                    self.faceDetection(fromImage: value)
                }
                core2.async{
                    self.faceDetection(fromImage: value)
                }
//                queue1.sync {
//
//                    Thread.current.name = "Queue1"
//                    self.faceDetection(fromImage: value)
//                    print("called queue1")
//
//                }
//                queue2.sync {
//                    Thread.current.name = "Queue2"
//                    print("called queue2")
//                    self.faceDetection(fromImage: value)
//                }
//                DispatchQueue.global(qos: .background).async {
//                    Thread.current.name = "my thread"
//                    self.faceDetection(fromImage: value)
//                }
            }
        }
    }
}
