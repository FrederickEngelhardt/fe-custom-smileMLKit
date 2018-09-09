//
//  ViewController.swift
//  SmileMLKit
//
//  Updated 09/07/2018
//  Copyright Frederick Engelhardt. All Rights Reserved
//

import UIKit
import Firebase
import Dispatch
import Photos

struct ImageArray {
    static var images: [UIImage] = []
    static var active: Bool = false
    static var multiplier: Int = 1
    static var labelsResults: String = ""
    static var faceResults: String = ""
    static var folderMaxCount: Int = 0
    static var count: Int = 0
}
class DataObject {
    init(data: AnyObject){}
}
class ImageData {
    init(faceData: FaceData, labelData: LabelData){}
}
class FaceData {
    init(score: String, timing: Float){}
}
class LabelData {
    init(score: String, timing: Float){}
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
    
    var interpreter: ModelInterpreter!
    var ioOptions: ModelInputOutputOptions!

    var startTimeStamp = Date()
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var detectedInfo: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        labelDetector = vision.labelDetector(options: options)
        self.modelSetup()
        // Do any additional setup after loading the view, typically from a nib.
    }
    func modelSetup() {
        let conditions = ModelDownloadConditions(wiFiRequired: true, idleRequired: false)
        let cloudModelSource = CloudModelSource(
            modelName: "mobilenet",
            enableModelUpdates: true,
            initialConditions: conditions,
            updateConditions: conditions
        )
        _ = ModelManager.modelManager().register(cloudModelSource)
        
        guard let modelPath = Bundle.main.path(forResource: "mobilenet", ofType: "tflite") else {
            return
        }
        let localModelSource = LocalModelSource(modelName: "my_local_model",
                                                path: modelPath)
        ModelManager.modelManager().register(localModelSource)
        
        let options = ModelOptions(
            cloudModelName: nil,
            localModelName: "my_local_model"
        )
        interpreter = ModelInterpreter(options: options)
        
        ioOptions = ModelInputOutputOptions()
        do {
            try ioOptions.setInputFormat(index: 0, type: ModelElementType.uInt8, dimensions: [1, 224, 224, 3])
            try ioOptions.setOutputFormat(index: 0, type: ModelElementType.uInt8, dimensions: [1, NSNumber(value: 1001)])
        } catch let error as NSError {
            print("Failed to set input or output format with error: \(error.localizedDescription)")
        }
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
            ImageArray.multiplier = 1
            ImageArray.active = true
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        let choose10Photos = UIAlertAction(title: "Choose 10 Photos", style: .default) {
            [unowned self] _ in
            ImageArray.active = true
            ImageArray.multiplier = 10
            self.presentPhotoPicker(sourceType: .photoLibrary)
        }
        let grabPhotosFromAlbum = UIAlertAction(title: "Process Album", style: .default) {
            [unowned self] _ in
            self.grabPhotos()
        }
        let clear = UIAlertAction(title: "Clear Array", style: .default) {
            _ in
            ImageArray.active = false
            ImageArray.images = []
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
    func detect(fromImage image: UIImage, image_id: String, image_name: String, image_properties: [String: String]) {
        startTimeStamp = Date()
        let v = VisionImage(image: image)
        labelDetector.detect(in: v) { (labels, error) in
            guard error == nil, let labels = labels, !labels.isEmpty else {
                // Error.
                self.detectedInfo.text = "No idea"
                let labelError = ["ERROR": "NO RESULTS FOUND FOR THIS IMAGE"]
                let data: [String: [String: Any]] = [
                    image_name: [
                        "image_id": image_id,
                        "image_name": image_name,
                        "image_tags": labelError,
                        "image_properties": image_properties
                    ]
                ]
                var dataDictionary = JsonFunctions.DataStack()
                dataDictionary.evaluate(image_id: image_id, type: "labels", data: data)
                
                
                return
            }
            let elapsed = "\(Date().timeIntervalSince(self.startTimeStamp))"
            
            ImageArray.labelsResults = labels.reduce("") { $0 + "\($1.label) (\($1.confidence)) \(elapsed) \n" }
//            let data = LabelData(score: (labels.reduce("") { $0 + "\($1.label) (\($1.confidence))\n" }), timing: 21)
            
            let myLabels = labels.reduce("") { $0 + "\($1.label) (\($1.confidence))" }
            let labelData = labels.map {ele in
                return ["name": ele.label, "confidence": ele.confidence]
            }
            let data: [String: [String: Any]] = [
            image_name: [
                    "image_id": image_id,
                    "image_name": image_name,
                    "image_tags": labelData,
                    "image_properties": image_properties
                    ]
            ]
            var dataDictionary = JsonFunctions.DataStack()
            dataDictionary.evaluate(image_id: image_id, type: "labels", data: data)
            print("\n", JsonFunctions.AllImages.data)
            self.detectedInfo.text = ImageArray.labelsResults
        }
    }
    
    // Main function that calls all MLKit detections
    func processImage(fromImage image: UIImage, image_id: String, image_name: String? = nil, image_properties: [String: String]? = nil) {
        self.detect(fromImage: image, image_id: image_id, image_name: image_name!, image_properties: image_properties!)
//        self.faceDetection(fromImage: image)
    }
    
    func loadImagesFromAlbum(folderName:String) -> [String]{
        
        let nsDocumentDirectory = FileManager.SearchPathDirectory.documentDirectory
        let nsUserDomainMask    = FileManager.SearchPathDomainMask.userDomainMask
        let paths               = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
        var theItems = [String]()
        if let dirPath          = paths.first
        {
            let imageURL = URL(fileURLWithPath: dirPath).appendingPathComponent(folderName)
            
            do {
                theItems = try FileManager.default.contentsOfDirectory(atPath: imageURL.path)
                return theItems
            } catch let error as NSError {
                print(error.localizedDescription)
                return theItems
            }
        }
        return theItems
    }
    
    func grabPhotos(){
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", "SampleSet")
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        print("Your collection has been found")
        
        let photoAssets = PHAsset.fetchAssets(in: collection.firstObject!, options: nil)
        print("Your collection contains \(photoAssets) photos.")
        
        print(photoAssets, collection)
        print(photoAssets.count)
        photoAssets.enumerateObjects { (asset: PHAsset!, count: Int, stop: UnsafeMutablePointer) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = true
            options.version = .original
            options.resizeMode = .none
            PHImageManager.default().requestImageData(for: asset, options: options,
                  resultHandler: { (imagedata, dataUTI, orientation, info) in
                    guard let image_data = imagedata else {
                        return
                    }
                    guard let image = UIImage(data: image_data) else {return}
                    let image_properties: [String: String] = [
                        "width": "\(image.size.width)",
                        "height": "\(image.size.height)",
                        "scale": "\(image.size.height)",
                        "orientation": "\(image.imageOrientation)"
                    ]

                    if let info = info {
                        if info.keys.contains(NSString(string: "PHImageFileURLKey")) {
                            if let path = info[NSString(string: "PHImageFileURLKey")] as? NSURL {
                                print(path)
                                let path_string = "\("\(path)".split(separator: ".")[0])"
                                let arr = path_string.split(separator: "/")
                                let count = arr.count
                                let fileName = "\(arr[count-1])"
                                print(fileName)
                                self.processImage(fromImage: image, image_id: "\(ImageArray.count)", image_name: fileName, image_properties: image_properties)
                                ImageArray.count += 1
                            }
                        }
                    }
            })
        }
        //        Link to helper code https://stackoverflow.com/questions/28885391/how-to-loop-through-a-photo-gallery-in-swift-with-photos-framework/28904792#28904792
        //        PHImageManger vs fetchImage https://stackoverflow.com/questions/30288789/requesting-images-to-phimagemanager-results-in-wrong-image-in-ios-8-3
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
        print("\(elapsed) \(text)")
        ImageArray.faceResults += "\(elapsed) \(text)"
        self.detectedInfo.text = ImageArray.faceResults
        
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
//        let elapsed = Date().timeIntervalSince(startTimeStamp)
//        _ = "Test took: \(elapsed) \(personText)"
        return "\(personText) "
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
        while i < ImageArray.multiplier {
            print(i)
            ImageArray.images.append(image)
            i += 1
        }

        // Loops through the array and does detection on each photo
        if (ImageArray.active == true) {
            ImageArray.images.map {
                value in
//                self.faceDetection(fromImage: value)
//                print("height \(value.size.height)")
                print(value)
                if (value.imageOrientation == UIImageOrientation.up){print("inside MAP orientation is UP")}
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

