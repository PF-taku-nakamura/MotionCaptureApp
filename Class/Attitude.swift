//
//  Attitude.swift
//  CognitoYourUserPoolsSample
//
//  Created by 中村拓 on 2019/01/07.
//  Copyright © 2019年 Dubal, Rohan. All rights reserved.
//

import Foundation
import AWSDynamoDB

class Attitude: AWSDynamoDBObjectModel, AWSDynamoDBModeling {
    
    var TimeStamp: NSNumber?
    var Yaw: NSNumber?
    var Pitch: NSNumber?
    var Roll: NSNumber?
    var DeviceId: NSString?
    // 姿勢データを送り続ける場合、以下も追加 ////////////////////
    var BoatNumber: NSNumber = 1
    var PositionLatitude: NSNumber = 0
    var PositionLongitude: NSNumber = 0
    var AccelarateX: NSNumber?
    var AccelarateY: NSNumber?
    var AccelarateZ: NSNumber?
    var AngularX: NSNumber?
    var AngularY: NSNumber?
    var AngularZ: NSNumber?
    var DirectionX: NSNumber?
    var DirectionY: NSNumber?
    var DirectionZ: NSNumber?
    //////////////////////////////////////////////////
    
    static func dynamoDBTableName() -> String {
        // 姿勢データをタップした時に送り続ける場合
        //return "Test"
        // 姿勢データを送り続ける場合
        return "Infinity"
    }
    
    class func hashKeyAttribute() -> String {
        return "TimeStamp"
    }
}

