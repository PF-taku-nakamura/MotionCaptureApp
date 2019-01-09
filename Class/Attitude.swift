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
    
    static func dynamoDBTableName() -> String {
        return "Test"
    }
    
    class func hashKeyAttribute() -> String {
        return "TimeStamp"
    }
}

