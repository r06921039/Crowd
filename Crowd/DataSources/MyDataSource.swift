//
//  MyDataSource.swift
//  Crowd
//
//  Created by Jeff on 2021/3/1.
//

import UIKit
import UBottomSheet

class MyDataSource: UBottomSheetCoordinatorDataSource {
    public func sheetPositions(_ availableHeight: CGFloat) -> [CGFloat] {
        return [0.2, 0.5, 0.82].map { $0 * availableHeight }
    }
    
    
    public func initialPosition(_ availableHeight: CGFloat) -> CGFloat {
        return availableHeight * 0.2
    }
    
//    public func rubberBandLogicTop(_ total: CGFloat, _ limit: CGFloat) -> CGFloat {
//        let value = limit * (1 - log10(total / limit))
//        guard !value.isNaN, value.isFinite else {
//            return total
//        }
//        return value
//    }
//
//    public func rubberBandLogicBottom(_ total: CGFloat, _ limit: CGFloat) -> CGFloat {
//        let value = limit * (1 + log10(total / limit))
//        guard !value.isNaN, value.isFinite else {
//            return total
//        }
//        return value
//    }
}
