//
//  AccessPoints.swift
//  CutsEditor
//
//  Created by Alan Franklin on 20/08/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation

typealias PtsOff = (pts: PtsType, offset: OffType)

/// Loads a ProgramName.ts.ap file which is a map of pts and file offsets for a ts file
/// for each GOP header in the file,  used by streamer to fast forward through
/// the file without having and read and decode every frame, by giving if file
/// file offset that guarantees a GOP start point

class AccessPoints {
  
//  var m_access_points = Dictionary<OffType,PtsType>()
  var m_access_points_array = [OffPts]()
  /// Derived PTS value of first GOP found if any
  var firstPTS: PtsType { return (m_access_points_array.count>0) ? m_access_points_array[0].pts : PtsType(0) }
  /// Derived PTS value of last GOP seen if any
  var lastPTS: PtsType { return (m_access_points_array.count>0) ? m_access_points_array[m_access_points_array.count-1].pts : PtsType(0)}
  
  var debug = true
  var apFileName = ""
  
  /// given full path filename, open related file
  /// which in this context means the .ts.ap
  
  /// Intializer where filename is the full path to the file
  /// - parameter fullpath : full pathname to zzzzzzzz.ts.ap file
  
  convenience init?( fullpath: URL) {
    self.init()
    if (!self.loadAP(fullpath)) {
      return nil
    }
    apFileName = fullpath.path
  }
  
  /// Open and decode the file into the internal structures
  /// - parameter filename: full path the to file
  
  func loadAP(_ filename: URL) -> Bool
  {
    let path = (filename as NSURL).filePathURL?.path
    var attributes : NSDictionary?
    do {
//      print("-------------------------->  Getting Attributes for \(path!)")
      attributes = try FileManager.default.attributesOfItem(atPath: path!) as NSDictionary?
      if let size = attributes?.fileSize()
      {
        if size == 0  { return false }
      }
    }
    catch _ {
      attributes = nil
      return false
    }
    
    let Cpath = path!.cString(using: String.Encoding.utf8)!
    let f = fopen(Cpath, ("rb").cString(using: String.Encoding.utf8))
    if (f == nil)
    {
      return false
    }
//    print("\n\n file order \n\n")
    var d = [UInt64](repeating: 0, count: 2)
    var sorted = true
    var lastOffset = OffType(0)
    while (true)
    {
      if (fread(&d, 16, 1, f) < 1)
      {
        break
      }
      else
      {
        d[0] = d[0].bigEndian  // file offset
        d[1] = d[1].bigEndian  // pts
        let pair = OffPts(d[0], d[1])
        // monitor if file is in file offset sorted order or not
        sorted = sorted && (lastOffset < d[0])
        lastOffset = d[0]
        m_access_points_array.append(pair)
      }
    }
    fclose(f)
    // order the map by offset
    if (!sorted) { m_access_points_array.sort{$0.offset < $1.offset}}
    return true
  }
  
  /// Find the highest PTS value within the array that is greater
  /// than the PTS at the start Index.  This is useful for finding
  /// the upper limit when there is a discontinuity in the file and 
  /// the PTS values reset to 0 mid program
  /// - parameter startIndex: start position in the array
  /// - return: tuple of the ptsValue and the index at which is is found
  
  fileprivate func highestPTSFrom (_ startIndex: Int) -> (pts: PtsType, ptsIndex: Int) {
    var found = false
    var nextPTS:PtsType
    var lastPTS:PtsType
    var ptsIndex = startIndex+1
    lastPTS = m_access_points_array[startIndex].pts
    nextPTS = lastPTS
    while (!found && ptsIndex < m_access_points_array.count) {
      if m_access_points_array[ptsIndex].pts > lastPTS {
        // keep going
        ptsIndex += 1
      }
      else { // found discontinuity
        found = true
        ptsIndex -= 1
        nextPTS = m_access_points_array[ptsIndex].pts
      }
    }
    if (!found) {  // ran off end of file -> found the last value without discontinuity
      ptsIndex -= 1  // bring in bounds
      nextPTS = m_access_points_array[ptsIndex].pts
    }
    return (nextPTS, ptsIndex)
  }
  
  /// The derived from ".ap" file duration of the ".ts" file in PTS units
  /// - return: duration in PTS
  func durationInPTS() -> PtsType {
    var returnDuration = PtsType(0)
    if firstPTS > lastPTS {
      if (debug) { print("saw discontinuity \(firstPTS) vs \(lastPTS) :\(apFileName)") }
      var cummulativeDuration = PtsType(0)
      // we have discontinuity to deal with find the highest PTS from start
      let result = highestPTSFrom(0)
      cummulativeDuration += (result.pts - firstPTS)
      
      // now seek forward from last position until we match then end of file
      var ptsIndex = result.ptsIndex + 1
      if (ptsIndex < m_access_points_array.count) {
        var found = false
        while (!found && ptsIndex < m_access_points_array.count) {
          let startPTS = m_access_points_array[ptsIndex].pts       // start PTS value each time through the loop
          found = m_access_points_array[ptsIndex].pts == lastPTS
          if (!found) {
            let result = highestPTSFrom(ptsIndex)
            cummulativeDuration += (result.pts - startPTS)
            ptsIndex = result.ptsIndex+1
          }
        }
      }
      returnDuration = cummulativeDuration
    }
    else {
      returnDuration = lastPTS - firstPTS
    }
    return returnDuration
  }
  
  /// The calculated duration of the file from the ap details
  /// - return: duration of recording in Seconds
  func durationInSecs() -> Double
  {
    return Double(durationInPTS()) * CutsTimeConst.PTS_DURATION
  }
}
