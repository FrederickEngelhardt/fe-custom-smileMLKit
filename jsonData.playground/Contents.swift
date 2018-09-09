import Foundation

struct face_data {
    private var box: [String: Int] = [
        "x": 0,
        "y": 0,
        "height": 0,
        "width": 0
    ]
    private var is_smiling: [String: Any] = [
        "value": "",
        "confidence": ""
    ]
    private var eyes_open: [String: Any] = [
        "value": "",
        "confidence": ""
    ]
}

struct image_tags {
    // tag is the dictionary for each label
    public var tag: [String: Any] = [
        "name": "",
        "confidence": ""
    ]
    // tag list contains a list of tags
    public var tag_list: [Any] = []
}

struct image_properties {
    private var properties: [String: Any] = [
        "height": "",
        "width": "",
        "orientation": "",
        "scale": ""
    ]
}

// This has to be updated each time any of the data changes
struct AllImages {
    public static var data: [String: [String: [String: Any]]] = [:]
    public static var labelIndex = 0
    public static var faceIndex = 0
}

struct DataStack {
    
    /*
     This has to be updated or created each time a face/label tag goes through.
     Default values are empty strings.
     */
    private var imageData: [String: Any] = [
        "image_id": "",
        "image_name": "",
        "face_data": "",
        "image_tags": ""
    ]
    

    
    func peek()-> [String: Any] {
        return imageData
    }
    
    // Evaluate will grab the data and either create a new imageData dictionary or patch the existing dictionary.
    mutating func evaluate(image_id: String, type: String, data: [String: [String: Any]]){
        let length: Int = AllImages.data.count
        switch(type){
        case "face":
            print("You receieved faceData")
            if (AllImages.faceIndex < length){
                AllImages.faceIndex += 1
                self.patch(image_id, type, data)
            }
            else {
                AllImages.faceIndex += 1
                self.push(image_id, type, data)
            }
        case "labels":
            print("You receieved labelData")
            if (AllImages.labelIndex < length){
                AllImages.labelIndex += 1
                self.patch(image_id, type, data)
            }
            else {
                AllImages.labelIndex += 1
                self.push(image_id, type, data)
            }
        default:
            print("You have failed to provide a type for this data")
        }
    }
    mutating func patch(_ image_id: String, _ type: String, _ element: [String: [String: Any]]) -> [String: [String: Any]] {
        switch(type){
            case "face":
                print("Patching face data")
                if let data = element[image_id]!["face_data"] as? [String: [String: Any]] {
                    AllImages.data[image_id]!["face_data"] = data
                }
                break
            case "labels":
                print("Patching lables data")
                if let data = element[image_id]!["image_tags"] as? [String: [String: Any]] {
                    AllImages.data[image_id]!["image_tags"] = data
                }
                break
            default:
                print("Type was not properly sent to push")
        }
        return AllImages.data
    }
    mutating func push(_ id: String,_ type: String, _ imageData: [String: [String: Any]]) -> [String: [String: Any]] {
        print("You just added a image onto the allImages Array")
        AllImages.data[id] = imageData
        return AllImages.data
    }
}

var dataDictionary = DataStack()

let imageTagData = ["image01": [
        "image_id": "image01",
        "image_name": "blah1",
//        "face_data": {
//            "box": {"x": 350, "y": 200, "height": 87, "width": 87},
//            "is_smiling": {"value": True, "confidence": 0.87},
//            "eyes_open": {"value": False, "confidence": 0.69}
//        },
        "image_tags": [
            ["name": "car", "confidence": 0.84],
            ["name": "person", "confidence": 0.94]
        ],
//        "image_tags_custom": [
//            ["name": "tree", "confidence": 0.76],
//            ["name": "window", "confidence": 0.33]
//        ],
        "image_properties": ["height": 256, "width": 360, "orientation": 2]
    ]]
let imageTagData2 = ["image02": [
    "image_id": "image02",
    "image_name": "blah2",
    //        "face_data": {
    //            "box": {"x": 350, "y": 200, "height": 87, "width": 87},
    //            "is_smiling": {"value": True, "confidence": 0.87},
    //            "eyes_open": {"value": False, "confidence": 0.69}
    //        },
    "image_tags": [
        ["name": "car", "confidence": 0.84],
        ["name": "person", "confidence": 0.94]
    ],
    //        "image_tags_custom": [
    //            ["name": "tree", "confidence": 0.76],
    //            ["name": "window", "confidence": 0.33]
    //        ],
    "image_properties": ["height": 256, "width": 360, "orientation": 2]
    ]]
let faceData = ["image01": [
    "image_id": "image01",
    "image_name": "blah2",
    "face_data": [
        "box": ["x": 350, "y": 200, "height": 87, "width": 87],
        "is_smiling": ["value": true, "confidence": 0.88],
        "eyes_open": ["value": false, "confidence": 0.69]
    ],
    "image_properties": ["height": 256, "width": 360, "orientation": 2]
    ]
]
dataDictionary.evaluate(image_id: "image01", type: "labels", data: imageTagData)
dataDictionary.evaluate(image_id: "image02", type: "labels", data: imageTagData2)
dataDictionary.evaluate(image_id: "image01", type: "face", data: faceData)
//print(AllImages.data)

