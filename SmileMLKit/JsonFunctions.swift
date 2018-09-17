//
//  JsonFunctions.swift
//  SmileMLKit
//
//  Created by Frederick Engelhardt on 9/8/18.
//  Copyright © 2018 Mitrevski. All rights reserved.
//

import Foundation

struct JsonFunctions {
    
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
        public func formatJSON(){
            let jsonData = try! JSONSerialization.data(withJSONObject: JsonFunctions.AllImages.data)
            let jsonString = NSString(data: jsonData, encoding: String.Encoding.utf8.rawValue)
            print("This is your JSON OBJECT", jsonString!, "End of JSON OBJECT")
            //            print("ALLIMAGES JSON DATA: \(JsonFunctions.AllImages.data as AnyObject)")
            //            print("ALLIMAGES RAW DATA: \(JsonFunctions.AllImages.data)")
        }
        
        // Evaluate will grab the data and either create a new imageData dictionary or patch the existing dictionary.
        mutating func evaluate(image_id: String, image_name: String, type: String, data: [String: [String: Any]]){
            let length: Int = AllImages.data.count
            switch(type){
            case "face":
                print("You receieved faceData")
                if (AllImages.faceIndex < length){
                    AllImages.faceIndex += 1
                    self.patch(image_id, image_name, type, data)
                }
                else {
                    AllImages.faceIndex += 1
                    self.push(image_id, type, data)
                }
            case "labels":
                print("You receieved labelData")
                if (AllImages.labelIndex < length){
                    AllImages.labelIndex += 1
                    self.patch(image_id, image_name, type, data)
                }
                else {
                    AllImages.labelIndex += 1
                    self.push(image_id, type, data)
                }
            default:
                print("You have failed to provide a type for this data")
            }
        }
        mutating func patch(_ image_id: String,_ image_name: String, _ type: String, _ element: [String: [String: Any]]) {
            switch(type){
            case "face":
                print("Patching face data")    
                if let data = element as? [String: [String: Any]] {
                    AllImages.data[image_id]![image_name]!["face_data"] = data[image_name]!["face_data"]!
                }
                break
            case "labels":
                print("Patching lables data")
                if let data = element[image_id]! as? [String: [String: Any]] {
                    AllImages.data[image_id]!["label_data"] = data
                }
                break
            default:
                print("Type was not properly sent to push")
            }
        }
        mutating func push(_ id: String,_ type: String, _ imageData: [String: [String: Any]]){
            print("You just added a image onto the allImages Array")
            AllImages.data[id] = imageData
        }
    }
}
