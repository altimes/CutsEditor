//
//  Recording.swift
//  CutsEditor
//
//  Created by Alan Franklin on 29/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation

// Protocol to provide a means for the various elements of recording
// to ask from unrelated information without a hard reference to that
// element (ie ap file) which may not exist.

/// Class to model the elements of Beyonwiz Tx series recording
/// Also acts a communication delegate between recording components
/// with the objective a interrogation about commonly used elements
/// such a pts ranges, discontinuity in pts and other
@objcMembers


class Recording 
{
  //  var movie: TransportStream?
  var movieName: String?
  var movieShortName: String?
  var eit  : EITInfo
  var meta : MetaData
  var cuts : CutsFile
  var ap   : AccessPoints
  //  var sc   : StuctureCache?
  static var debug = false
  var isCuttable: Bool {
    get {
      return cuts.isCuttable
    }
  }
  
  var hasCutsToPerform: Bool {
    return cuts.inOutOnly.count > 0
  }
  
  /// injected from viewController when/if player comes ready with video
  var videoDurationFromPlayer: Double = 0.0
  
  
  /// Readonly computed var of the position of the last OUT pts.  If no OUT is present,
  /// or it is followed by an IN
  /// then return the max of the metadata duration (which for some broadcasters
  /// can be 0 (!)) and the video duration determined by the AVPlayer
  
  var lastOutCutPTS: UInt64 {
    get {
      var pts : UInt64
      let metaPTS : UInt64 = UInt64( meta.duration) ?? UInt64(0)
      let videoPTS : UInt64 = UInt64( videoDurationFromPlayer * Double(CutsTimeConst.PTS_TIMESCALE))
      
      if (metaPTS == UInt64(0)) {
        pts = videoPTS
      }
      else {
        pts = max(metaPTS, videoPTS)
      }
      //
      // get in/out pairs only
      let inOut = cuts.inOutOnly
      if let entry = inOut.last
      {
        if entry.cutType == MARK_TYPE.OUT.rawValue {
          pts = entry.cutPts
        }
      }
      else { // no in/out pairs, may be already cut
        if ap.hasGaps { // has had middle cuts done
          pts = ap.runtimePTS
        }
      }
      return pts
    }
  }
  
  var movieFiles:[String]  {
    get {
      if (movieName == nil)
      {
        return Array<String>(repeating: "", count:6)
      }
      else {
        var namesArray:[String] = Array<String>(repeating: "", count:6)
        namesArray[0] = movieName! + ConstsCuts.TS_SUFFIX
        namesArray[1] = movieName! + ConstsCuts.AP_SUFFIX
        namesArray[2] = movieName! + ConstsCuts.META_SUFFIX
        namesArray[3] = movieName! + ConstsCuts.EIT_SUFFIX
        namesArray[4] = movieName! + ConstsCuts.SC_SUFFIX
        namesArray[5] = movieName! + ConstsCuts.CUTS_SUFFIX
        return namesArray
      }
    }
  }
  
  /// Cache of all the "small" files to save from reaccessing high latency network connections (VPN)
  static var cache = Cache<NSString,Data>()
  
  /// Get the OS record of a fully specified file
  /// - parameter filePath: fully specified file path
  /// - returns: Byte count of file from OS
  
  static func getFileSize(filePath: String) -> UInt64
  {
    var fileSize : UInt64 = 0
    
    // if file is in caches, then return data count
    if let data = cache.value(forKey: NSString(string: filePath)) {
      // all good
      print ("actual size from cache is \(data.count)")
      return UInt64(data.count)
    }
    do {
      //return [FileAttributeKey : Any]
      let attr = try FileManager.default.attributesOfItem(atPath: filePath)
      fileSize = attr[FileAttributeKey.size] as! UInt64
      
      //if you convert to NSDictionary, you can get file size old way as well.
      //            let dict = attr as NSDictionary
      //            fileSize = dict.fileSize()
      
    } catch {
      print("Error - Cannot get filesize from OS: \(error)")
    }
    print ("actual size from os is \(fileSize)")
    
    return fileSize
  }
  
  // dummy initialzer
  convenience init() {
    self.init(rootURLName: "")
  }
  
