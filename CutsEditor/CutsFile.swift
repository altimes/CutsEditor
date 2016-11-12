//
//  CutsFile.swift
//
//  Created by Alan Franklin on 31/03/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//
//  Models the Beyonwiz (Enigma2) .cuts file

import AVFoundation

struct MessageStrings {
  static let NO_SUCH_FILE = "No Such File"
  static let FOUND_FILE = "Found File"
  static let CAN_CREATE_FILE = "Success on file creation"
  static let DID_WRITE_FILE = "Success of replacement"
  static let sequentialInMarks = "Sequential IN cut Marks"
  static let sequentialOutMarks = "Sequential OUT cut Marks"
}

/// Models the collection of cut/book/lastplay marks associated with a recording

class CutsFile: NSObject {
  
  /// Known cut mark cases
  fileprivate enum cutStates {
    case
      unknown,
      inCut,
      outCut,
      bookmark,
      lastplay
  }
  
  /// collection of cut marks, internally maintained to be in time (pts) order
  // TODO: check what happens with discontinuities with PTS values
  fileprivate var cutsArray = [CutEntry]()
  
  /// Return number of elements in cuts collection
  public var count : Int
    {
    get { return cutsArray.count }
  }
  
  /// Accessor to Parent container
  var container : Recording?
  
  /// Get the CoreMedia time of the first mark in the cuts collection.
  /// If the collection is empty then return zero time.
  var firstMarkTime : CMTime {
    get {
      var startTime: CMTime
      if let firstMark = self.first {
        startTime = CMTimeMake(Int64(firstMark.cutPts), CutsTimeConst.PTS_TIMESCALE)
      }
      else {
        startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
      }
      return startTime
    }
  }
  
  /// Get earliest (pts time based) cut entry in the collection or nil if there is none
  open var first: CutEntry? {
    get {
      return cutsArray.first
    }
  }
  
  /// Get latest (pts time based) cut entry in collection or nil if there is none
  public var last: CutEntry? {
    get {
      return cutsArray.last
    }
  }
  
  /// Get the last OUT mark (pts time based) cut entry in collection or nil if there is none
  public var lastOutCutMark: CutEntry? {
    get {
      let OUTArray = cutsArray.filter() {$0.cutType == MARK_TYPE.OUT.rawValue}
      return OUTArray.last
    }
  }
  
  /// Get the first IN mark (pts time based) cut entry in collection or nil if there is none
  public var firstInCutMark: CutEntry? {
    get {
      let INArray = cutsArray.filter() {$0.cutType == MARK_TYPE.IN.rawValue}
      return INArray.first
    }
  }
  
  /// Get the first OUT mark (pts time based) cut entry in collection or nil if there is none
  public var firstOutCutMark: CutEntry? {
    get {
      let OUTArray = cutsArray.filter() {$0.cutType == MARK_TYPE.OUT.rawValue}
      return OUTArray.first
    }
  }
  
  /// Array of only the IN and OUT cutmarks in time order
  public var inOutOnly: [CutEntry] {
    get {
      let inOut = cutsArray.filter{$0.cutType == MARK_TYPE.IN.rawValue || $0.cutType == MARK_TYPE.OUT.rawValue}
      return inOut
    }
  }
  
  /// Returns the result of checking the cuts list for consistency.
  /// That is, ensure OUTs and INs are always alternating
  /// - returns: changed state
  public var isCuttable : Bool {
    get {
      let validation = self.validateInOut()
      lastValidationMessage = validation.errorMessage
      return validation.result
    }
  }
  
  /// Message string from the last validation performed
  public private(set) var lastValidationMessage: String = ""
  
  /// Has the list of cuts been changed
  /// - returns: changed state
  public var isModified : Bool {
     get {
      return modified
    }
  }
  
  /// internal flag if any change is made to the collection
  fileprivate var modified = false
  
  var debug = false
  
  // MARK: Initializers
  
  convenience init(data: Data)
  {
    self.init()
    decodeCutsData(data)
  }
  
  // supporting functions
  
