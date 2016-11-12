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
  
  var debug = false
  var apFileName: String
  private(set) var hasGaps : Bool = false
  private(set) var runtimePTS: PtsType
  var container: Recording?
  
  init() {
    runtimePTS = PtsType(0)
    apFileName = "unassiged"
  }
  
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
    runtimePTS = deriveRunTimePTS()
  }
  
  /// Initialize from raw contents, typically content of file
  /// Contrived to ensure that collection maintained in order
  /// sorted by file offset.
  convenience init?( data: Data) {
    self.init()
    var d = [UInt64](repeating: 0, count: 2)
    var sorted = true
    var lastOffset = OffType(0)
    let dataElementCount = data.count/MemoryLayout<UInt64>.size
    var index = 0
    let littleEndian = data.withUnsafeBytes {
      Array(UnsafeBufferPointer<UInt64>(start: $0, count: data.count/MemoryLayout<UInt64>.size))
    }
    while (index < dataElementCount)
    {
      d[0] = littleEndian[index].bigEndian  // file offset
      d[1] = littleEndian[index+1].bigEndian  // pts
      let pair = OffPts(d[0], d[1])
      // monitor if file is in file offset sorted order or not
      sorted = sorted && (lastOffset < d[0])
      lastOffset = d[0]
      m_access_points_array.append(pair)
      index += 2
    }
    // order the map by offset if it has loaded unordered
    if (!sorted) { m_access_points_array.sort{$0.offset < $1.offset}}
    
    runtimePTS = deriveRunTimePTS()
  }
  
  /// Open and decode the file into the internal structures
  /// Contrived to ensure that collection maintained in order
  /// sorted by file offset.
  /// - parameter filename: full path the to file
  /// - returns: success or failure of load collection
  
  func loadAP(_ filename: URL) -> Bool
  {
    let path = (filename as NSURL).filePathURL?.path
    var attributes : NSDictionary?
    do {
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
    /// working buffer
    var d = [UInt64](repeating: 0, count: 2)
    var sorted = true
    var lastOffset = OffType(0)
    /// read 16 bytes each time until we run out of data
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
    // order the map by offset if it has loaded unordered
    if (!sorted) { m_access_points_array.sort{$0.offset < $1.offset}}
    runtimePTS = deriveRunTimePTS()
    return true
  }
  
  /// Find the highest PTS value within the collection that is greater
  /// than the PTS at the start Index.  This is useful for finding
  /// the upper limit when there is a discontinuity in the file and 
  /// the PTS values restart at 0 mid program. (Rollover of the PCR)
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
  func simpleDurationInPTS() -> PtsType {
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
    return Double(runtimePTS) * CutsTimeConst.PTS_DURATION
  }
  
  /// wrapper converting secs to HH:MM:SS format
  /// - returns: formatted string
  func durationInHMS() -> String
  {
    return CutEntry.hhMMssFromSeconds(durationInSecs())
  }
  
  /// return the simple last pts - first pts calculated duration
  /// can be wrong if there are breaks in the PTS sequences
  func simpleDurationInHMS() -> String
  {
    return CutEntry.hhMMssFromSeconds(Double(simpleDurationInPTS()) * CutsTimeConst.PTS_DURATION)
  }
  
  /// Determine the runtime of a recording bye checking for "gaps" or breaks in the PTS sequencing.
  /// This happens when advertisement have been edited out of a recording.
  /// The corresponding entries have been removed resulting in a smooth file offset sequence but a jump in the PTS
  /// The lack of PTS compenstation in the ap/ts files means that (last-first) calculation for runtime is incorrect
  /// A approximately valid run time can only be determined by summing the pts deltas
  /// A typical PTS offset is about .4 secs
  /// - returns: runtime calculated in PCR ticks (1/90000 of a sec)
  private func deriveRunTimePTS() -> PtsType
  {
     // analyze for gaps
    guard m_access_points_array.count > 0 else {
      return PtsType(0)
    }
    var deltaSecs: Double
    var lastDeltas: String
    var seqStart = 0
    var ptsDiscontinuity = false
    let last = m_access_points_array.count-1
    var cummulativeDurationPTS = PtsType(0)
    if (debug) {
      print("checking Ap for \(container?.movieName! ?? apFileName)")
      print("Simple duration: \(simpleDurationInHMS())")
    }
    for index in 0 ..< last-1
    {
      let entry  = m_access_points_array[index]
      let entry2 = m_access_points_array[index+1]
      if entry2.pts > entry.pts {
         let delta1 = Double(entry2.pts - entry.pts)*CutsTimeConst.PTS_DURATION
         let deltaInt = Int(delta1*10)
         deltaSecs = Double(deltaInt)/10.0
         lastDeltas =  String("deltas \(delta1): \(deltaInt) : \(deltaSecs)")
      }
      else {
        // pts discontinuity, treat as virtual gap
        lastDeltas = "--------- undetermined"
        // ascribe an "typical step"
        deltaSecs = 3.0
        ptsDiscontinuity = true
      }
      // check for significant break in sequence of ap's
      // accumulate duration and reset for next sequence
      if (deltaSecs > 30.0 || ptsDiscontinuity) {
        if (debug) {
           print(lastDeltas)
           print("[\(index)] - \(entry.pts)/\(entry2.pts)  - \(Int(Double(entry.pts) * CutsTimeConst.PTS_DURATION))/\(Int(Double(entry2.pts)*CutsTimeConst.PTS_DURATION)) delta = \(deltaSecs)")
        }
        let sequenceDurationPTS = m_access_points_array[index].pts - m_access_points_array[seqStart].pts
        cummulativeDurationPTS += sequenceDurationPTS
        if (debug) {
          let sequenceDurationSecs = Double(sequenceDurationPTS) * CutsTimeConst.PTS_DURATION
          let sequenceDurationHMS = CutEntry.hhMMssFromSeconds(sequenceDurationSecs)
          let runTimeSecs = Double(cummulativeDurationPTS)*CutsTimeConst.PTS_DURATION
          let readableCummulativeTime = CutEntry.hhMMssFromSeconds(runTimeSecs)
          print("\(sequenceDurationPTS) - \(cummulativeDurationPTS): \(sequenceDurationHMS) - \(readableCummulativeTime)")
        }
        seqStart = index+1
        ptsDiscontinuity = false
      }
    }
    let sequenceDurationPTS = m_access_points_array[last].pts - m_access_points_array[seqStart].pts
    cummulativeDurationPTS += sequenceDurationPTS
    if (debug) {
      let runTimeSecs = Double(cummulativeDurationPTS)*CutsTimeConst.PTS_DURATION
      let readableTime = CutEntry.hhMMssFromSeconds(runTimeSecs)
      print("Run time of \(cummulativeDurationPTS) pts / \(readableTime)")
    }
    self.hasGaps = (seqStart != 0)
    return cummulativeDurationPTS
  }
}
