//
//  CutsFile.swift
//  CutsEditor
//
//  Created by Alan Franklin on 3/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

//
//  CutsFile.swift
//
//  Created by Alan Franklin on 31/03/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa
import AVFoundation

struct MessageStrings {
  static let NO_SUCH_FILE = "No Such File"
  static let FOUND_FILE = "Found File"
  static let CAN_CREATE_FILE = "Success on file creation"
  static let DID_WRITE_FILE = "Success of replacement"
}


open class CutsFile: NSObject {
  
  // model: array of cuts data
  
  fileprivate enum cutStates {
    case
      unknown,
      inCut,
      outCut,
      bookmark,
      lastplay
  }
  
  var cutsArray = [CutEntry]()
  open var count : Int
    {
    get { return cutsArray.count }
  }
  
  var firstBookmark : CMTime {
    get {
      var startTime: CMTime
      if (cutsArray.count>0)
      {
        let startPTS = Int64(cutsArray[0].cutPts)
        startTime = CMTimeMake(startPTS, CutsTimeConst.PTS_TIMESCALE)
      }
      else {
        startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
      }
      return startTime
    }
  }
  
  open var first: CutEntry? {
    get {
      return cutsArray.first
    }
  }
  
  open var last: CutEntry? {
    get {
      return cutsArray.last
    }
  }
  
  
  /// Get the last OUT mark
  open var lastOutCutMark: CutEntry? {
    get {
      let OUTArray = cutsArray.filter() {$0.cutType == MARK_TYPE.OUT.rawValue}
      return OUTArray.last
    }
  }
  
  /// Get the first IN mark
  open var firstInCutMark: CutEntry? {
    get {
      let INArray = cutsArray.filter() {$0.cutType == MARK_TYPE.IN.rawValue}
      return INArray.first
    }
  }
  
  /// Get the first OUT mark
  open var firstOutCutMark: CutEntry? {
    get {
      let OUTArray = cutsArray.filter() {$0.cutType == MARK_TYPE.OUT.rawValue}
      return OUTArray.first
    }
  }
  
  var isCuttable : Bool {
    get {
      let validation = self.validateInOut()
      return validation.result
    }
  }
  
  var isModified : Bool {
     get {
      return modified
    }
  }
  
  fileprivate var modified = false
  
  
  var debug = false
  
  public static let marksDictionary = ["addBookmark":MARK_TYPE.BOOKMARK,"addInMark":MARK_TYPE.IN, "addOutMark":MARK_TYPE.OUT, "addLastPlay":MARK_TYPE.LASTPLAY]
  
  // MARK: Initializers
  
  convenience init(data: Data)
  {
    self.init()
    decodeCutsData(data)
  }
  
  // supporting functions
  
  open static func makeCutEntry(_ cutPts : UInt64, type : MARK_TYPE) -> CutEntry
  {
    return CutEntry(cutPts: cutPts, cutType: type.rawValue)
  }
  
  open func entry(at index: Int) -> CutEntry?
  {
    // validate index
    if (index >= 0 && index < cutsArray.count) {
      return cutsArray[index]
    }
    else {
      return nil
    }
  }
  
  open func contains(_ entry: CutEntry) -> Bool
  {
    return cutsArray.contains(entry)
  }
  
  /// Add cut entry to array
  /// FIXME: should return SUCCESS or FAILURE ?
  func addEntry(_ cutEntry: CutEntry) {
    // check if already present
    if (!cutsArray.contains(cutEntry)) {
      insert(cutEntry)
    }
  }
  
  /// Append cutEntry to the cuts Storage and
  /// resort the storage.
  /// Maintains storage in ascending order
  open func insert(_ entry: CutEntry)
  {
    modified = true
    cutsArray.append(entry)
    cutsArray.sort(by: <)
  }

  
  /// Add bookmarks to the array at a fixed time interval.
  /// Early simplistic implementation to caculate PTS value from first
  /// PTS value.  Later may interogate .ap file for nearest PTS value.
  /// Uses preference value for time interval
  /// Note that this deliberately avoids a begin boundary bookmark
  /// Cutting occurs on GOP boundaries and can end up with negative
  /// bookmarks.
  
