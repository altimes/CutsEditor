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

open class CutsFile: NSObject {
  
  // model: array of cuts data
  
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
  
  var debug = false
  
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
  
  func firstINMark() -> CutEntry?
  {
    let INArray = cutsArray.filter() {$0.cutType == MARK_TYPE.IN.rawValue}
    return INArray.first
  }
  
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
    
    if (fileWritten) {
      print(MessageStrings.DID_WRITE_FILE)
    }
  }
  
  // - check all pts within range of corresponding file
  // - check if at least one IN OUT pair exist - if not, then fabricate as
  //   first or last file point
  
//  public func validate() -> Bool
//  {
//    return false
//  }
}
