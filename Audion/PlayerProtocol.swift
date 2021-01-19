//
//  PlayerProtocol.swift
//  Audion
//
//  Created by Jesús A. Álvarez on 2021-01-18.
//  Copyright © 2021 Panic. All rights reserved.
//

import Foundation
import AVFoundation

protocol AnyPlayer: NSObject {
    func play()
    func pause()
    func seek(to time: CMTime)
    @discardableResult func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Void) -> Any
    func removeTimeObserver(_ observer: Any)
    
    var volume: Float { get set }
    var automaticallyWaitsToMinimizeStalling: Bool { get set }
    var rate: Float { get set }
    var status: AVPlayer.Status { get }
    var timeControlStatus: AVPlayer.TimeControlStatus { get }
    
    var currentItemDuration: CMTime? { get }
    var currentItemCommonMetadata: [AVMetadataItem]? { get }
    
    var isRemoteControl: Bool { get }
}

extension AVPlayer: AnyPlayer {
    var currentItemCommonMetadata: [AVMetadataItem]? {
        currentItem?.asset.commonMetadata
    }
    
    var currentItemDuration: CMTime? {
        currentItem?.duration
    }
    
    var isRemoteControl: Bool {
        false
    }
}