  func addFixedTimeBookmarks (interval: Int, firstInCutPts: PtsType, lastOutCutPts: PtsType)
  {
    
    let intervalInSeconds = interval
    let ptsIncrement = PtsType( intervalInSeconds*Int(CutsTimeConst.PTS_TIMESCALE))
    // get duration
    if (firstInCutPts < lastOutCutPts)  // important for UIntXX values
    {
      var pts = firstInCutPts + ptsIncrement
      while pts < lastOutCutPts
      {
        let cutPt = CutEntry(cutPts: pts, cutType: MARK_TYPE.BOOKMARK.rawValue)
        addEntry(cutPt)
        pts += ptsIncrement
      }
      modified = true
    }
  }

  /// Note that this deliberately avoids a begin boundary bookmark
  /// Cutting occurs on GOP boundaries and can end up with negative
  /// bookmarks.
  /// Default value give bookmarks at 10 % boundaries
  
  func addPercentageBookMarks(_ numberOfMarks: Int = 9, firstInCutPts: PtsType, lastOutCutPts: PtsType)
  {
    var countAdded = 0
    // get duration
    if (firstInCutPts < lastOutCutPts)  // important for UIntXX values
    {
      let programLength = lastOutCutPts - firstInCutPts
      let ptsOffset = programLength / UInt64(numberOfMarks+1)
      var ptsPosition = firstInCutPts + ptsOffset
      while (ptsPosition < lastOutCutPts && countAdded < numberOfMarks)
      {
        //        print("\(pts)  - \(offset)")
        let cutPt = CutEntry(cutPts: ptsPosition, cutType: MARK_TYPE.BOOKMARK.rawValue)
        addEntry(cutPt)
        ptsPosition += ptsOffset
        countAdded += 1
      }
      modified = true
    }
  }
  

  /// Remove the given cutEntry from the cuts storage.
  /// Silently ignor missing entry.
  /// - parameter cutEntry: entry structure to remove
  open func removeEntry(_ cutEntry: CutEntry) -> Bool
  {
    guard let index = cutsArray.index(of: cutEntry) else {
      return false
    }
    cutsArray.remove(at: index)
    modified = true
    return true
  }
  
  /// Wrapper function to abstract implementation
  open func removeAll() {
    cutsArray.removeAll()
    modified = true
  }

  /// Wrapper function
  open func remove(at index: Int)
  {
    guard (cutsArray.count > 0 && index>=0 && index < cutsArray.count) else { return }
    cutsArray.remove(at: index)
    modified = true
  }
  
  open func removeEntriesOfType(_ type: MARK_TYPE)
  {
    // replace with array with all marks except "type"
    cutsArray = cutsArray.filter() {!($0.cutType == type.rawValue)}
    modified = true
  }
  
  open func index(of entry: CutEntry) -> Int?
  {
    return cutsArray.index(of: entry)
  }

  /// Find the cut entry that preceeds the current time or is within the provivded tolerance of the
  /// time.  That is, if time is 15.99, return the 16.0 cut entry
  open func entryBeforeTime(_ secs: Double, tolerance: Double = 0.05) -> (entry :CutEntry, index: Int)?
  {
    var found: CutEntry? = nil
    for entry in cutsArray {
      let entrySecs = entry.asSeconds()
      if ((entrySecs - secs) <= tolerance) {
        found = entry
      }
      else {  // now is less than this mark
        if let mark = found
        { // there was a previous mark
          return (mark, cutsArray.index(of: mark)!)
        }
        else {
          break
        }
      }
    }
    if let mark = found
    { // there was a previous mark
      return (mark, cutsArray.index(of: mark)!)
    }
    return nil
  }
  
  // core accessors decode/encode
  
