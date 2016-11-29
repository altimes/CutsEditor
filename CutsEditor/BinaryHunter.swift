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

// Binary search for ad boundary

class boundaryHunter {

  enum huntDirection  {
    case forward, backward, done, undefined
  }
  
  var jumpDistance = 120.0   // Seconds
  var lowPlayerPos: Double   // seconds
  var hiPlayerPos: Double    // Seconds
  var initialJump: Double
  var lastDirection = huntDirection.undefined
  var foundBoundary = false
  var isFirstJump = true
  var player: AVPlayer
  var startPlayerPos: CMTime
  static let seekTolerance = CMTime(seconds: 0.1, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
  var debug = false
  
  init(firstJump: Double, player avPlayer: AVPlayer) {
    jumpDistance = firstJump
    initialJump = jumpDistance
    player = avPlayer
    startPlayerPos = self.player.currentTime()
    if firstJump > 0.0 {
      lowPlayerPos = startPlayerPos.seconds
      hiPlayerPos = lowPlayerPos + firstJump
    }
    else {
      lowPlayerPos = startPlayerPos.seconds + firstJump  // remember this is negative
      hiPlayerPos = startPlayerPos.seconds
    }
    if (debug)
    {print(String(format: "Initialized at lo: %6.2f, hi: %6.2f, jump: %6.2f", lowPlayerPos, hiPlayerPos, jumpDistance))}
  }
  
  /// set hunting hi / lo boundaries
  /// calling this is delayed from Seek to allow player to actually seek
  /// such that current position is as expected.
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
  func jumpForward() -> String {
   setHiLo(direction: lastDirection)
   switch lastDirection {
    case .backward :
      jumpDistance = ((hiPlayerPos - lowPlayerPos) / 2.0)
    case .forward : // double forward
      jumpDistance = (hiPlayerPos - lowPlayerPos) / 2.0
      lowPlayerPos = player.currentTime().seconds
    case .undefined:
      jumpDistance = jumpDistance * 1.0  // first usage
    case .done:
      jumpDistance = 0.0
    }
    if (debug)
    {print(String(format: "forward lo: %6.2f, hi: %6.2f, jump: %6.2f", lowPlayerPos, hiPlayerPos, jumpDistance))}
    jump(direction: .forward, distance: jumpDistance)
    return "\(jumpDistance)"
  }
  
  /// seek backward from the current position.
  /// halve the distance if there is a change of direction
  func jumpBackward() -> String {
    setHiLo(direction: lastDirection)
    switch lastDirection {
    case .backward :  // double backward
      jumpDistance = -((hiPlayerPos - lowPlayerPos) / 2.0)
      hiPlayerPos = player.currentTime().seconds
    case .forward :
      jumpDistance = -(hiPlayerPos - lowPlayerPos) / 2.0
    case .undefined:
      jumpDistance = jumpDistance * 1.0  // first usage
    case .done:
      jumpDistance = 0.0
    }
    if (debug)
    {print(String(format: "backward lo: %6.2f, hi: %6.2f, jump: %6.2f", lowPlayerPos, hiPlayerPos, jumpDistance))}
    jump(direction: .backward, distance: jumpDistance)
    return "\(jumpDistance)"
  }
  
  /// seek the player to within "tolerance"
  /// tolerance is performance factor for the VideoPlayer
  func jump(direction: huntDirection, distance: Double)
  {
    let seekTolerance = CMTime(seconds: 0.1, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
    let seekStep = CMTimeMake(Int64(distance*Double(CutsTimeConst.PTS_TIMESCALE)), CutsTimeConst.PTS_TIMESCALE)
    let seekPos = CMTimeAdd(player.currentTime(), seekStep)
    if (debug)
    {print(String(format: "jumping %6.2f, from %6.2f, to: %6.2f", distance, player.currentTime().seconds, seekPos.seconds))}
    player.seek(to: seekPos, toleranceBefore: seekTolerance, toleranceAfter: seekTolerance)
    lastDirection = direction
    isFirstJump = false
  }
  
  /// this is a the "ah bugger" jumped the wrong way, start again, function
  func reset() {
    player.seek(to: startPlayerPos)
    lastDirection = .undefined
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
    jumpDistance = initialJump
    foundBoundary = true
  }
}