  init(rootURLName: String)
  {
    if (rootURLName.count == 0)
    {
      cuts = CutsFile()
      meta = MetaData()
      eit = EITInfo()
      ap = AccessPoints()
    }
    else {
      movieName = rootURLName.replacingOccurrences(of: "file://", with: "").removingPercentEncoding
      movieShortName = Recording.programDateTitleFrom(movieURLPath: rootURLName)
      
      // load the meta file
      meta = MetaData()
      if let metaRawData = Recording.loadRawDataFrom(file: movieName!+ConstsCuts.META_SUFFIX)
      {
        meta = MetaData(data: metaRawData)
      }
      
      // load the cuts file
      cuts = CutsFile()
      if let cutsRawData = Recording.loadRawDataFrom(file: movieName!+ConstsCuts.CUTS_SUFFIX) {
        cuts = CutsFile(data: cutsRawData)
      }
      
      // load the ap file
      ap = AccessPoints()
      if let apRawData = Recording.loadDataFromBinary(file: movieName!+ConstsCuts.AP_SUFFIX) {
        if (apRawData.count > badApLoadThreshold)
        {
          print("What the fudge, the ap file is not \(apRawData.count) bytes in size")
          let filePath = movieName!+ConstsCuts.AP_SUFFIX
          let fileSize = Recording.getFileSize(filePath: filePath)
          print ("OS reports file size of \(fileSize)")
        }
          // only proceed with rational ap counts otherwise leave ap unpopulated
        else if let apts = AccessPoints(data: apRawData, fileName:movieShortName ?? "indeterminate")
        {
          ap = apts
        }
      }
      
      // load the eit file
      eit = EITInfo()
      if let EITData = Recording.loadRawDataFrom(file: movieName!+ConstsCuts.EIT_SUFFIX) {
        if let eitInfo=EITInfo(data: EITData) {
          eit = eitInfo
        }
      }
    }
    cuts.container = self
    ap.container = self
    eit.container = self
  }
  
  /// Writes the cuts collection back to a file formatted for the PVR
  /// - returns : success or failure of save
  public func saveCuts() -> Bool
  {
    return cuts.saveAs(filenamePath: movieName!+ConstsCuts.CUTS_SUFFIX)
  }
  
  // MARK: OS utility functions
  