  // see if file exists or if we can create one
  
//  public func openCreateCutsFile(name:String)  -> Bool {
//    
//    let (fileMgr, didFindFile, pathName) = cutsfileDelegate!.getFileManagerForFile(name)
//    if (didFindFile)
//    {
//      print(MessageStrings.FOUND_FILE)
//    }
//    else
//    {
//      print(MessageStrings.NO_SUCH_FILE)
//      var dummy = CutEntry(cutPts: 0, cutType: 0)
//      let databuffer = NSData(bytes: &dummy, length: sizeof(CutEntry))
//      let success = fileMgr.createFileAtPath(pathName, contents: databuffer, attributes: nil)
//      
//      if (success) {
//        print(MessageStrings.CAN_CREATE_FILE)
//        deleteCutsFile(name)
//      }
//    }
//    return didFindFile
//  }
  
//  public func deleteCutsFile(name:String) -> Bool
//  {
//    var success : Bool
//    let (fileMgr, foundFile, fullFileName) = cutsfileDelegate!.getFileManagerForFile(name)
//    if (foundFile)
//    {
//      do {
//        try fileMgr.removeItemAtPath(fullFileName)
//        success = true
//      }
//      catch { // argh!!
//        print(error)
//        success = false
//      }
//    }
//    else { // some process has deleted the file
//      success = true
//    }
//    return success
//  }

  
  /// Routine that looks at the program time and decide if it is in
  /// a "cut me out" section and if so, return the next IN time or nil
  open func programTimeAfter(_ now: CMTime) -> CMTime?
  {
    var skipCandidate = false
    let nowInSecs = now.seconds
    for entry in cutsArray {
      var markInSecs = entry.asSeconds()
      if (entry.cutType == MARK_TYPE.IN.rawValue || entry.cutType == MARK_TYPE.OUT.rawValue)
      {
//        let type = MARK_TYPE(rawValue: entry.cutType)!
//        print("seeing now as \(nowInSecs) and mark as \(markInSecs) with mark \(type.description()) and candidate = \(skipCandidate)")
        var markTime = CMTimeMake(Int64(entry.cutPts), CutsTimeConst.PTS_TIMESCALE)
        
        if (nowInSecs > markInSecs && entry.cutType == MARK_TYPE.OUT.rawValue)
        {
          // skip ad candidate
          skipCandidate = true
          continue
        }
        
        if (nowInSecs < markInSecs && entry.cutType == MARK_TYPE.IN.rawValue && skipCandidate) {
//          print (" comp \(nowInSecs) vs \(markInSecs)")
//          print ("\(markTime) - \(now)")
          markInSecs += 0.25
          markTime = CMTimeMake(Int64(markInSecs*1000.0)*Int64(CutsTimeConst.PTS_TIMESCALE/1000), CutsTimeConst.PTS_TIMESCALE)
//          markTime = CMTimeConvertScale(markTime, now.timescale, .roundAwayFromZero)
          return markTime
        }
        else {
          skipCandidate = false
        }
      }
    }
    return nil
  }
  
  open func decodeCutsData(_ data: Data)
  {
    
      if (debug)  {
        print("Found file ")
        print("Found file of \((data.count))! size")
      }
      
      let entries = (data.count) / MemoryLayout<CutEntry>.size
      cutsArray = [CutEntry](repeating: CutEntry(cutPts: 0, cutType: 0 ), count: entries)
      
      // nibble through the data buffer and populate array
      var startOffset = 0
      for i in 0..<entries
      {
        var tempCutEntry = CutEntry(cutPts: 0, cutType: 0)
        let itemRange = NSRange.init(location: startOffset, length: MemoryLayout<CutEntry>.size)
        startOffset += MemoryLayout<CutEntry>.size
        (data as NSData).getBytes(&tempCutEntry, range: itemRange)
        cutsArray[i].cutPts = UInt64(bigEndian: tempCutEntry.cutPts)
        cutsArray[i].cutType = UInt32(bigEndian: tempCutEntry.cutType)
      }
      cutsArray.sort(by: <)
      modified = false
  }
  
//  public func loadCutsDataFromFile(name:String)
//  {
//    let debug = true
//    
//    let (fileMgr, foundFile, fullFileName) = cutsfileDelegate!.getFileManagerForFile(name)
//    
//    if (foundFile)
//    {
//      let foundData = fileMgr.contentsAtPath(fullFileName)
//      if (debug)  {
//        print("Found file ")
//        print("Found file of \((foundData?.length))! size")
//      }
//      
//      let entries = (foundData?.length)! / sizeof(CutEntry)
//      cutsArray = [CutEntry](count: entries, repeatedValue: CutEntry(cutPts: 0, cutType: 0 ))
//      
//      // nibble through the data buffer and populate array
//      var startOffset = 0
//      for i in 0..<entries
//      {
//        var tempCutEntry = CutEntry(cutPts: 0, cutType: 0)
//        let itemRange = NSRange.init(location: startOffset, length: sizeof(CutEntry))
//        startOffset += sizeof(CutEntry)
//        foundData?.getBytes(&tempCutEntry, range: itemRange)
//        cutsArray[i].cutPts = UInt64(bigEndian: tempCutEntry.cutPts)
//        cutsArray[i].cutType = UInt32(bigEndian: tempCutEntry.cutType)
//        //        print("--> \(i) -- " + cutsArray[i].asString())
//      }
////      cutsArray.sortInPlace(orderByPTS)
////      cutsArray.sortInPlace({(c1:CutEntry, c2:CutEntry) in  return c1.cutPts < c2.cutPts})
////      cutsArray.sortInPlace({c1, c2 in return c1.cutPts < c2.cutPts})
////      cutsArray.sortInPlace( {$0.cutPts < $1.cutPts} )
////      cutsArray.sortInPlace() {$0.cutPts < $1.cutPts}
//      cutsArray.sortInPlace(<)
////      if (debug) {
////        printCutsData()
////      }
//    }
//  }
  
