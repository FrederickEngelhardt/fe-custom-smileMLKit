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
    let threshold: CGFloat = 0.5
    lazy var faceDetector = Vision.vision().faceDetector(options: faceDetectionOptions())
    lazy var vision = Vision.vision()
    var labelDetector: VisionLabelDetector!
    static let labelConfidenceThreshold : Float = 0.5
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
    
    private func faceDetection(fromImage image: UIImage,_ image_id: String,_ image_name: String,_ image_properties: [String: String]) {
        startTimeStamp = Date()
        let visionImage = VisionImage(image: image)
        faceDetector.detect(in: visionImage) { [unowned self] (faces, error) in
                guard error == nil, let detectedFaces = faces else {
                    self.showAlert("An error occured", alertMessage: "The face detection failed.")
                    return
                }
                
                let faceStates = self.faceStates(forDetectedFaces: detectedFaces, image_id,image_name,image_properties)
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
                let data: [String: [String: Any]] = [
                    image_name: [
                        "image_id": image_id,
                        "image_name": image_name,
                        "image_tags": [],
                        "image_properties": image_properties
                    ]
                ]
                var dataDictionary = JsonFunctions.DataStack()
                dataDictionary.evaluate(image_id: image_id, image_name: image_name, type: "labels", data: data)
                
                
                return
            }
            let elapsed = "\(Date().timeIntervalSince(self.startTimeStamp))"
            
            ImageArray.labelsResults = labels.reduce("") { $0 + "\($1.label) (\($1.confidence)) \(elapsed) \n" }
//            let data = LabelData(score: (labels.reduce("") { $0 + "\($1.label) (\($1.confidence))\n" }), timing: 21)
            print(labels)
            let myLabels = labels.reduce("") { $0 + "\($1.label) (\($1.confidence))" }
            let labelData = labels.map {ele in
                return ["name": ele.label, "confidence": "\(ele.confidence)"]
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
            dataDictionary.evaluate(image_id: image_id, image_name: image_name, type: "labels", data: data)
            print("THIS IS COUNT", ImageArray.count, image_id)
            if (ImageArray.folderMaxCount == JsonFunctions.AllImages.labelIndex){
                dataDictionary.formatJSON()
            }
            if (ImageArray.folderMaxCount == JsonFunctions.AllImages.labelIndex && ImageArray.folderMaxCount == JsonFunctions.AllImages.faceIndex){
                // print out the JSON
                dataDictionary.formatJSON()
            }
            self.detectedInfo.text = ImageArray.labelsResults
        }
    }
    
    // Main function that calls all MLKit detections
    func processImage(fromImage image: UIImage, image_id: String, image_name: String? = nil, image_properties: [String: String]? = nil) {
        self.detect(fromImage: image, image_id: image_id, image_name: image_name!, image_properties: image_properties!)
//        self.faceDetection(fromImage: image, image_id, image_name!, image_properties!)
    }
    
    func loadImagesFromAlbum(folderName:String) -> [String]{
        
        let nsDocumentDirectory = FileManager.SearchPathDirectory.documentDirectory
        let nsUserDomainMask    = FileManager.SearchPathDomainMask.userDomainMask
        let paths               = NSSearchPathForDirectoriesInDomains(nsDocumentDirectory, nsUserDomainMask, true)
        var theItems = [String]()
        if let dirPath = paths.first
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
    func complete(){
        print("complete")
    }
    func grabPhotos(){
        
        let fetchOptions = PHFetchOptions()
        // SampleSet for folder of 50 images
        // Test for folder of 2 images.
        // Because Image names aren't tracked we will track album names...yep this is not optimal
        let albumArray: [String] = [
            "910003768_1000_1917798883.jpg",
            "910088472_1000_1935659587.jpg",
            "910089471_1000_1914529224.jpg",
            "910090973_1000_1936079527.jpg",
            "910091820_1000_1936455331.jpg",
            "910095165_1000_1937101043.jpg",
            "910095903_1000_1937222695.jpg",
            "910096575_1000_1916274041.jpg",
            "910096600_1000_1916292324.jpg",
            "910097008_1000_1937398382.jpg",
            "910097463_1000_1935595703.jpg",
            "910097987_1000_1916367901.jpg",
            "910098019_1000_1450191546.jpg",
            "910098310_1000_110740585685.jpg",
            "910098610_1000_1914975755.jpg",
            "910098706_1000_1914973901.jpg",
            "910099312_1000_1918756007.jpg",
            "910099492_1000_1938219140.jpg",
            "910099795_1000_1938342923.jpg",
            "910100396_1000_1936724811.jpg",
            "910100724_1000_1938555435.jpg",
            "910101178_1000_1788380935.jpg",
            "910101323_1000_1934680409.jpg",
            "910101534_1000_1938898454.jpg",
            "910101742_1000_1933206745.jpg",
            "910101742_1000_1933296143.jpg",
            "910101909_1000_1938907274.jpg",
            "910102165_1000_1936824324.jpg",
            "910102672_1000_1938263818.jpg",
            "910102813_1000_1919185832.jpg",
            "910103451_1000_1939329245.jpg",
            "910103655_1000_1939343187.jpg",
            "910103892_1000_1939424694.jpg",
            "910104201_1000_1939454686.jpg",
            "910104379_1000_1938067353.jpg",
            "910104669_1000_1939603728.jpg",
            "910104812_1000_1939647254.jpg",
            "910104987_1000_1939720558.jpg",
            "910105405_1000_1939737020.jpg",
            "910105405_1000_1939825458.jpg",
            "910105405_1000_1939855845.jpg",
            "910105447_1000_60788458900.jpg",
            "910105526_1000_1939177809.jpg",
            "910105965_1000_1936600301.jpg",
            "910106119_1000_1922418392.jpg",
            "910106317_1000_1937395226.jpg",
            "910106317_1000_1937459652.jpg",
            "910106465_1000_20777127927.jpg",
            "910106635_1000_1939868437.jpg",
            "910106635_1000_1939914076.jpg",
        ]
        albumArray.forEach { (albumStringName) in
            
            fetchOptions.predicate = NSPredicate(format: "title = %@", "\(albumStringName)")
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
            print("Your collection has been found")
            
            let photoAssets = PHAsset.fetchAssets(in: collection.firstObject!, options: nil)
            print("Your collection contains \(photoAssets) photos.")
            
            ImageArray.folderMaxCount = photoAssets.count
            print("You are processing: \(ImageArray.folderMaxCount) Images")
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
                        var orientation: String = ""
                        switch(image.imageOrientation){
                        case .up:
                            orientation = "up"
                            break
                        case .down:
                            orientation = "down"
                            break
                        case .left:
                            orientation = "left"
                            break
                        case .right:
                            orientation = "right"
                            break
                        default:
                            orientation = "Not a normal orienation"
                        }
                        let image_properties: [String: String] = [
                            "width": "\(image.size.width)",
                            "height": "\(image.size.height)",
                            "scale": "\(image.size.height)",
                            "orientation": "\(orientation)"
                        ]
                        print(dataUTI!, info!)

                        if let info = info {
                            if info.keys.contains(NSString(string: "PHImageFileURLKey")) {
                                if let path = info[NSString(string: "PHImageFileURLKey")] as? NSURL {
                                    
                                    let path_string = "\("\(path)".split(separator: ".")[0])"
                                    let fileType = "\("\(path)".split(separator: ".")[1])"
    //                                print("this is the path string \(path_string)")
                                    let arr = path_string.split(separator: "/")
                                    let count = arr.count
                                    let trail = "\(arr[count-2])"
                                    let fileName = "\(arr[count-1])"
                                    
                                    // Count starts at 1 and will increment until it reaches the ImageArry.folderMaxCount value.
                                    ImageArray.count += 1
    //                                print("THIS IS THE \(fileName)")
    //                                let newURL: URL = path.

    //                                let newURL = URL(string: "\(trail)\(count)\(fileType)")
    //                                try? UIImagePNGRepresentation(image)!.write(to: newURL!)
                                    self.processImage(fromImage: image, image_id: "\(ImageArray.count)", image_name: albumStringName, image_properties: image_properties)
                                }
                            }
                        }
                })
            }
        }
        //        Link to helper code https://stackoverflow.com/questions/28885391/how-to-loop-through-a-photo-gallery-in-swift-with-photos-framework/28904792#28904792
        //        PHImageManger vs fetchImage https://stackoverflow.com/questions/30288789/requesting-images-to-phimagemanager-results-in-wrong-image-in-ios-8-3
    }
    
    private func faceStates(forDetectedFaces faces: [VisionFace], _ image_id: String,_ image_name: String,_ image_properties: [String: String]) -> [FaceState] {
        var states = [FaceState]()
        var stateJSON: [[String: Any]] = []
        for face in faces {
            var isSmiling = false
            var iSConfidence = CGFloat()
            var leftEyeOpen = false
            var lEConfidence = CGFloat()
            var rightEyeOpen = false
            var rEConfidence = CGFloat()
            var frame = CGRect()
            if face.hasSmilingProbability {
                // set the frame inside here too...
                frame = face.frame
                isSmiling = self.isPositive(forProbability: face.smilingProbability)
                iSConfidence = face.smilingProbability
            }
            
            if face.hasRightEyeOpenProbability {
                rightEyeOpen = self.isPositive(forProbability: face.rightEyeOpenProbability)
                rEConfidence = face.rightEyeOpenProbability
            }
            
            if face.hasLeftEyeOpenProbability {
                leftEyeOpen = self.isPositive(forProbability: face.leftEyeOpenProbability)
                lEConfidence = face.leftEyeOpenProbability
            }
            let faceStateJSON: [String: [String: String]] = [
                "box": ["x": "\(frame.minX)", "y": "\(frame.minY)", "width": "\(frame.width)", "height": "\(frame.height)" ],
                "is_smiling": ["value": "\(isSmiling)", "confidence": "\(iSConfidence)"],
                "left_eye_open": ["value": "\(leftEyeOpen)", "confidence": "\(lEConfidence)"],
                "right_eye_open": ["value": "\(rightEyeOpen)", "confidence": "\(rEConfidence)"]
            ]
            let faceState = FaceState(smiling: isSmiling,
                                      leftEyeOpen: leftEyeOpen,
                                      rightEyeOpen: rightEyeOpen)
            states.append(faceState)
            stateJSON.append(faceStateJSON)
        }
        // If no values the array will be blank
        
        // This were we update the global JSON object
        let data: [String: [String: Any]] = [
            image_name: [
                "image_id": image_id,
                "image_name": image_name,
                "face_data": stateJSON,
                "image_properties": image_properties
            ]
        ]
        print("FACEIMAGE JSON DATA to send: \(data as AnyObject)")
        var dataDictionary = JsonFunctions.DataStack()
        dataDictionary.evaluate(image_id: image_id, image_name: image_name, type: "face", data: data)
        print("THIS IS CURRENT FACE INDEX", JsonFunctions.AllImages.faceIndex)
        if (ImageArray.folderMaxCount == JsonFunctions.AllImages.labelIndex && ImageArray.folderMaxCount == JsonFunctions.AllImages.faceIndex){
            // print out the JSON
            dataDictionary.formatJSON()
        }
        self.detectedInfo.text = ImageArray.labelsResults
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
        // Add this text to JSON Object
        
        
        let elapsed = "\(Date().timeIntervalSince(startTimeStamp))"
//        print("\(elapsed) \(text)")
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
            ImageArray.images.forEach {
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

