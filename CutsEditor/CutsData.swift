//
//  CutsData.swift
//  CutsEditor
//
//  Created by Alan Franklin on 3/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation
/*
 == .cut FILES ==
 
 Also network ordered, they contain a 64bit value (PTS) and 32bit value
 (type) for each cut. (If you want file offsets, use the .ap file to look up
 the PTS values.)
 
 Type is:
 
 0 - 'in' point
 1 - 'out' point
 2 - mark
 3 - lastplay
 
 If the first 'out'-point is not preceeded by an 'in'-point, there is an
 implicit 'in' point at zero.
 
 If the there is no final 'out' point, the end-of-file is an implicit
 'out'-point.
 
 Note that the PTS values are zero-based and continouus. If you want absolute
 PTS values, you can either:
 - use the .ap file, find discontinuities, and interpolate between the APs
 - or just use the first PTS value as an offset, and work around PTS
 wraparounds. (simple method)
 */

public struct CutsTimeConst {
  public static let PTS_DURATION : Double = (1.0/90000.0) // seconds
  public static let PTS_TIMESCALE : Int32 = 90000
}

struct MessageStrings {
  static let NO_SUCH_FILE = "No Such File"
  static let FOUND_FILE = "Found File"
  static let CAN_CREATE_FILE = "Success on file creation"
  static let DID_WRITE_FILE = "Success of replacement"
}

struct FieldStrings {
  static let IN = "IN"
  static let OUT = "OUT"
  static let  BOOKMARK = "BOOKMARK"
  static let LASTPLAY = "LASTPLAY"
}

public enum MARK_TYPE : UInt32
{
  // note: UInt32 is doco--- swift thinks it knows better and uses 1 byte !!!
  // hence later convoluted code to ensure serialized file entry is 32 bits
  case IN  = 0
  case OUT = 1
  case BOOKMARK = 2
  case LASTPLAY = 3
  
  func description () -> String {
    switch self
    {
    case .IN : return FieldStrings.IN
    case .OUT : return FieldStrings.OUT
    case .BOOKMARK : return FieldStrings.BOOKMARK
    case .LASTPLAY : return FieldStrings.LASTPLAY
    }
  }
  
  static func lookupOnRawValue(_ raw : UInt32) -> MARK_TYPE?
  {
    switch (raw)
    {
    case IN.rawValue : return .IN
    case OUT.rawValue : return .OUT
    case BOOKMARK.rawValue : return .BOOKMARK
    case LASTPLAY.rawValue  : return .LASTPLAY
    default : return nil
    }
  }
}

/// structure with PTS and MARK_TYPE
/// and sundry supporting functions to convert
/// textural formats
public struct  CutEntry {
  var cutPts  : UInt64
  var cutType : UInt32
  
  // debug support functions
  func asHex () -> String{
    let hexRep = String(format: "%16.16lx:%8.8x", cutPts, cutType)
    return hexRep
  }
  func asDecimal () -> String{
    let decimalRep = String(format: "%ld : %ld" , cutPts, cutType)
    return decimalRep
  }
  
  func asSeconds() -> Double
  {
    return Double(self.cutPts) * CutsTimeConst.PTS_DURATION
  }
  
  static func hhMMssFromSeconds(_ seconds: Double) -> String
  {
    var inputSeconds = seconds
    var remainderSeconds = inputSeconds.truncatingRemainder(dividingBy: 60.0)
    if (60.0 - remainderSeconds) < 0.5 {
      remainderSeconds = 0.0
      inputSeconds += 0.5
    }
    let minutes = inputSeconds / 60.0
    
    let hours = minutes / 60.0
    let days = hours / 24.0
    let intMinutes = Int(minutes) % 60
    let intHours = Int(hours) % 24
    let intDays = Int(days)
    // compose significant elements only
    var result = String.init(format: "%02.0fs", remainderSeconds)
    if (intMinutes > 0  || intHours>0 || intDays > 0) {
      result = String.init(format: "%2.2d:\(result)", intMinutes)
    }
    if (intHours > 0 || intDays > 0)
    {
      result = String.init(format: "%2.2d:%@", intHours, result)
    }
    if (intDays>0) {
      result = String.init(format: "%:%@", intDays, result)
    }
    return result
  }
  
  static public func timeTextFromPTS(_ ptsCount : UInt64) -> String {
    return hhMMssFromSeconds(Double(ptsCount) * CutsTimeConst.PTS_DURATION)
  }
  
  func asString() -> String {
    if let markType = MARK_TYPE(rawValue: cutType) {
     return "\(markType) " + CutEntry.timeTextFromPTS(self.cutPts)
    }
    else {
      return "Unknown Mark Type code \(cutType) " + CutEntry.timeTextFromPTS(self.cutPts)
    }
  }
  
  init(cutPts:UInt64, cutType:UInt32)
  {
    self.cutPts = cutPts
    self.cutType = cutType
  }
}

// this seems a nonsense if struct are "Value Type" they ought to be
// implicitly equatable ..... but there you go....
extension CutEntry: Equatable {}

public func == (lhs: CutEntry, rhs: CutEntry) -> Bool
{
//  return lhs == rhs
  return lhs.cutPts == rhs.cutPts && lhs.cutType == rhs.cutType
}

public func != (c1: CutEntry, c2: CutEntry) -> Bool
{
  return c1.cutPts != c2.cutPts || c1.cutType != c2.cutType
}

// operators for ordering by time, ordering by type is not useful

extension CutEntry: Comparable {}

public func < (c1: CutEntry, c2: CutEntry) -> Bool
{
  return c1.cutPts < c2.cutPts
}

public func > (c1: CutEntry, c2: CutEntry) -> Bool
{
  return c1.cutPts > c2.cutPts
}


