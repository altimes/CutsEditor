//
//  BinaryHunter.swift
//  CutsEditor
//
//  Created by Alan Franklin on 14/11/16.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation
import AVFoundation
import AVKit

struct huntDirectionStrings {
  static let forward = "Forward"
  static let backward = "Backward"
  static let done = "Done"
  static let undo = "Undo"
  static let undefined = "Undefined"
}

/// Direction to jump when performing a binary search for an
/// advertisment boundary.  Include "done" and "undefined"
/// to ensure setup and completion states are representable
enum huntDirection  {
  case forward, backward, done, undo, undefined
  var description: String {
    get {
      switch self
      {
      case .forward : return huntDirectionStrings.forward
      case .backward : return huntDirectionStrings.backward
      case .done : return huntDirectionStrings.done
      case .undo : return huntDirectionStrings.undo
      case .undefined : return huntDirectionStrings.undefined
      }
    }
  }
}


// Binary search for ad boundary

class BoundaryHunter {
  
  struct huntCommand : Equatable {
    var command:huntDirection
    var jumpDistance: Double
    var button: NSButton
    
    var description: String {
      return "\(command):\(jumpDistance):\(button.title)"
    }
    
    static func == (lhs: huntCommand, rhs: huntCommand) -> Bool {
      let areEqual = lhs.command == rhs.command &&
        lhs.jumpDistance == rhs.jumpDistance &&
        lhs.button == rhs.button
      
      return areEqual
    }
  }
  
  var jumpDistance = 120.0   // Seconds
  
  var lowPlayerPos: Double   // seconds
  var hiPlayerPos: Double    // Seconds
  var gap : Double
  var gapString: String {
    get {
      return String(format:"%5.2f",gap)
    }
  }
  var huntHistory =  [ huntCommand ]()
  var recordHistory = true
  var initialJump: Double
  var lastDirection = huntDirection.undefined
  var lastJumpDistance: Double = 0.0
  var foundBoundary = false
  var isFirstJump = true
  var player: AVPlayer
  var startPlayerPos: CMTime
  var seekCompletionHandler : (_ completed: Bool) -> Void
  var playerSeek : (_ to: CMTime, _ beforeTolerance: CMTime, _ afterTolerance: CMTime) -> Void
  var seekCompleted: Bool
  
  // TODO: make runtime configurable
  static let seekToleranceValue = 1.0/25.0 // Seconds
  
  static var reportGapValue = 3.0 // seconds: nearness to start reporting
  static var nearEnough = 0.3     // near enough match in seconds to perfect position
  static var voiceReporting = false
  static var visualReporting = true
  