  /// Get a copy of the cutEntry at requested sequence position in the collection.
  /// - Returns: cutEntry or nil on invalid sequence position
  /// - parameter at: sequential position in the collection
  ///
  public func entry(at index: Int) -> CutEntry?
  {
    // validate index
    if (index >= 0 && index < cutsArray.count) {
      return cutsArray[index]
    }
    else {
      return nil
    }
  }
  
  /// Check if array has a matching (==) entry
  /// Wrapper function to detach implementation detail
  /// - parameter cutEntry: entry to search for
  public func contains(_ entry: CutEntry) -> Bool
  {
    return cutsArray.contains(entry)
  }
  
  /// Add cut entry to array if it is not already present.
  /// If it is present, then simply ignor the request
  /// - parameter cutEntry: entry to add to the collection
  public func addEntry(_ cutEntry: CutEntry) {
    // check if already present
    if (!cutsArray.contains(cutEntry)) {
      insert(cutEntry)
    }
  }
  
  /// Append cutEntry to the cuts collection and
  /// re-sort the collection.
  /// Allows duplicate entries.
  /// Maintains storage in ascending order
  /// - parameter cutEntry: entry to add to the collection
  public func insert(_ entry: CutEntry)
  {
    modified = true
    cutsArray.append(entry)
    cutsArray.sort(by: <)
  }
  
  /// Derives and returns first and last position in a video file
  /// from the cutmarks and video information
  /// - returns : firstIN and lastOut mark points as PtsType
  func startEnd() -> (firstIN: PtsType, lastOUT: PtsType)
  {
    let firstInCutPts =  (count != 0) ? ((first!.cutType == MARK_TYPE.IN.rawValue) ? first!.cutPts : PtsType(0)) : PtsType(0)
    let lastPTS =   ((inOutOnly.count > 0) && (inOutOnly.last!.cutType == MARK_TYPE.OUT.rawValue)) ? inOutOnly.last!.cutPts : container!.lastOutCutPTS
    return(firstInCutPts, lastPTS)
  }
  
  /// Add bookmarks to the array at a fixed time interval.
  /// Early simplistic implementation to caculate PTS value from first
  /// PTS value.  Later may interogate .ap file for nearest PTS value.
  /// Honour out/in marks, the interval is a program interval (as defined by OUT/IN)
  /// markers, not simple recording duration
  /// Note that this deliberately avoids a begin boundary bookmark
  /// Cutting appears to occur on GOP boundaries and can end up with negative
  /// bookmarks.
  
  /// - parameter interval: interval between bookmarks in seconds
  /// - parameter firstInCutPts: pts value of the start position
  /// - parameter lastOutCutPts: pts value of the end position
  
  func addFixedIntervalBookmarks (interval: PtsType, firstInCutPts: PtsType, lastOutCutPts: PtsType)
  {
    var lastPts = lastOutCutPts
    
    if (firstInCutPts < lastOutCutPts)  // important for UIntXX values
    {
      // get duration from meta and compare to first / last pts range
      // editted file will result in a substantial mismatch
      if let metaDuration = Double((container?.meta.duration)!) {
        let ptsDuration = Double(lastOutCutPts - firstInCutPts)
        let durationDiff = abs(ptsDuration-metaDuration)
        // is the diffrence > 30 secs ?
        if metaDuration != 0 && durationDiff > 30.0*Double(CutsTimeConst.PTS_TIMESCALE) {
          // file has had advertisements removed, check that last matches the ap data
            lastPts = firstInCutPts + (container?.ap.runtimePTS)!
          // FIXME: this algorithm is broken for edited file (in/outs) are missing
          // might be fixable by finding gaps and inserting temp in/out at gap boundaries
        }
      }
      
      // alogrithm is to: create a temporary table of only INs and OUTs.
      // balance IN/OUT sequence to ensure that we start IN and end OUT
      // and then process the IN/OUT pairs
      
      var inOut = inOutOnly
      
      // no marks, generate a pair
      if (inOut.count == 0 ) {
        inOut.append(CutEntry(cutPts: firstInCutPts, mark: .IN))
        inOut.append(CutEntry(cutPts: lastPts, mark: .OUT))
      }
      
      // assert inOut is NOT emptry
      
      // first mark is OUT, generate an IN at the begining
      if (inOut.first!.cutType == MARK_TYPE.OUT.rawValue) {
        inOut.insert(CutEntry(cutPts: firstInCutPts, mark: MARK_TYPE.IN), at: 0)
      }
      
      // last mark is IN, generate an OUT at the end
      if (inOut.last!.cutType != MARK_TYPE.OUT.rawValue) {
        inOut.append(CutEntry(cutPts: lastPts, mark: .OUT))
      }
      
      // assert inOut is now always IN/OUT, [IN/OUT], .... in the inOut array
      
      var index = 0
      var used = UInt64(0)
      while (index < inOut.count)
      {
        let nextInMark = inOut[index]
        let nextOutMark = inOut[index+1]
        let startPts = nextInMark.cutPts-used
        if (debug) {print ("used: \(Double(used)*CutsTimeConst.PTS_DURATION) in: \(nextInMark.asSeconds()), start:\(Double(startPts)*CutsTimeConst.PTS_DURATION), out:\(nextOutMark.asSeconds())")}
        used = addMarks(fromPos: startPts, upToPos: nextOutMark.cutPts, spacing: interval)
        index += 2
      }
      modified = true
    }
  }
  
