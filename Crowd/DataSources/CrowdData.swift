//
//  CrowdData.swift
//  Crowd
//
//  Created by Jeff on 2021/3/5.
//

import Foundation

class CrowdData{
    var table : [String:Int] = [:]
    init(_ data:Array<NSDictionary>){
        for value in data{
            let lat = value["latitude"] as! NSNumber
            let long = value["longitude"] as! NSNumber
            let key = lat.stringValue + long.stringValue
            let percent = ((value["people"] as! Float) / (value["total"] as! Float) * 100)
            table[key] = Int(percent)
        }
    }
    func getTable() -> [String:Int]{
        return table
    }
}
