//
//  AccessPoints.swift
//  CutsEditor
//
//  Created by Alan Franklin on 20/08/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation
import AVFoundation

typealias PtsOff = (pts: PtsType, offset: OffType)

let badApLoadThreshold = 1_200_000  // only a really long recording should trigger this - typical GOP is 0.5 secs
// so this 600_000 secs ~= 10_000 mins ~= 167 hours ~= 1 week

/// Loads a ProgramName.ts.ap file which is a map of pts and file offsets for a ts file
/// for each GOP header in the file,  used by streamer to fast forward through
/// the file without having and read and decode every frame, by giving it a
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
  
  /// flag that indicates a movie that may have had advertisements removed which
  /// results in there being gaps in sequence
  private(set) var hasGaps : Bool = false
  private var sequenceHasGaps : Bool = false
  
  /// flag to be initialized on startup to check if there was a PCR clock reset
  /// during the movie which results in the PTS going back to zero.  Used to assist
  /// code that is hunting within the PTS sequence
  private(set) var hasPCRReset: Bool
  /// array of indices where the PCR reset occurs and PTS numbering  re-starts
  private(set) var pcrIndices = [Int]()
  
  /// flag that gapIndices is populated
  private(set) var hasGapIndices:Bool
  /// arrar of indices where a gap starts (end index of video)
  private(set) var gapIndices = [Int]()
  
  /// duration in PTS units, calculated.
  private(set) var runtimePTS: PtsType
  var container: Recording?
  
  init() {
    runtimePTS = PtsType(0)
    hasPCRReset = false
    hasGapIndices = false
    apFileName = "unassigned"
  }
  
  /// given full path filename, open related file
  /// which in this context means the .ts.ap
  
  /// Intializer where filename is the full path to the file
  /// - parameter fullpath : full pathname to zzzzzzzz.ts.ap file
  
  convenience init?( url: URL) {
    self.init()
    if (!self.loadAP(url)) {
      return nil
    }
    apFileName = url.path
    self.postInitSetup()
  }
   
  /// Initialize from raw contents, typically content of file
  /// Contrived to ensure that collection maintained in order
  /// sorted by file offset.
  convenience init?( data: Data, fileName: String)
  {
    self.init()
    self.apFileName = fileName
    var d = [UInt64](repeating: 0, count: 2)
    var offsetSorted = true
    var ptsSorted = true
    var lastOffset = OffType(0)
    var lastPts = PtsType(PtsType.max)
    let dataElementCount = data.count/MemoryLayout<UInt64>.size
    // for an unknown reason binary loads of data have returned crazy (200 Gb) array
    // counts for ap files.  So this is sanity check on the Data being offered
    guard (dataElementCount*8 < badApLoadThreshold) else {
      print("Got crazy data with size count of \(dataElementCount*8) bytes")
      return nil
    }
    var index = 0
//    let littleEndian = data.withUnsafeBytes {
//      Array(UnsafeBufferPointer<UInt64>(start: $0, count: data.count/MemoryLayout<UInt64>.size))
//    }
    
    let chunkCount = data.count/MemoryLayout<UInt64>.size
    var littleEndian:[UInt64] = Array(repeating: 0, count: chunkCount)
    littleEndian.withUnsafeMutableBytes { destBytes in
      data.withUnsafeBytes { srcBytes in
        destBytes.copyBytes(from: srcBytes)
      }
    }
    
//    // comparison check of old and new code
//    for index in 0..<fred.count{
//      if (littleEndian[index] != fred[index])
//      {
//        print(" argh bugger!")
//      }
//    }
    
    while (index+1 < dataElementCount)
    {
      d[0] = littleEndian[index].bigEndian  // file offset
      d[1] = littleEndian[index+1].bigEndian  // pts
      let pair = OffPts(d[0], d[1])
      // monitor if file is in file offset sorted order or not
      offsetSorted = offsetSorted && (lastOffset < d[0])
      ptsSorted = ptsSorted && (lastPts > d[1])
      lastOffset = d[0]
      lastPts = d[1]
      m_access_points_array.append(pair)
      index += 2
    }
    // order the map by offset if it has loaded unordered
    if (!offsetSorted) {
      m_access_points_array.sort{$0.offset < $1.offset}
      print("WARNING: unsorted offset access points")
    }
    if (!ptsSorted) {
//      m_access_points_array.sort{$0.pts < $1.pts}
      print("WARNING: unsorted pts (PCR ?)")
    }
    
    self.postInitSetup()
  }
  
  func postInitSetup()
  {
    let resetCheck = checkForPCRReset()
    hasPCRReset = resetCheck.hasReset
    if hasPCRReset {
      self.pcrIndices = resetCheck.indexArray
    }
    runtimePTS = deriveRunTimePTS()
    let gaps = checkForPTSGaps()
    if gaps.hasGap {
      gapIndices = gaps.indexArray
    }
    
  }
  /// Open and decode the file into the internal structures
  /// Contrived to ensure that collection maintained in order
  /// sorted by file offset.
  /// - parameter filename: full path the to file
  /// - returns: success or failure of load collection
  /// Beware of ap files that cross a PCR Reset this will
  /// result in incorrectly ordered AP file
  
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
    
    // FIXME: this code does not allow for PCR Reset clean handling
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
    return runtimePTS.asSeconds
  }
  
  /// wrapper converting secs to HH:MM:SS format
  /// - returns: formatted string
  func durationInHMS() -> String
  {
//    return CutEntry.hhMMssFromSeconds(durationInSecs())
    return durationInSecs().hhMMss
  }
  
  /// return the simple last pts - first pts calculated duration
  /// can be wrong if there are breaks in the PTS sequences
  func simpleDurationInHMS() -> String
  {
//    return CutEntry.hhMMssFromSeconds(simpleDurationInPTS().asSeconds)
    return simpleDurationInPTS().hhMMss
  }
  
  /// Determine the runtime of a recording bye checking for "gaps" or breaks in the PTS sequencing.
  /// This happens when advertisement have been edited out of a recording.
  /// The corresponding entries have been removed resulting in a smooth file offset sequence but a jump in the PTS
  /// The lack of PTS compensation in the ap/ts files means that (last-first) calculation for runtime is incorrect
  /// A approximately valid run time can only be determined by summing the pts deltas
  /// A typical PTS offset is about .4 secs
  /// - returns: runtime calculated in PCR ticks (~1/90000 of a sec)
  private func deriveRunTimePTS() -> PtsType
  {
    guard m_access_points_array.count > 1 else {
      return PtsType(0)
    }
    
    let runTimeDurationPTS = deriveRunTimePTSBetweenIndices(startIndex: 0, endIndex: m_access_points_array.count-1)
    self.hasGaps = self.sequenceHasGaps
    return runTimeDurationPTS
  }
  
  
  //  func nearestApIndexForPTSFromAp(ptsValue: PtsType) -> Int
  //  {
  //    return 0
  //  }
  
  /// given a CMTime from the player convert it into a TS PTS time
  /// and use the ap values and gap checking to determine an actual elapsed time to
  /// drive the timelime control
  
  func elapsedTimeFromPlayerTime(_ playerTime: CMTime) -> CMTime
  {
    // if there are no gaps or a clock reset, then the player time is good
    guard self.hasGaps || self.hasPCRReset else {
      return playerTime
    }
    let videoSegments = videoSequences
    let playerPTS = PtsType(playerTime.convertScale(CutsTimeConst.PTS_TIMESCALE, method: CMTimeRoundingMethod.default).value)
    // short cut if before first gap
    if videoSegments.count > 0 {
      if playerPTS.asSeconds < videoSegments[0].videoDurationSeconds
      {
        return playerTime
      }
    }
    
    // PTS from the player will be "related" to the stored PTS values in the TS file
    // thus, to get a "played video" time we need to discount any gaps that we have passed over
    //    print ("playerTime \(playerTime)")
    if (debug) { print ("playerPTS \(playerPTS.hhMMss)") }
    let apIndex = nearestApIndexForPTSFromPlayer(ptsValue: playerPTS)
    //    print ("apIndex = \(apIndex)")
    let endPTS = deriveRunTimeDurationToIndex(endIndex: apIndex)
    //    print ("endPTS = \(endPTS.asSeconds)")
    let videoElapsedTime = CMTime(value: CMTimeValue(endPTS), timescale: CutsTimeConst.PTS_TIMESCALE)
    //    print ("videoElapsed \(videoElapsedTime)")
    let  playerElapsedtime = videoElapsedTime.convertScale(playerTime.timescale, method: CMTimeRoundingMethod.default)
    //    print ("playerElapsedtime = \(playerElapsedtime)")
    return playerElapsedtime
  }
  
  
  /// find the ap index nearest the given PTS
  /// - parameter ptsValue: zero based pts to look for (expected to come from player being 0 based)
  /// - returns: index of ap array or -1 if no such entry exists in ap array
  func nearestApIndexForPTSFromPlayer(ptsValue: PtsType) -> Int
  {
    guard m_access_points_array.count > 2 else {
      return -1
    }
    var adjustedPtsValue = ptsValue + self.firstPTS
    // cannot use binary search due to clock resets, the sequence may restart midstream
    // O(n) but how else ?
    var index = 0
    var found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
    while (!found && index < m_access_points_array.count-2)
    {
      index += 1
      let low = m_access_points_array[index].pts
      let hi = m_access_points_array[index+1].pts
      if hi < low {
        // PCR clock reset has happened
        // simple case, target is greater than next pts number
        if adjustedPtsValue > hi && index < m_access_points_array.count-2  // reset indices and continue
        {
          // readjust target into next range by reducing it by the last highest seen
          adjustedPtsValue -= low
          index += 1
          found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
        }
        else {
          found = true
          // what is the pts delta to the last index entry ?
          let ptsDelta = adjustedPtsValue - m_access_points_array[index].pts
          if ptsDelta > 2*(m_access_points_array[index].pts - m_access_points_array[index-1].pts) {
            // !argh this is too big a difference .. give up
            index = -1
          }
        }
      }
      else {
        found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
        if (debug) {
          print("value=\(adjustedPtsValue), curr = \(m_access_points_array[index].pts), next\(m_access_points_array[index+1].pts), at index \(index)")
        }
        if found {
          // pick the nearest
          index =  ((adjustedPtsValue - m_access_points_array[index].pts) < (m_access_points_array[index+1].pts - adjustedPtsValue)) ? index : index+1
        }
      }
    }
    return index
  }
  
  /// find the ap index nearest to given PTS.  This function uses a binary search
  /// and assumes that bounded array of pts values are ordered and increasing in value
  /// (that is: don't call unprotected by PCRReset check)
  /// - parameter ptsValue: adjusted for range base,
  /// - parameter startIndex: lowest index in access points array to limit search
  /// - paraneter endIndex: highest index in access points array to limit search
  /// - returns: index of ap array or -1 if no such entry exists in ap array
  func nearestApIndexInRangeSerial(ptsValue adjustedPtsValue: PtsType, startIndex: Int, endIndex: Int) -> Int
  {
    guard (self.hasPCRReset == false) else { return -1}
    
    var index = startIndex
    var found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
    while (!found && index < endIndex-1)
    {
      index += 1
      found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
      if found {
        // pick the nearest
        index =  ((adjustedPtsValue - m_access_points_array[index].pts) < (m_access_points_array[index+1].pts - adjustedPtsValue)) ? index : index+1
      }
    }
    return index
  }
  
  /// Calculate and return cumulative "removed" gaps before the give PTS value
  /// time is zero based
  func gapsBeforeInSeconds(_ ptsTime: PtsType) -> Double
  {
    return gapsBetweenTimes(start:PtsType(0), end: ptsTime)
  }
  
  /// Determine to duration in seconds of all the gaps
  /// after the given time
  func gapsBetweenTimes(start startPTS: PtsType, end endPTS: PtsType) -> Double
  {
    var gapTime: Double = 0.0
    guard hasGaps else { return gapTime }
    
    var elapsedTime: Double = 0.0
    
    // find sequence that contains start time
    if (debug) {
      print (#function + "start \(startPTS.asSeconds), end = \(endPTS.asSeconds)")
      print ("\(videoSequences)")
    }
    var segmentIndex = 0
    var segment = videoSequences[segmentIndex]
    
    while (startPTS.asSeconds > elapsedTime && segmentIndex+1 < videoSequences.count)
    {
      segmentIndex += 1
      segment = videoSequences[segmentIndex]
      elapsedTime += segment.segementSeconds
    }
    
    // count the gaps until we find the segment that contains the end time
    while endPTS.asSeconds > elapsedTime && segmentIndex < videoSequences.count
    {
      if endPTS.asSeconds < (elapsedTime + segment.videoDurationSeconds)
      {
        break
      }
      else {
        elapsedTime += segment.segementSeconds
        gapTime += segment.gapSeconds != nil ? segment.gapSeconds!: 0
      }
    }
    if (debug) { print("returning gapTime of \(gapTime) for gaps between \(startPTS.hhMMss) and \(endPTS.hhMMss)") }
    return gapTime
  }
  
  
  /// find the ap index nearest to given PTS.  This function uses a binary search
  /// and assumes that bounded array of pts values are ordered and increasing in value
  /// (that is: don't call unprotected by PCRReset check)
  /// - parameter ptsValue: base adjusted ptsValue
  /// - parameter startIndex: lowest index in access points array to limit search
  /// - paraneter endIndex: highest index in access points array to limit search
  /// - returns: index of ap array or -1 if no such entry exists in ap array
  func nearestApIndexInRangeBinary(ptsValue adjustedPtsValue: PtsType, startIndex: Int, endIndex: Int) -> Int
  {
    guard (self.hasPCRReset == false) else {return -1}
    
    var index = startIndex
    var lowIndex = startIndex
    var hiIndex = endIndex
    var found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
    while (!found && (hiIndex - lowIndex) > 1)
    {
      index = lowIndex + (hiIndex - lowIndex)/2
      found = adjustedPtsValue >= m_access_points_array[index].pts && adjustedPtsValue < m_access_points_array[index+1].pts
      if found {
        // pick the nearest
        index =  ((adjustedPtsValue - m_access_points_array[index].pts) < (m_access_points_array[index+1].pts - adjustedPtsValue)) ? index : index+1
      }
      else { // which way to jump ?
        if adjustedPtsValue > m_access_points_array[index].pts
        {
          lowIndex = index
        }
        else {
          hiIndex = index
        }
      }
    }
    return index
  }
  
  /*
   worked example in seconds to aid comprehension of code:
   we have position from player of 2400 seconds from a duration of 3600 seconds
   we have a access points array (seconds for comprehension) that of 7200 entries that
   covers it with values sets of 5000..6000, 100..1000, 200..1900 (1000+900+1700 === 3600)
   OK.
   so, take the 2400 add the first offset 5000 -> 7400
   which is not in the first bounds of 5000..6000
   to check the second bounds we need to take the
   postion, reduce it by the duration of the first bounds
   so, 2400 - (6000-5000) -> 1400
   now adjust the 1400 for the next range start offset 1400+100 -> 1500
   Now, is that in the bounds 100..1000 ? NO, then rinse and repeat
   2400 - (6000-5000) - (1000-100) -> 500
   again adjust for rannge start 500+200 -> 700
   now is that in bounds 200..1900 ? Yes, OK, now search for and return index nearest 700
   
   */
  
  /// find the ap index nearest the given PTS
  /// - parameter ptsValue: zero based pts to look for (expected to come from avplayer being 0 based)
  /// - returns: index of ap array or -1 if no such entry exists in ap array
  func nearestApIndex1(ptsValue: PtsType) -> Int
  {
    guard m_access_points_array.count > 2 else {
      return -1
    }
    var index = 0
    if (hasPCRReset)
    {
      // determine which sequence to use
      var found = false
      var index = 0
      var PTSdurationOfRange :PtsType = PtsType(0)
      
      // loop initializer
      let startIndex = 0
      let rangeStartPTS = m_access_points_array[startIndex].pts
      let endOfRangeIndex = pcrIndices[index+1]-1
      let rangeEndPTS = m_access_points_array[endOfRangeIndex].pts
      var adjustedPTSValue = ptsValue+firstPTS
      found = adjustedPTSValue >= rangeStartPTS && adjustedPTSValue <= rangeEndPTS
      if found {
        return nearestApIndexInRangeSerial(ptsValue: adjustedPTSValue, startIndex: startIndex, endIndex: endOfRangeIndex)
      }
      else {
        index += 1
        //                                      highest pts value in range  - lowest pts value in range
        PTSdurationOfRange = m_access_points_array[pcrIndices[index]-1].pts - m_access_points_array[0].pts
      }
      
      while (!found && index<=pcrIndices.count-1)
      {
        let startIndex = pcrIndices[index]
        let endIndex = (index+1 < pcrIndices.count) ? pcrIndices[index+1]-1 : m_access_points_array.count-1
        // check that ptsValue lies in range
        let rangeStartPTS = m_access_points_array[startIndex].pts
        let rangeEndPTS = m_access_points_array[endIndex].pts
        adjustedPTSValue = adjustedPTSValue - PTSdurationOfRange + m_access_points_array[startIndex].pts
        let found = adjustedPTSValue >= rangeStartPTS && adjustedPTSValue <= rangeEndPTS
        if found {
          return nearestApIndexInRangeSerial(ptsValue: adjustedPTSValue, startIndex: startIndex, endIndex: endIndex)
        }
        else {
          index += 1
          //                                      highest pts value in range  - lowest pts value in range
          PTSdurationOfRange = m_access_points_array[pcrIndices[index]-1].pts - m_access_points_array[0].pts
        }
      }
    }
    else // simple case
    {
      index = nearestApIndexInRangeSerial(ptsValue: ptsValue, startIndex: 0, endIndex: m_access_points_array.count-1)
    }
    return index
  }
  
  /// Scan serially through the ap array looking for a PCR reset (next sequential PTS being less that current)
  /// very long recordings may result in more that one.
  /// The result array is the indices of the lowest pts values, that is, the start indices
  /// - return: flag and array of reset indices.
  
  private func checkForPCRReset() -> (hasReset:Bool,  indexArray: [Int])
  {
    var resetFound = false
    var arrayOfResetPoints = [Int]()
    var startIndex = 0
    let endIndex = m_access_points_array.count - 1
    
    guard(startIndex >= 0 && endIndex >= 0) else { return (resetFound, arrayOfResetPoints) }
    
    // check for PTS discontinuity
    var notAtEnd = (startIndex+1) < endIndex
    while notAtEnd {
      let (_, ceilingIndex) = highestPTSFrom(startIndex)
      startIndex = ceilingIndex+1
      notAtEnd = ceilingIndex < endIndex
      if notAtEnd {
        arrayOfResetPoints.append(startIndex)
        resetFound = true
//        print("PCR Reset in \(self.apFileName)")
     }
    }
    return (resetFound, arrayOfResetPoints)
  }
  
  /// Scan serially through the ap array looking for a discontinuity (next sequential PTS substantially greater)
  /// The result array is the indices of the lowest pts values, that is, the start indices
  /// - return: flag and array of reset indices.
  
  private func checkForPTSGaps() -> (hasGap:Bool,  indexArray: [Int])
  {
    var gapFound = false
    var arrayOfGapPoints = [Int]()
    var startIndex = 0
    let endIndex = m_access_points_array.count - 1
    
    guard(startIndex >= 0 && endIndex >= 0) else { return (gapFound, arrayOfGapPoints) }
    
    // analyse ap array to determine nomimal GOP step for this movie
    var allChecked = startIndex+1 >= endIndex
    var buckets = [Int](repeating:0, count:101)
    while (!allChecked)
    {
      let thisAp = m_access_points_array[startIndex]
      let nextAp = m_access_points_array[startIndex+1]
      // ignor reset transitions
      if thisAp.pts < nextAp.pts {
        let deltaPTS = nextAp.pts - thisAp.pts
        // round to nearest 1/10 of a second
        var step = Int(deltaPTS/(UInt64(CutsTimeConst.PTS_TIMESCALE)/10))
        step = min(step,buckets.count-1)
        buckets[step] += 1
      }
      startIndex += 1
      allChecked = startIndex+1 >= endIndex
    }
    
    // find the highest non-zero index, excluding clear gaps
    var highestPopulatedIndex = 0
    for  i in 1...99 {
      if buckets[i] > 0 {
        highestPopulatedIndex = i
      }
    }
    //    print ("index \(highestPopulatedIndex): count \(buckets[highestPopulatedIndex])")
    
    // now find the gaps
    startIndex = 0
    allChecked = startIndex+1 >= endIndex
    while (!allChecked)
    {
      let thisAp = m_access_points_array[startIndex]
      let nextAp = m_access_points_array[startIndex+1]
      // ignor reset transitions
      if thisAp.pts < nextAp.pts {
        let deltaPTS = nextAp.pts - thisAp.pts
        // round to nearest 1/10 of a second
        let  step = Int(deltaPTS/(UInt64(CutsTimeConst.PTS_TIMESCALE)/10))
        if step > highestPopulatedIndex {
          arrayOfGapPoints.append(startIndex)
          gapFound = true
        }
      }
      startIndex += 1
      allChecked = startIndex+1 >= endIndex
    }
    return (gapFound, arrayOfGapPoints)
  }
  
  /// Convert the gap start ap array in a normalized array.
  var normalizedGaps : [Double]
  {
    get {
      var gapsArray = [PtsOff]()
      // note: swapping as m_access_points_array is [OffPts]
      gapsArray = gapIndices.map {(m_access_points_array[$0].pts,m_access_points_array[$0].offset)}
      var gapsPts = [PtsType]()
      // FIXME: handle gap after PCR Reset
      if hasPCRReset {
        for gap in gapsArray {
          if firstPTS < gap.pts {
            gapsPts.append(PtsType(gap.pts - self.firstPTS))
          }
          else {
            gapsPts.append(PtsType(gap.pts - m_access_points_array[pcrIndices[0]].pts))
          }
        }
      }
      else {
        gapsPts = gapsArray.map {return $0.pts - self.firstPTS}
      }
      let gapsNormalized = self.container!.cuts.normalizePTSArray(ptsArray: gapsPts, ignorGaps: false)
      return gapsNormalized
    }
  }
  
  /// Convert the pcr ap array in a normalized array.
  var normalizedPCRs : [Double]
  {
    get {
      var PCRsNormalized = [Double]()
      guard hasPCRReset else { return PCRsNormalized }
      let countAsDouble = Double(m_access_points_array.count)
      // near enough,
      PCRsNormalized = pcrIndices.map {Double($0)/countAsDouble}
      return PCRsNormalized
    }
  }
  
  /// Work out the duration in seconds of the gaps preceeding given time mark
  /// - parameter timeMark: actual played (able) time
  /// - returns: original elapsed time including gaps which is suitable as a "seekTo" value
  ///            for the player which only sees the PTS values
  func gapDuration(before timeMark: Double) -> Double
  {
    guard (hasGaps) else { return timeMark }
    
    let discontinuousSegmentsInSeconds = self.videoSequences
    var remaining = timeMark
    var offset = 0.0
    for segment in discontinuousSegmentsInSeconds
    {
      let video = segment.videoDurationSeconds
      let gap = segment.gapSeconds
      if remaining > video {
        remaining -= video
        offset += (video + (gap ?? 0.0))
      }
      else {
        offset += remaining
        break
      }
    }
    print("returing file postion \(offset) for input time of \(timeMark)")
    return offset
  }
  
  struct VideoSegment {
    let startSeconds:Double
    let videoDurationSeconds:Double
    let gapSeconds:Double?
    var segementSeconds: Double {
      return gapSeconds == nil ? videoDurationSeconds : videoDurationSeconds+gapSeconds!
    }
  }
  
  /// model of the video as a array of contiguous timed sequences of video+(optional)gap
  /// this model ignors all cut marks, thus unedited video is represented (simpleDuration,nil)
  // TODO: create code to handle PCRReset
  var videoSequences: [VideoSegment]
  {
    var sequence = [VideoSegment]()
    if (hasGaps) {
      var start = 0
      var startTime = Double(0.0)
      for end in gapIndices
      {
        let segmentDurationInSeconds = deriveRunTimePTSBetweenIndices(startIndex: start, endIndex: end).asSeconds
        let gapDurationInPts = m_access_points_array[end+1].pts - m_access_points_array[end].pts
        let gapDurationInSeconds:Double? = gapDurationInPts.asSeconds
        let segment = VideoSegment(startSeconds: startTime, videoDurationSeconds:segmentDurationInSeconds, gapSeconds:gapDurationInSeconds)
        sequence.append(segment)
        startTime += segmentDurationInSeconds + (gapDurationInSeconds ?? 0.0)
        start = end+1
      }
      let lastVideoSeconds = deriveRunTimePTSBetweenIndices(startIndex: start, endIndex: m_access_points_array.count-1).asSeconds
      let segment:VideoSegment = VideoSegment(startSeconds: startTime, videoDurationSeconds:lastVideoSeconds,gapSeconds: nil)
      sequence.append(segment)
      return sequence
    }
    else  {
      let segment: VideoSegment = VideoSegment(startSeconds: 0.0, videoDurationSeconds:runtimePTS.asSeconds, gapSeconds:nil)
      return [segment]
    }
  }
  
  /// Derive the duration between to index values of the access points table.
  /// Allow for detection of one discontinuity.
  /// Expected usage is for get the time duration of a cut out section
  func durationInPTS(from startIndex: Int, to endIndex: Int) -> UInt64
  {
    var durationInPTS:UInt64
    guard(startIndex >= 0 && endIndex >= 0) else { return 0 }
    
    // check for PTS discontinuity
    if (m_access_points_array[endIndex].pts < m_access_points_array[startIndex].pts)
    { // discontuity get a close approximation (assuming only one discontinuity)
      let (ptsValue, ceilingIndex) = highestPTSFrom(startIndex)
      durationInPTS = (ptsValue - m_access_points_array[startIndex].pts) + (m_access_points_array[endIndex].pts - m_access_points_array[ceilingIndex+1].pts)
    }
    else {
      durationInPTS = m_access_points_array[endIndex].pts - m_access_points_array[startIndex].pts
    }
    return durationInPTS
  }
  
  /// Determine the elapsed duration from a pts in the sequence that may contains gaps
  /// Used to map PTS fed back from the AVPlayer currentTime into a "played video"
  /// duration.
  func deriveRunTimeFromFromPlayer(ptsTime: PtsType) -> PtsType
  {
    let endIndex = nearestApIndexForPTSFromPlayer(ptsValue: ptsTime)
    return deriveRunTimeDurationToIndex(endIndex: endIndex)
  }
  
  ///
  private func deriveRunTimePTSBetweenIndices(startIndex: Int, endIndex: Int) -> PtsType
  {
    // derive duration with analysis for gaps
    guard m_access_points_array.count > 1 else {
      return PtsType(0)
    }
    
    var deltaSecs: Double
    var lastDeltas: String
    var seqStart = startIndex
    var ptsDiscontinuity = false
    var cummulativeDurationPTS = PtsType(0)
    if (debug) {
      print("checking Ap for \(container?.movieName! ?? apFileName)")
      print("Simple duration: \(simpleDurationInHMS())")
    }
    for index in startIndex ..< endIndex
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
        // ascribe a "typical step"
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
          //          let sequenceDurationHMS = CutEntry.hhMMssFromSeconds(sequenceDurationSecs)
          let sequenceDurationHMS = sequenceDurationSecs.hhMMss
          let runTimeSecs = Double(cummulativeDurationPTS)*CutsTimeConst.PTS_DURATION
//          let readableCummulativeTime = CutEntry.hhMMssFromSeconds(runTimeSecs)
          let readableCummulativeTime = runTimeSecs.hhMMss
          print("\(sequenceDurationPTS) - \(cummulativeDurationPTS): \(sequenceDurationHMS) - \(readableCummulativeTime)")
        }
        seqStart = index+1
        ptsDiscontinuity = false
      }
    }
    let sequenceDurationPTS = m_access_points_array[endIndex].pts - m_access_points_array[seqStart].pts
    cummulativeDurationPTS += sequenceDurationPTS
    if (debug) {
      let runTimeSecs = Seconds(cummulativeDurationPTS)*CutsTimeConst.PTS_DURATION
//      let readableTime = CutEntry.hhMMssFromSeconds(runTimeSecs)
      let readableTime = runTimeSecs.hhMMss
      print("Run time of \(cummulativeDurationPTS) pts / \(readableTime)")
    }
    self.sequenceHasGaps = (seqStart != 0)
    return cummulativeDurationPTS
  }
  
  private func deriveRunTimeDurationToIndex(endIndex: Int) -> PtsType
  {
    return deriveRunTimePTSBetweenIndices(startIndex: 0, endIndex: endIndex)
  }
  
  private func deriveRunTimeDurationFromIndex(startIndex first: Int) -> PtsType
  {
    guard m_access_points_array.count > 0  else {
      return PtsType(0)
    }
    let last = m_access_points_array.count-1
    return deriveRunTimePTSBetweenIndices(startIndex: first, endIndex: last)
  }
  
  /// Convert PTS into elapsed duration time using value acquired from avplayer.
  /// Typically from timed observer callback and used to reposition time marker
  /// Player generates a increasing sequence of time and does not report the
  /// PTS value from the recording
  /// Scenario is compounded when the player "Seeks" to a specific file PTS value
  /// Player PTS is then set to that value
  func elapsedForPlayer(from ptsValue: PtsType) -> PtsType
  {
    guard self.hasGaps else { return ptsValue }
    return ptsValue
  }
  
  /// Convert PTS into elapsed duration time using value acquired from time line
  /// Typically from use "clicking" in the time time to manually seek
  /// Clicking generates a proportional value which needs to be adjusted for
  /// any gaps in pts sequences to calculate an absolute PTS value present
  /// in the file for the player to seekTo
  
  func elapsedForTimeline(from ptsValue: PtsType) -> PtsType
  {
    guard self.hasGaps else { return ptsValue }
    return ptsValue
  }
}