  /// Add bookmarks to the array at a fixed time interval.
  /// Early simplistic implementation to caculate PTS value from first
  /// PTS value.  Later may interogate .ap file for nearest PTS value.
  /// Uses preference value for time interval
  /// Note that this deliberately avoids a begin boundary bookmark
  /// Cutting occurs on GOP boundaries and can end up with negative
  /// bookmarks.
  
  /// - parameter interval: interval between bookmarks in seconds
  
  func addFixedTimeBookmarks (interval: Int)
  {
    let intervalInSeconds = interval
    let (first, last) = startEnd()
    let ptsIncrement = PtsType( intervalInSeconds*Int(CutsTimeConst.PTS_TIMESCALE))
    addFixedIntervalBookmarks(interval: ptsIncrement, firstInCutPts: first, lastOutCutPts: last)
  }

  /// Add bookmarks to the collection at the spacing from the given start position
  /// up to the given end position. calculates and returns the last "used" part of the spacing
  /// to enable the next bookmark create to compensate for unused portion and ensure even
  /// bookmarks in relation to program content
  /// - parameter fromPos: start value
  /// - parameter upToPos: value not to create bookmarks beyond
  /// - parameter spacing: spacing of bookmarks
  /// - returns : remainder of unused spacing
  fileprivate func addMarks(fromPos: PtsType, upToPos: PtsType, spacing: PtsType) -> PtsType
  {
    var bookmarkPosition: PtsType
    if (debug) { print("received start at: \(Double(fromPos)*CutsTimeConst.PTS_DURATION)") }
    bookmarkPosition = fromPos + spacing
    while bookmarkPosition < upToPos {
      if (debug) { print("Creating entry at \(Double(bookmarkPosition)*CutsTimeConst.PTS_DURATION) for spacing of \(Double(spacing)*CutsTimeConst.PTS_DURATION)") }
      addEntry(CutEntry(cutPts: bookmarkPosition, mark: .BOOKMARK))
      bookmarkPosition += spacing
    }
    let used = spacing - (bookmarkPosition - upToPos)
    if (debug) { print("returning remainder of \(Double(used)*CutsTimeConst.PTS_DURATION)") }
    return used
  }
  
  /// Add fixed NUMBER of bookmarks
  /// Note that this deliberately avoids adding bookmarks
  /// on the begin and end boundaries.
  /// Due to the observation that when cutting is done after bookmarks
  /// are inserted and that cutting seems to occur
  /// on GOP boundaries, then it can end up with negative
  /// bookmarks that cause all sorts of grief to avplayers
  /// Default value gives bookmarks at 10 % spacing
  
  /// - parameter numberOfMarks: how many bookmarks to interpolate between begin and end positions
  