  func orderByPTSAscending(_ cut1: CutEntry, _ cut2: CutEntry) -> Bool {
    return cut1.cutPts < cut2.cutPts
  }
  
  func orderByPTSDescending(_ cut1: CutEntry, _ cut2: CutEntry) -> Bool {
    return cut1.cutPts > cut2.cutPts
  }
  
  func orderByType(_ cut1: CutEntry, _ cut2: CutEntry) -> Bool {
    return cut1.cutType < cut2.cutType
  }
  
  func containsINorOUT() -> Bool
  {
    return contains(.IN) || contains(.OUT)
  }
  
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
  
//  func firstINMark() -> CutEntry?
//  {
//    let INArray = cutsArray.filter() {$0.cutType == MARK_TYPE.IN.rawValue}
//    return INArray.first
//  }
  
//  public func appendEntry(item : CutEntry)
//  {
//    cutsArray.append(item)
//  }
  
  open func printCutsData()
  {
    var lineNumber = 0
    for entry in cutsArray {
      print("\(lineNumber) = " + entry.asString())
      lineNumber += 1
    }
  }
  
  open func printCutsDataAsHex()
  {
    var lineNumber = 0
    for entry in cutsArray {
      print("\(lineNumber) = " + entry.asHex())
      lineNumber += 1
    }
  }
  
  
  // print in/out list from array
  
  open func printInOut()
  {
    let inOutSet = Set([MARK_TYPE.OUT,MARK_TYPE.IN])
    printSetOfType(inOutSet)
  }
  
  // print bookmark list from array
  
  open func printBookmark()
  {
    let  bookMarkSet = Set([MARK_TYPE.BOOKMARK])
    printSetOfType(bookMarkSet)
  }
  
  // print items that match the set member type
  
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
  
  // optional return formatted string of entry that if of any type in the set of cut types
  
  func cutDataMarkOfTypeAsString(_ cutEntry: CutEntry, markSet : Set<MARK_TYPE>) -> String?
  {
    var result : String? = nil
    if (markSet.contains(MARK_TYPE.lookupOnRawValue(cutEntry.cutType)!))
    {
      result =  cutEntry.asString()
    }
    return result
  }
  
  open func saveCutsToFile(_ fullFileName :String, using fileMgr: FileManager)
  {
    
    let item = NSMutableData()
    
    for entry in cutsArray
    {
      var entryCopy = CutEntry(cutPts: entry.cutPts.bigEndian, cutType: entry.cutType.bigEndian)
      item.append(&entryCopy, length: MemoryLayout<CutEntry>.size)
    }
    
    let fileWritten = fileMgr.createFile(atPath: fullFileName, contents: item as Data, attributes: nil)
    
    if (fileWritten && debug) {
      print(MessageStrings.DID_WRITE_FILE)
    }
    modified = false
  }
  
  /// check that there are no IN, IN or OUT, OUT sequences present
  /// - returns: result of validation and message if flaw was found or empty string if good
  
  open func validateInOut() -> (result: Bool, errorMessage: String) {
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
          message = "Sequential IN cut Marks"
          break
        }
      case .OUT :
        if (currentState == .unknown || currentState == .inCut ) {
          currentState = .outCut
          goodList = goodList && true
        }
        else {
          goodList = false
          message = "Sequential OUT cut Marks"
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