  static let seekTolerance = CMTime(seconds: seekToleranceValue, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
  
  var debug = false
  
  init(firstJump: Double, firstButton: NSButton, player avPlayer: AVPlayer, seekCompletionFlag: inout Bool, completionHander: @escaping ((_: Bool) -> Void), seekHandler: @escaping (_ to: CMTime, _ beforeTolerance: CMTime, _ afterTolerance:CMTime) -> Void)
  {
    var direction: huntDirection
    
    seekCompletionHandler = completionHander
    seekCompleted = seekCompletionFlag
    playerSeek = seekHandler
    jumpDistance = firstJump
    initialJump = jumpDistance
    player = avPlayer
    startPlayerPos = self.player.currentTime()
    if (debug) { print("initial video pos of \(startPlayerPos.seconds)") }
    
    if firstJump > 0.0 {
      lowPlayerPos = startPlayerPos.seconds
      hiPlayerPos = lowPlayerPos + firstJump
      direction = .forward
    }
    else {
      lowPlayerPos = startPlayerPos.seconds + firstJump  // remember this is negative
      hiPlayerPos = startPlayerPos.seconds
      direction = .backward
    }
    
    gap = hiPlayerPos - lowPlayerPos
    if (debug)
    { print(String(format: "Initialized at lo: %6.2f, hi: %6.2f, jump: %6.2f", lowPlayerPos, hiPlayerPos, jumpDistance)) }
    huntHistory.append(huntCommand(command: direction, jumpDistance: firstJump, button: firstButton))
  }
  
  func setFromPreferences(prefs: adHunterPreferences)
  {
    BoundaryHunter.reportGapValue = prefs.closingReport
    BoundaryHunter.nearEnough = prefs.nearEnough
    BoundaryHunter.voiceReporting = prefs.isSpeechReporting
    BoundaryHunter.visualReporting = prefs.isOverlayReporting
  }
  
  /// set hunting hi / lo boundaries
  /// calling this is delayed from Seek to allow player to actually seek
  /// such that current position is as expected.
  /// parameter direction: direction that binary step occured
  
  func setHiLo(direction: huntDirection)
  {
    switch (direction) {
    case .forward:
      hiPlayerPos = player.currentTime().seconds
    case .backward:
      lowPlayerPos = player.currentTime().seconds
    default: // do nothing
      break
    }
  }
  
  /// seek forward from the current position.
  /// halve the gap if there is a change of direction
  /// returns : displayable string of step taken
  func jumpForward(using button: NSButton) -> String {
    jumpDistance = seekTimeBetween(lowBoundary: lowPlayerPos, highBoundary: hiPlayerPos, going: .forward)
    if (debug) {print(String(format: "forward lo: %6.2f, hi: %6.2f, jump: %6.2f", lowPlayerPos, hiPlayerPos, jumpDistance))}
    jump(direction: .forward, distance: jumpDistance, using: button)
    return String.init(format: "%.2f", jumpDistance)
  }
  
  func seekTimeBetween(lowBoundary: Double, highBoundary: Double, going direction:huntDirection ) -> Double
  {
    if (direction == .backward)
    {
      setHiLo(direction: lastDirection)
      gap = (hiPlayerPos - lowPlayerPos)
      let halvedGap = ( gap / 2.0)
      switch lastDirection {
      case .backward :  // double backward, set new high limit
        jumpDistance = -halvedGap
        hiPlayerPos = player.currentTime().seconds
      case .forward :
        jumpDistance = -halvedGap
      case .undefined:
        jumpDistance = jumpDistance * 1.0  // first usage
      case .undo:
        jumpDistance = -1.0 * lastJumpDistance
        hiPlayerPos += jumpDistance
      case .done:
        jumpDistance = 0.0
      }
    }
    else if (direction == .forward)
    {
      setHiLo(direction: lastDirection)
      gap = (hiPlayerPos - lowPlayerPos)
      let halvedGap = ( gap / 2.0)
      switch lastDirection {
      case .backward :
        jumpDistance = halvedGap
      case .forward : // double forward, set new low limit
        jumpDistance = halvedGap
        lowPlayerPos = player.currentTime().seconds
      case .undefined:
        jumpDistance = jumpDistance * 1.0  // first usage
      case .undo:
        jumpDistance = -1.0 * lastJumpDistance
        lowPlayerPos += lastJumpDistance
      case .done:
        jumpDistance = 0.0
      }
    }
    return jumpDistance
  }
  
  /// seek backward from the current position.
  /// halve the distance if there is a change of direction
  /// returns : displayable string of step taken
  func jumpBackward(using button: NSButton) -> String {
    jumpDistance = seekTimeBetween(lowBoundary: lowPlayerPos, highBoundary: hiPlayerPos, going: .backward)
    if (debug) {print(String(format: "backward lo: %6.2f, hi: %6.2f, jump: %6.2f", lowPlayerPos, hiPlayerPos, jumpDistance))}
    jump(direction: .backward, distance: jumpDistance, using: button)
    return String.init(format: "%.2f", jumpDistance)
  }
  
  /// seek the player to within "tolerance"
  /// tolerance is performance factor for the VideoPlayer
  /// - parameter direction : .forward / .backward hunting
  /// - parameter distance : time step in signed seconds
  func jump(direction: huntDirection, distance: Double, using fromButton:NSButton)
  {
    //    let seekTolerance = CMTime(seconds: 0.1, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
    let seekStep = CMTimeMake(value: Int64(distance*Double(CutsTimeConst.PTS_TIMESCALE)), timescale: CutsTimeConst.PTS_TIMESCALE)
    let seekPos = CMTimeAdd(player.currentTime(), seekStep)
    if (debug)
    {print(String(format: "jumping %6.2f, from %6.2f, to: %6.2f", distance, player.currentTime().seconds, seekPos.seconds))}
//    seekCompleted = false
//    player.seek(to: seekPos, toleranceBefore: BoundaryHunter.seekTolerance, toleranceAfter: BoundaryHunter.seekTolerance, completionHandler: seekCompletionHandler)
    playerSeek(seekPos, BoundaryHunter.seekTolerance, BoundaryHunter.seekTolerance)
    lastDirection = direction
    lastJumpDistance = distance
    if (recordHistory && !isFirstJump)  {
      huntHistory.append(huntCommand(command: direction, jumpDistance: distance, button: fromButton))
    }
    // being called during a replay
    isFirstJump = false
  }
  
  /// this is a the "ah bugger" jumped the wrong way, start from the begining, function
  func reset() {
    if (debug) { print("resetting ad hunter") }
//    seekCompleted = false
//    player.seek(to: startPlayerPos, completionHandler: seekCompletionHandler)
    if (debug) { print("reset seeking to \(startPlayerPos.seconds)")}
//    seekCompleted = false
//    player.seek(to: startPlayerPos, toleranceBefore: BoundaryHunter.seekTolerance, toleranceAfter: BoundaryHunter.seekTolerance, completionHandler: seekCompletionHandler)
    playerSeek(startPlayerPos, BoundaryHunter.seekTolerance, BoundaryHunter.seekTolerance)

    lastDirection = .undefined
    lastJumpDistance = 0.0
    jumpDistance = initialJump
    if initialJump > 0.0 {
      lowPlayerPos = startPlayerPos.seconds
      hiPlayerPos = lowPlayerPos + initialJump
    }
    else {
      lowPlayerPos = startPlayerPos.seconds + initialJump  // remember this is negative
      hiPlayerPos = startPlayerPos.seconds
    }
    isFirstJump = true
  }
  
  /// found the location of interest, reset for the next usage
  func done() {
    lastDirection = .undefined
    lastJumpDistance = 0.0
    jumpDistance = initialJump
    foundBoundary = true
  }
  
  /// convert array of hunt commands into Human form
  func descriptionOfHistory(jumpHistory: [huntCommand]) -> String
  {
    var description = "jumpHistory\n"
    for index in 0 ..< jumpHistory.count
    {
      let entry = jumpHistory[index]
      let entryDescription = "\n[\(index)]:\(entry.command) -> \(entry.jumpDistance) from button \(entry.button.title)"
      description += entryDescription
    }
    return description
  }
  
  var printableHistory: String {
    guard (huntHistory.count > 0 ) else { return "no hunt history" }
//    var description = "huntHistory\n"
//    for index in 0 ..< huntHistory.count
//    {
//      let entry = huntHistory[index]
//      let entryDescription = "\n[\(index)]:\(entry.command) -> \(entry.jumpDistance)"
//      description += entryDescription
//    }
    return descriptionOfHistory(jumpHistory: self.huntHistory)
  }
}