  public func addPercentageBookMarks(_ numberOfMarks: Int = 9)
  {
    let (first, last) = startEnd()
    // get duration
    let programLength =  playable(startPTS: first, endPTS: last)
    let ptsOffset = programLength / UInt64(numberOfMarks+1)
    addFixedIntervalBookmarks(interval: ptsOffset, firstInCutPts: first, lastOutCutPts: last)
  }

  
  /// return the recording duration with respect to OUT / IN markers
  /// return duration from movie otherwise
  private func playable(startPTS: PtsType, endPTS: PtsType) -> PtsType
  {
    var playableDurationInPts = (endPTS - startPTS)
    guard  (isCuttable) else { return playableDurationInPts }
    
    let inOut = inOutOnly
    if inOut.count != 0
    {
      var index = 0
      // prime the loop - deal with leading IN marker
      if inOut[index].cutType == MARK_TYPE.IN.rawValue {
        let leadingOutCut = (inOut[index].cutPts - startPTS)
        playableDurationInPts -= leadingOutCut
        index += 1
      }
      
      // loop invar inOut[index] is an OUT marker && index+1 is valid
      while (index < inOut.count-1)
      {
        let outInDurationInPts = (inOut[index+1].cutPts - inOut[index].cutPts)
        playableDurationInPts -= outInDurationInPts
        index += 2
      }
      
      // finalize the loop  - deal with trailing OUT marker
      if (inOut.last!.cutType == MARK_TYPE.OUT.rawValue) {
        let trailingOutCut = (endPTS - inOut.last!.cutPts)
        playableDurationInPts -= trailingOutCut
      }
    }
    return playableDurationInPts
  }
  
  /// Find the earliest position in the video.  This should be;
  /// the first IN mark not preceed by an out Mark,
  /// failing that, if there are <= 3 bookmarks,
  /// use the first bookmark - most likely an unedited file.
  /// Otherwise use then use the initial file position
  /// which may have to be fabricated if it does not exist.
  
  func firstVideoPosition() -> CutEntry
  {
    if let firstInEntry = firstInCutMark {
      if (index(of: firstInEntry) == 0) {
        return firstInEntry
      }
      else
      {
        if let firstOutEntry = firstOutCutMark
        {
          if (index(of: firstInEntry)! < index(of: firstOutEntry)!) {
            return firstInEntry
          }
          else {
            return CutEntry.InZero
          }
        }
      }
    }
    // if there are a set of bookmarks or no bookmarks
    if count > 3 || count == 0
    {
      return CutEntry.InZero
    }
    else // >0 && <= 2 bookmarks pick the first bookmark
    {
      if let entry = first {
        return entry
      }
      else { // should be technically impossible, however, belt and braces
        return CutEntry.InZero
      }
    }
  }
  

  /// Remove the given cutEntry from the cuts storage.
  /// Missing entry is acceptable
  /// - parameter cutEntry: entry structure to remove
  /// - returns : true if entry was found, false if not
  public func removeEntry(_ cutEntry: CutEntry) -> Bool
  {
    guard let index = cutsArray.index(of: cutEntry) else {
      return false
    }
    cutsArray.remove(at: index)
    modified = true
    return true
  }
  
  /// Remove all marks from the collection
  public func removeAll() {
    cutsArray.removeAll()
    modified = true
  }

  /// Remove the mark a the given place in the collection sequence
  /// Silently ignor out of bounds index
  /// - parameter at: sequential position in the collection
  public func remove(at index: Int)
  {
    guard (cutsArray.count > 0 && index>=0 && index < cutsArray.count) else { return }
    cutsArray.remove(at: index)
    modified = true
  }
  
  /// Remove all entries matching the given mark type from the collection
  /// - parameter type: mark type to remove
  public func removeEntriesOfType(_ type: MARK_TYPE)
  {
    // replace with array with all marks except "type"
    cutsArray = cutsArray.filter() {!($0.cutType == type.rawValue)}
    modified = true
  }
  
  /// Get the sequence position of the first entry that matches
  /// the given entry.  Return nil on failure to find
  /// - parameter cutEntry: entry get index of
  /// - returns : sequence position or nil
  public func index(of entry: CutEntry) -> Int?
  {
    return cutsArray.index(of: entry)
  }

