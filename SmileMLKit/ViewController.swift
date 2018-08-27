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
import Photos

struct imageArray {
    static var images: [UIImage] = []
    static var active: Bool = false
    static var multiplier: Int = 1
    static var labelsResults: String = ""
    static var faceResults: String = ""
}
class ViewController: UIViewController {
    let threshold: CGFloat = 0.75
    lazy var faceDetector = Vision.vision().faceDetector(options: faceDetectionOptions())
    lazy var vision = Vision.vision()
    var labelDetector: VisionLabelDetector!
    static let labelConfidenceThreshold : Float = 0.9
    let options = VisionLabelDetectorOptions(
        confidenceThreshold: labelConfidenceThreshold
    )

    var startTimeStamp = Date()	
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var detectedInfo: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labelDetector = vision.labelDetector(options: options)
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
        let grabPhotosFromAlbum = UIAlertAction(title: "Process Album", style: .default) {
            [unowned self] _ in
            self.grabPhotos()
        }
        let clear = UIAlertAction(title: "Clear Array", style: .default) {
            _ in
            imageArray.active = false
            imageArray.images = []
        }
        
        
        photoSourcePicker.addAction(takePhoto)
        photoSourcePicker.addAction(choosePhoto)
        photoSourcePicker.addAction(choose10Photos)
        photoSourcePicker.addAction(grabPhotosFromAlbum)
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
                print("completed image!")
            }
    }
    func detect(fromImage image: UIImage) {
        let v = VisionImage(image: image)
        labelDetector.detect(in: v) { (labels, error) in
            //            self.runQueue.pop()
            guard error == nil, let labels = labels, !labels.isEmpty else {
                // Error.
                self.detectedInfo.text = "No idea"
                return
            }
            imageArray.labelsResults += labels.reduce("") { $0 + "\($1.label) (\($1.confidence))\n" }
            self.detectedInfo.text = imageArray.labelsResults
        }
    }
    func processImage(fromImage image: UIImage) {
//        self.detect(fromImage: image)
        self.faceDetection(fromImage: image)
    }

    func grabPhotos(){
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "Test")
        let collection = PHAssetCollection.fetchAssetCollections(with:.album, subtype: .albumRegular, options: fetchOptions)
        print("Your collection has been found")
        
        let photoAssets = PHAsset.fetchAssets(in: collection.firstObject!, options: nil)
        print("Your collection contains \(photoAssets) photos.")
        let imageManager = PHCachingImageManager()
        
        print(photoAssets, collection)
        
        photoAssets.enumerateObjects { (object: PHAsset!, count: Int, stop: UnsafeMutablePointer) in
            if object is PHAsset! {
                let asset = object!
                print("Inside  If object is PHAsset, This is number 1")
                let imageSize = PHImageManagerMaximumSize
                let options = PHImageRequestOptions()
                options.deliveryMode = .highQualityFormat
                options.resizeMode = .exact
                options.isSynchronous = true
                imageManager.requestImage(for: asset,
                                          targetSize: imageSize,
                                          contentMode: .aspectFill,
                                          options: options,
                                          resultHandler: {
                                            (image: UIImage!, info)->Void in
                                            let photo = image!
                                            self.processImage(fromImage: photo)
                                            print(photo)
                                            
                })
            }
        }
        //        Link to helper code https://stackoverflow.com/questions/28885391/how-to-loop-through-a-photo-gallery-in-swift-with-photos-framework/28904792#28904792
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
        if (text == ""){text = "NO FACESTATES"}
        let elapsed = "\(Date().timeIntervalSince(startTimeStamp))"
        imageArray.faceResults += "\(elapsed) \(text)"
        self.detectedInfo.text = imageArray.faceResults
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
        return "\(index+1) \(elapsed) \(personText) "
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
//                self.faceDetection(fromImage: value)
                self.processImage(fromImage: value)
//                self.grabPhotos()
//                self.processImage(fromImage: value)
            }
        }
    }
}
extension UIImage {
    /// Save PNG in the Documents directory
    func save(_ name: String) {
        let path: String = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        let url = URL(fileURLWithPath: path).appendingPathComponent(name)
        try! UIImagePNGRepresentation(self)?.write(to: url)
        print("saved image at \(url)")
    }
}

// Usage: Saves file in the Documents directory

