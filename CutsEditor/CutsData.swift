//
//  CutsData.swift
//  CutsEditor
//
//  Created by Alan Franklin on 3/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//
//  Defines a single entry in the .cuts file

import Foundation
/*
 from the NET
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

/// Constants for working with PTS time units
public struct CutsTimeConst {
  public static let PTS_DURATION : Double = (1.0/90000.0) // seconds
  public static let PTS_TIMESCALE : Int32 = 90000
}

/// Text string associated with enum MARK_TYPE
struct FieldStrings {
  static let IN = "IN"
  static let OUT = "OUT"
  static let  BOOKMARK = "BOOKMARK"
  static let LASTPLAY = "LASTPLAY"
}

/// Enum to capture the current set of marks that the cuts file can contain
public enum MARK_TYPE : UInt32
{
  // note: UInt32 is doco --- swift thinks it knows better and uses 1 byte !!!
  // hence later convoluted code to ensure serialized file entry is 32 bits
  case IN  = 0
  case OUT = 1
  case BOOKMARK = 2
  case LASTPLAY = 3
  
  /// Return a textural value for the enum I18N'able
  
  func description () -> String {
    switch self
    {
    case .IN : return FieldStrings.IN
    case .OUT : return FieldStrings.OUT
    case .BOOKMARK : return FieldStrings.BOOKMARK
    case .LASTPLAY : return FieldStrings.LASTPLAY
    }
  }
  
  /// Given a suitable number try to return a MARK_TYPE
  /// - parameter raw: value of enum
  /// - returns : valid enum or nil
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
/// textural formats, perform comparions etc.
public struct  CutEntry {
  var cutPts  : UInt64
  var cutType : UInt32
  var type : MARK_TYPE? {
    get {
      return MARK_TYPE.lookupOnRawValue(self.cutType)
    }
    set {
      self.cutType = (newValue?.rawValue)!
    }
  }
  
  /// designated initializer
  init(cutPts:UInt64, cutType: UInt32)
  {
    self.cutPts = cutPts
    self.cutType = cutType
  }
  
  /// Constructor that masks underlying values for cut types
  init(cutPts: UInt64, mark: MARK_TYPE)
  {
    self.cutPts = cutPts
    self.cutType = mark.rawValue
  }
  
  /// A useful "0" entry for IN marks - ie start of recording
  static var InZero: CutEntry {
    get {
      return CutEntry(cutPts: UInt64(0), cutType: MARK_TYPE.IN.rawValue)
    }
  }
  
  // debug support functions
  /// Convert to string with hex values
  func asHex () -> String{
    let hexRep = String(format: "%16.16lx:%8.8x", cutPts, cutType)
    return hexRep
  }
  
  /// Convert to string with decimal values
  func asDecimal () -> String{
    let decimalRep = String(format: "%ld : %ld" , cutPts, cutType)
    return decimalRep
  }
  
  /// Convert PTS to seconds
  func asSeconds() -> Double
  {
    return Double(self.cutPts) * CutsTimeConst.PTS_DURATION
  }
  
  /// Convert N seconds in to HH:MM:SS[.ss] format for display
  static func hhMMssFromSeconds(_ seconds: Double, resolution:Double) -> String
  {
    var inputSeconds = seconds
    var remainderSeconds = inputSeconds.truncatingRemainder(dividingBy: 60.0)
    // rounding
    if (60.0/resolution - remainderSeconds/resolution) < 0.5 {
      remainderSeconds = 0.0
      inputSeconds += 0.5/resolution
    }
    let minutes = inputSeconds / 60.0
    
    let hours = minutes / 60.0
    let days = hours / 24.0
    let intMinutes = Int(minutes) % 60
    let intHours = Int(hours) % 24
    let intDays = Int(days)
    // compose significant elements only
    var result = String.init(format: "%04.2f", remainderSeconds)
    if (intMinutes > 0  || intHours>0 || intDays > 0) {
      result = String.init(format: "%2.2d:\(result)", intMinutes)
    }
    if (intHours > 0 || intDays > 0)
    {
      result = String.init(format: "%2.2d:%@", intHours, result)
    }
    if (intDays>0) {
      result = String.init(format: "%d:%@", intDays, result)
    }
    return result
  }
  
  /// Convert N seconds in to HH:MM:SS.ss format for display
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
    var result = String.init(format: "%02.0f", remainderSeconds)
    if (intMinutes > 0  || intHours>0 || intDays > 0) {
      result = String.init(format: "%2.2d:\(result)", intMinutes)
    }
    if (intHours > 0 || intDays > 0)
    {
      result = String.init(format: "%2.2d:%@", intHours, result)
    }
    if (intDays>0) {
      result = String.init(format: "%d:%@", intDays, result)
    }
    return result
  }
  
//  /// Convert PTS value to HH:MM:SS string
//  static public func timeTextFromPTS(_ ptsCount : UInt64) -> String {
//    return hhMMssFromSeconds(Double(ptsCount) * CutsTimeConst.PTS_DURATION)
//  }
  
  /// Return entry as printable string
  func asString() -> String {
    if let markType = MARK_TYPE(rawValue: cutType) {
//      return "\(markType) " + CutEntry.timeTextFromPTS(self.cutPts)
      return "\(markType) " + self.cutPts.hhMMss
    }
    else {
//      return "Unknown Mark Type code \(cutType) " + CutEntry.timeTextFromPTS(self.cutPts)
      return "Unknown Mark Type code \(cutType) " + self.cutPts.hhMMss
    }
  }
  
  /// Return entry with fine numeric detail
  func asStringDecimal() -> String {
    if let markType = MARK_TYPE(rawValue: cutType) {
      let timeStamp = String(format:"%ld", self.cutPts)
      return "\(markType) " + timeStamp
    }
    else {
//      return "Unknown Mark Type code \(cutType) " + CutEntry.timeTextFromPTS(self.cutPts)
      return "Unknown Mark Type code \(cutType) " + self.cutPts.hhMMss
    }

  }
}

// this seems a nonsense if struct are "Value Type" they ought to be
// inherently equatable ..... but there you go.... new languages take time to get "sensible"
extension CutEntry: Equatable {}

/// Operator equals
public func == (lhs: CutEntry, rhs: CutEntry) -> Bool
{
  return lhs.cutPts == rhs.cutPts && lhs.cutType == rhs.cutType
}

/// Operator not Equals
public func != (c1: CutEntry, c2: CutEntry) -> Bool
{
  return c1.cutPts != c2.cutPts || c1.cutType != c2.cutType
}

/// operators for ordering by time, ordering by type is not useful
extension CutEntry: Comparable {}

/// Operator less than
public func < (c1: CutEntry, c2: CutEntry) -> Bool
{
  return c1.cutPts < c2.cutPts
}

/// Operator greater than
public func > (c1: CutEntry, c2: CutEntry) -> Bool
{
  return c1.cutPts > c2.cutPts
}