  /// Find the cut entry that preceeds the current time or is within the provivded tolerance of the
  /// time.  That is, if time is 15.99, return the 16.0 cut entry
  /// - parameter secs: target time in seconds
  /// - parameter tolerance: in seconds
  /// - returns : valid entry and sequence position or nil
  public func entryBeforeTime(_ secs: Double, tolerance: Double = 0.05) -> (entry :CutEntry, index: Int)?
  {
    var found: CutEntry? = nil
    
    // Simple serial search.  Record the highwater mark compared to target time
    // until we get a mark later than the target time
    for entry in cutsArray {
      let entrySecs = entry.asSeconds()
      if ((entrySecs - secs) <= tolerance) {
        found = entry
      }
      else {
        break
      }
    }
    if found != nil
    {
      return (found!, cutsArray.index(of: found!)!)
    }
    return nil
  }
  
  /// Routine that looks at the given program time and decide if it is in
  /// a "cut me out" section of the program and if so, return the next IN time or nil
  /// - parameter now: Core Media time structure
  /// - returns : valid IN mark time or nil
  public func programTimeAfter(_ now: CMTime) -> CMTime?
  {
    var skipCandidate = false
    let nowInSecs = now.seconds
    for entry in cutsArray {
      var markInSecs = entry.asSeconds()
      if (entry.cutType == MARK_TYPE.IN.rawValue || entry.cutType == MARK_TYPE.OUT.rawValue)
      {
        var markTime = CMTimeMake(Int64(entry.cutPts), CutsTimeConst.PTS_TIMESCALE)
        
        if (nowInSecs > markInSecs && entry.cutType == MARK_TYPE.OUT.rawValue)
        {
          // skip ad candidate
          skipCandidate = true
          continue
        }
        
        if (nowInSecs < markInSecs && entry.cutType == MARK_TYPE.IN.rawValue && skipCandidate) {
          markInSecs += 0.25
          markTime = CMTimeMake(Int64(markInSecs*1000.0)*Int64(CutsTimeConst.PTS_TIMESCALE/1000), CutsTimeConst.PTS_TIMESCALE)
          return markTime
        }
        else {
          skipCandidate = false
        }
      }
    }
    return nil
  }
  
  // TODO: update to Swift 3 Data unpacking functions. replacing bridged NSData functions
  /// Unravels the binary chunk of data into the required local format
  /// - parameter data: the Binary lump to be decoded
  
  private func decodeCutsData(_ data: Data)
  {
      if (debug)  {
        print("Found file ")
        print("Found file of \((data.count))! size")
      }
      
      let entries = (data.count) / MemoryLayout<CutEntry>.size
      cutsArray = [CutEntry](repeating: CutEntry(cutPts: 0, cutType: 0 ), count: entries)
    
      // nibble through the data buffer and populate array
      var startOffset = 0
      for i in 0 ..< entries
      {
        var tempCutEntry = CutEntry(cutPts: 0, cutType: 0)
        let itemRange = NSRange.init(location: startOffset, length: MemoryLayout<CutEntry>.size)
        startOffset += MemoryLayout<CutEntry>.size
        // pass the byte into a the temporary structure and then byte swap the chunks
        (data as NSData).getBytes(&tempCutEntry, range: itemRange)
        cutsArray[i].cutPts = UInt64(bigEndian: tempCutEntry.cutPts)
        cutsArray[i].cutType = UInt32(bigEndian: tempCutEntry.cutType)
      }
      cutsArray.sort(by: <)
      modified = false
  }
  
  /// Encoder for collection. Encodes into binary form suitable for PVR
  /// - returns : data binary blob ready to writing to file
  open func encodeCutsData() -> Data
  {
    var data = Data()
    for entry in cutsArray
    {
      var entryCopy = CutEntry(cutPts: entry.cutPts.bigEndian, cutType: entry.cutType.bigEndian)
      data.append(Data(bytes: &entryCopy, count: MemoryLayout<CutEntry>.size))
    }
    return data
  }
  
  /// Test if collection has an IN or OUT Marker
  /// - returns : true or false
  func containsINorOUT() -> Bool
  {
    return contains(.IN) || contains(.OUT)
  }
  