  /// Utility function that unpacks the file name and check that the file is exists
  /// and is accessible.
  /// - parameter fullFileName: path to the file
  /// - returns : touple of a filemanager, status of files existence and the resolved path to file
  static func getFileManagerForFile( _ fullyPathedFilename : String) -> (FileManager, Bool, String)
  {
    var pathName : String
    let fileMgr : FileManager = FileManager.default
    if (debug) { print (#function+":"+fullyPathedFilename) }
    
    pathName = ""
    if let checkIsURLFormat = URL(string: fullyPathedFilename)
    {
      pathName = checkIsURLFormat.path
    }
    else // assume file system format
    {
      pathName = fullyPathedFilename
    }
    let fileExists = fileMgr.fileExists(atPath: pathName)
    return (fileMgr, fileExists, pathName)
  }
  
  /// Read the file into a Data element but with an artificial delay.  The delay is
  /// to accomodate a remote system that has notified of a completed a task, however, the underlying
  /// remote OS has not completedthe write back to disk.  Resulting in the next access to the file
  /// reading rubbish.  Only intended to be used when detached process is notified of completion
  /// Simple wrapper around loadRawDataFromFile
  
  /// Seems to only affect meta data file for an unknown reason
  
  static func loadRawDataDelayedFrom(file filename:String, withDelay delay: UInt32) -> Data?
  {
    /// - parameter filename: fully defined file path
    /// - parameter withDelay: int of seconds delay
    /// - returns : raw arbitrary data
    usleep(delay*1_000)
    return loadRawDataFrom(file: filename)
  }
  
  /// Binary data loader
  /// - parameter filename: fully defined file path
  /// - returns : raw arbitrary data
  
  static func loadRawDataFrom(file filename:String) -> Data?
  {
    var data:Data?
    
    // check cache for data
    if (debug) {
      print(#function+" Cache keys are \(cache.keys)")
    }
    data = cache.value(forKey: NSString(string: filename))
    if ( data == nil ) { // load the file from disk
      let (fileMgr, foundFile, fullFileName) = getFileManagerForFile(filename)
      
      if (foundFile)
      {
        // FIXME: this is failing some how with huge amounts of data being read
        data = fileMgr.contents(atPath: fullFileName)
        if (debug)  {
          print("Found file \(fullFileName)")
          print("Found file of \((data?.count ?? 0))! size")
        }
        // not interested in empty files.... may as well be missing
        if (data?.count == 0 ) {
          data = nil
        }
      }
      if data != nil { // add to cache
        cache.insert(data!, forKey: NSString(string: filename))
      }
    }
    return data
  }
  
  static func loadDataFromBinary(file filename:String) -> Data?
  {
    var data:Data?
    
    // check cache for data
    if (debug) {
      print(#function+" Cache keys are \(cache.keys)")
    }
    data = cache.value(forKey: NSString(string: filename))
    if ( data == nil ) { // load the file from disk
//      let (fileMgr, foundFile, fullFileName) = getFileManagerForFile(filename)
      let (_, foundFile, fullFileName) = getFileManagerForFile(filename)

      if (foundFile)
      {
        let fileURL = URL(fileURLWithPath: fullFileName)
        data = try? Data(contentsOf:fileURL)
        
        if (debug)  {
          print("Found file \(fullFileName)")
          print("Found file of \((data?.count ?? 0))! size")
        }
        // not interested in empty files.... may as well be missing
        if (data?.count == 0 ) {
          data = nil
        }
        if (data != nil && (data!.count > badApLoadThreshold) && fullFileName.hasSuffix(ConstsCuts.AP_SUFFIX) ) {
          print("arghh bad structure size - got \((data != nil) ? data!.count : -1)")
          // probably side effect of race condition in which operation has returned
          // as complete, but OS may be still lazily persisting file to disk
          // try a few more times before giving up
          var badCount = true
          var i = 0
          while badCount && i<10 {
            let fileURL = URL(fileURLWithPath: fullFileName)
            data = try? Data(contentsOf:fileURL)
            
            if (debug)  {
              print("Found file \(fullFileName)")
              print("Found file of \((data?.count ?? 0))! size")
            }
            badCount = (data?.count ?? 0) < badApLoadThreshold
            i += 1
          }
          data = nil
        }
        if data != nil { // add to cache
          cache.insert(data!, forKey: NSString(string: filename))
        }
      }
    }
    return data
  }

  
  /// return to first PTS from the ap file, else 0
  // TODO: develop function to read first PTS from recording if ap file is not present
  /// - returns: access the first ProgramTimeStamp in the AccessPoints
  func firstPts() -> PtsType
  {
    return self.ap.firstPTS
  }
  
  /// Extract selected fields from expected "dateTime - channel - programTitle" formated string
  fileprivate static func getFieldsFromCutsFilename(movieURLPath: String, dateTime: Bool, channelName: Bool, programTitle: Bool) -> String
  {
    let fileNameSeperator = "-"
    var programName = ""
    let basename = movieURLPath.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    if let fullPathName = basename.replacingOccurrences(of: "file://",
                                                        with: "").removingPercentEncoding {
      if let title = fullPathName.components(separatedBy: "/").last {
        programName = title
        let fileElements = programName.components(separatedBy: fileNameSeperator)
        var conjuction = ""
        if (fileElements.count >= 3) { // this is the expected format else return full title
          programName = ""
          programName += dateTime ? fileElements[0] : ""
          if (programName != "" ) { conjuction = fileNameSeperator }
          programName += channelName ? conjuction+fileElements[1] : ""
          if (programName != "" ) { conjuction = fileNameSeperator }
          programName += programTitle ? conjuction+fileElements[2 ..< fileElements.count].joined(separator: fileNameSeperator) : ""
        }
      }
    }
    return programName
  }
  
  /// Extract the short movie title from the file path
  public static func programTitleFrom(movieURLPath: String) -> String
  {
    return getFieldsFromCutsFilename(movieURLPath: movieURLPath, dateTime: false, channelName: false, programTitle: true)
  }
  
  /// Extract the short movie title from the file path
  public static func programDateTitleFrom(movieURLPath: String) -> String
  {
    return getFieldsFromCutsFilename(movieURLPath: movieURLPath, dateTime: true, channelName: false, programTitle: true)
  }
  
  /// Find the earliest position in the video.  This should be;
  /// the first IN mark not preceed by an out Mark,
  /// failing that, if there are <= 3 bookmarks,
  /// use the first bookmark - most likely an unedited file.
  /// Otherwise use then use the initial file position
  /// which may have to be fabricated if it does not exist.
  
  func firstVideoPosition() -> CutEntry {
    return cuts.firstVideoPosition()
  }
  
  
  /// Decode and return the three stored recording durations in seconds.  Durations
  /// come from the EIT, the metaData and calculated from the AccessPoints
  /// - returns: touple of (eitDuration, metaDuration, ptsDuration) all Doubles
  
  func getStoredDurations() -> (eitDuration: Double, metaDuration:Double, ptsDuration:Double)
  {
    var metaFileDuration: Double = 0.0
    var eitFileDuration: Double = 0.0
    var accessPointsFileDuration: Double
    
    // get from EIT
    if (eit.eit.Duration != "00:00:00" && eit.eit.Duration != "") {
      //        self.programDuration.stringValue = eitInfo.eit.Duration
      let timeParts = eit.eit.Duration.components(separatedBy: ":")
      eitFileDuration = Double(timeParts[0])!*3600.0 + Double(timeParts[1])!*60.0+Double(timeParts[2])!
    }
    
    // get from metaData
    if (meta.duration != "0" && meta.duration != "")
    {  // meta data looks OK, use it for duration display
      metaFileDuration = Double(meta.duration)!*CutsTimeConst.PTS_DURATION
    }
    
    // get from accessPoints
    accessPointsFileDuration = ap.durationInSecs()
    
    return (eitFileDuration, metaFileDuration, accessPointsFileDuration)
  }
  
  /// Check validity of meta data duration
  /// - parameter metaTime: Duration in Seconds
  /// - parameter eitTime: Duration in Seconds
  /// - parameter playerTime: Duration in Seconds
  /// - parameter apTime: Duration in Seconds
  /// - returns: valid to use metaTime
  func isMetaDurationOK(metaTime: Double, eitTime: Double, playerTime: Double, apTime: Double) -> Bool
  {
    // meta data duration can be wildly wrong only use it, if it is within
    // 50% of the others
    let meta2EIT = metaTime/eitTime
    let meta2player = metaTime/playerTime
    let meta2ap = metaTime/apTime
    let ok2UseMeta = meta2EIT > 0.5 && meta2player > 0.5 && meta2ap > 0.5
    return ok2UseMeta
  }
  
  /// Inspect metadata, eit and player to get a best guess of the program duration
  /// in seconds.  metaData can have 0 entry, eit can refer to a later program
  /// subject to EPG and broadcaster variances
  ///
  /// first uses meta data duration
  /// if that is missing or zero, then it return the event duration
  /// from the eit it that is non-zero
  /// finally queries the current item being played if there is any
  
  /// - parameter meta: decoded meta data structure
  /// - parameter eit: decoded eit structure
  /// - parameter player: player if running, may be nil
  /// - returns: duration in seconds or 0.0 if it cannot be obtained
  
  func getBestDurationAndApDurationInSeconds(playerDuration: Double = 0) -> (best: Double, ap: Double)
  {
    // get the program duration from all sources and choose the least of the
    // non-zero values
    // It *looks* as though the Execute Cuts plugin does not update metaData or eit file
    // all durations in seconds
    var metaDuration: Double = 0.0
    var eitDuration: Double = 0.0
    var accessPointsDuration: Double = 0.0
    var bestDuration: Double = 0.0
    
    metaDuration = getStoredDurations().metaDuration
    eitDuration = getStoredDurations().eitDuration
    accessPointsDuration = getStoredDurations().ptsDuration
    
    if (Recording.debug) {
      print("Meta Duration = \(metaDuration)")
      print("EIT Duration = \(eitDuration)")
      print("Player Duration = \(playerDuration)")
      print("Access Points Duration = \(accessPointsDuration)")
    }
    
    // cascade to pick out minimum non-zero duration
    if (playerDuration != 0.0) {
      bestDuration = playerDuration
    }
    if (metaDuration != 0.0 && bestDuration != 0.0)
    {
      if (isMetaDurationOK(metaTime: metaDuration, eitTime: eitDuration, playerTime: playerDuration, apTime: accessPointsDuration))
      {
        bestDuration = min(bestDuration, metaDuration)
      }
    }
    else if (metaDuration != 0.0 && isMetaDurationOK(metaTime: metaDuration, eitTime: eitDuration, playerTime: playerDuration, apTime: accessPointsDuration))
    {
      bestDuration = metaDuration
    }
    if (eitDuration != 0.0 && bestDuration != 0.0)
    {
      bestDuration = min(bestDuration, eitDuration)
    } else if (eitDuration != 0.0 ) {
      bestDuration = eitDuration
    }
    if (accessPointsDuration != 0.0 && bestDuration != 0.0)
    {
      bestDuration = min(bestDuration, accessPointsDuration)
    } else if (accessPointsDuration != 0) {
      bestDuration = accessPointsDuration
    }
    return (bestDuration, accessPointsDuration)
  }
  
  /// Build a string from player and recording that shows all possible recording durations
  /// for use as a tooltip on GUI
  
  var durationStrings: [String]
  {
    get {
      let (eitDuration, metaDuration, ptsDuration) = self.getStoredDurations()
      let eitString =  "eit: " + CutEntry.hhMMssFromSeconds(eitDuration)
      let metaString = "meta: " + CutEntry.hhMMssFromSeconds(metaDuration)
      let apString = "ap: " + CutEntry.hhMMssFromSeconds(ptsDuration)
      return [eitString, metaString, apString]
    }
  }
  
  /// Clear cache of entries for this recording
  
  func removeFromCache() {
    for item in movieFiles {
      Recording.cache.removeValue(forKey: NSString(string: item))
    }
  }
  
  func reloadCurrentCache() {
    
  }
  
  /// Update data content of cache. Ensure that cache is kept in sync with "Save" operations
  
  func updateValueInCache(_ value: Data, forKey key: String) {
    Recording.cache.update(value, forKey: NSString(string: key))
  }
  
}
