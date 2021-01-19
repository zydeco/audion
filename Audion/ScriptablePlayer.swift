//
//  ScriptablePlayer.swift
//  Audion
//
//  Created by Jesús A. Álvarez on 2021-01-18.
//  Copyright © 2021 Panic. All rights reserved.
//

import AVFoundation

class ScriptablePlayer: NSObject, AnyPlayer {
    var isRemoteControl: Bool {
        true
    }
    
    var automaticallyWaitsToMinimizeStalling: Bool = false
    
    @objc dynamic var rate: Float = .zero
    
    @objc dynamic var status: AVPlayer.Status = .unknown
    
    @objc dynamic var timeControlStatus: AVPlayer.TimeControlStatus = .paused
    
    var currentItemCommonMetadata: [AVMetadataItem]? {
        guard let currentTrack = currentTrackScript?.executeAndReturnError(nil), currentTrack.numberOfItems == 3,
              let title = currentTrack.atIndex(1)?.stringValue,
              let artist = currentTrack.atIndex(2)?.stringValue,
              let album = currentTrack.atIndex(3)?.stringValue else {
            return []
        }
        
        let titleItem = AVMutableMetadataItem()
        titleItem.identifier = .commonIdentifierTitle
        titleItem.value = title as NSString
        
        let artistItem = AVMutableMetadataItem()
        artistItem.identifier = .commonIdentifierArtist
        artistItem.value = artist as NSString
        
        let albumItem = AVMutableMetadataItem()
        albumItem.identifier = .commonIdentifierAlbumName
        albumItem.value = album as NSString
        
        return [titleItem, artistItem, albumItem]
    }
    
    var volume: Float {
        get {
            guard let value = volumeScript?.executeAndReturnError(nil).int32Value else {
                return .zero
            }
            return Float(value) / 100.0
        }
        set {
            setVolumeScript(Int(newValue * 100))?.executeAndReturnError(nil)
        }
    }
    
    let appName: String
    let playScript, pauseScript, playerPositionScript, playerStateScript, durationScript, volumeScript, currentTrackScript: NSAppleScript?
    
    init(appName: String) {
        self.appName = appName
        playScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to play")
        pauseScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to pause")
        playerPositionScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to get the player position")
        playerStateScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to get the player state")
        durationScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to get the duration of the current track")
        volumeScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to get the sound volume")
        currentTrackScript = NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to get {the name of the current track, the artist of the current track, the album of the current track}")
        super.init()
        
        let runScript = NSAppleScript(source: "tell application \"\(appName)\" to run")
        var error: NSDictionary? = nil
        runScript?.executeAndReturnError(&error)
        if error != nil {
            print("\(error!)")
        }
    }
    
    
    private func setVolumeScript(_ volume: Int) -> NSAppleScript? {
        return NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to set the sound volume to \(volume)")
    }
    
    private func setPlayerPositionScript(_ seconds: Double) -> NSAppleScript? {
        return NSAppleScript(source: "if application \"\(appName)\" is running then tell application \"\(appName)\" to set the player position to \(seconds)")
    }
    
    var currentItemDuration: CMTime? {
        guard var value = durationScript?.executeAndReturnError(nil).doubleValue else {
            return .zero
        }
        if appName == "Spotify" && value > 1000 {
            // spotify returns duration in milliseconds instead of seconds, despite documenting otherwise 😤
            value /= 1000
        }
        if value == 0 {
            value = -1
        }
        return CMTime(seconds: value, preferredTimescale: 1000)
    }
    
    private var lastPlayerSeconds: Int = 0
    
    private var playerPosition: Double {
        get {
            guard let value = playerPositionScript?.executeAndReturnError(nil).stringValue else {
                return .zero
            }
            return Double(value) ?? .zero
        }
        
        set {
            setPlayerPositionScript(newValue)?.executeAndReturnError(nil)
        }
    }
    
    func play() {
        playScript?.executeAndReturnError(nil)
        update()
    }
    
    func pause() {
        pauseScript?.executeAndReturnError(nil)
        update()
    }
    
    func seek(to time: CMTime) {
        playerPosition = time.seconds
    }
    
    private var updateTimer: Timer? = nil
    private var timeObservers: [(id: UUID, callback: (CMTime) -> Void)] = []
    
    func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Void) -> Any {
        if updateTimer == nil {
            updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true, block: { (_) in
                self.update()
            })
        }
        
        let uuid = UUID()
        timeObservers.append((uuid, block))
        return uuid
    }
    
    func removeTimeObserver(_ observer: Any) {
        guard let uuid = observer as? UUID else {
            return
        }
        timeObservers.removeAll(where: { $0.id == uuid })
    }
    
    private func updateRate(_ newValue: Float) {
        if rate != newValue {
            rate = newValue
        }
    }
    
    private func updateTimeControlStatus(_ newValue: AVPlayer.TimeControlStatus) {
        if timeControlStatus != newValue {
            timeControlStatus = newValue
        }
    }
    
    @objc func update() {
        if status != .readyToPlay {
            status = .readyToPlay
        }
        let playerState = playerStateScript?.executeAndReturnError(nil).stringValue
        switch playerState {
        case "kPSp":
            updateTimeControlStatus(.paused)
            updateRate(.zero)
        case "kPSP":
            updateTimeControlStatus(.playing)
            updateRate(1.0)
        default:
            updateTimeControlStatus(.waitingToPlayAtSpecifiedRate)
            updateRate(.zero)
        }
        
        let time = CMTime(seconds: playerPosition, preferredTimescale: 1000)
        if lastPlayerSeconds != Int(time.seconds) {
            lastPlayerSeconds = Int(time.seconds)
            timeObservers.forEach({ $0.callback(time) })
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