  /// Test if collection has a marker of the given type
  /// - parameter cutOfType: case from emum (.IN, .OUT, .LASTPLAY, .BOOKMARK)
  /// - returns : true or false
  func contains(_ cutOfType: MARK_TYPE) -> Bool
  {
    var found = false
    var index = 0
    while (!found && index < cutsArray.count)
    {
      found = cutsArray[index].cutType == cutOfType.rawValue
      if (found) {
        break
      }
      index += 1
    }
    return found
  }
  
  /// Utility debug to verify order and contents of collection
  open func printCutsData()
  {
    var lineNumber = 0
    for entry in cutsArray {
      print("\(lineNumber) = " + entry.asString())
      lineNumber += 1
    }
  }
  
  /// Utility debug to verify order and contents of collection
  open func printCutsDataAsHex()
  {
    var lineNumber = 0
    for entry in cutsArray {
      print("\(lineNumber) = " + entry.asHex())
      lineNumber += 1
    }
  }
  
  /// Utility debug to verify order and contents of collection.
  ///  Print to console  in/out list from array
  
  open func printInOut()
  {
    let inOutSet = Set([MARK_TYPE.OUT,MARK_TYPE.IN])
    printSetOfType(inOutSet)
  }
  
  /// Utility debug to verify order and contents of collection.
  /// Print to console bookmark list from array
  
  open func printBookmark()
  {
    let  bookMarkSet = Set([MARK_TYPE.BOOKMARK])
    printSetOfType(bookMarkSet)
  }
  
  /// Utility debug to verify order and contents of collection
  ///  Print to console  items that match the set member type
  /// - parameter markSet: Set of required mark types
  func printSetOfType(_ markSet : Set<MARK_TYPE>) {
    var lineNumber = 0
    for entry in cutsArray {
      if let item = cutDataMarkOfTypeAsString(entry, markSet: markSet)
      {
        print("\(lineNumber) \(item)")
      }
      lineNumber += 1
    }
  }
  
  /// Get a formatted string of the entry if that entry is of any type that is in the set of cut types given
  /// - parameter cutEntry: entry to be formatted if it matches the condition
  /// - parameter markSet: Set of required mark types
  func cutDataMarkOfTypeAsString(_ cutEntry: CutEntry, markSet : Set<MARK_TYPE>) -> String?
  {
    var result : String? = nil
    if (markSet.contains(MARK_TYPE.lookupOnRawValue(cutEntry.cutType)!))
    {
      result =  cutEntry.asString()
    }
    return result
  }
  
  /// Save the cuts data back to disk and return result
  /// parameter filenamePath: full path to file
  /// returns: success or failure of save
  func saveAs(filenamePath: String) -> Bool
  {
    let (fileMgr, found, fullFileName) = Recording.getFileManagerForFile(filenamePath)
    if (found) {
      let cutsData = encodeCutsData()
      let fileWritten = fileMgr.createFile(atPath: fullFileName, contents: cutsData, attributes: nil)
      if (fileWritten && debug) {
        print(MessageStrings.DID_WRITE_FILE)
      }
      return fileWritten
    }
    return false
  }
  
  /// check that there are no IN, IN or OUT, OUT sequences present
  /// - returns: result of validation and message if flaw was found or empty string if good
  
  fileprivate func validateInOut() -> (result: Bool, errorMessage: String) {
    // check in/out pairing
    var currentState = cutStates.unknown
    var goodList = true
    var message = ""
    for item in cutsArray
    {
      switch MARK_TYPE(rawValue: item.cutType)! {
      case .IN :
        if (currentState == .unknown || currentState == .outCut) {
          currentState = .inCut
          goodList = goodList && true
        }
        else {
          goodList = false
          message = MessageStrings.sequentialInMarks
          break
        }
      case .OUT :
        if (currentState == .unknown || currentState == .inCut ) {
          currentState = .outCut
          goodList = goodList && true
        }
        else {
          goodList = false
          message = MessageStrings.sequentialOutMarks
          break
        }
      case .BOOKMARK : fallthrough
      case .LASTPLAY :
        // does not change state
        goodList = goodList && true
      }
    }
    return (goodList, message)
  }
}
