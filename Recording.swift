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

//class Recording : RecordingResources
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
  
  /// injected from viewController when/if player comes ready with video
  var videoDurationFromPlayer: Double = 0.0
  
  // TODO: move to Recording class
  // in the controller whilst it has access to all the elements of a recording AND the videoPlayer
  // better placed in either the cutsfile class or the Recording class once populated
  
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
  
  convenience init() {
    self.init(rootURLName: "")
  }
  
  init(rootURLName: String)
  {
    if (rootURLName.characters.count == 0)
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
      if let apRawData = Recording.loadRawDataFrom(file: movieName!+ConstsCuts.AP_SUFFIX) {
        if let apts = AccessPoints(data: apRawData)
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
    if (debug) { print (fullyPathedFilename) }
    
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
  
  /// Binary data loader
  /// - parameter filename: fully defined file path
  /// - returns : raw arbitrary data
  
  static func loadRawDataFrom(file filename:String) -> Data?
  {
    var data:Data?
    
    let (fileMgr, foundFile, fullFileName) = getFileManagerForFile(filename)
    
    if (foundFile)
    {
      data = fileMgr.contents(atPath: fullFileName)
      if (debug)  {
        print("Found file ")
        print("Found file of \((data?.count))! size")
      }
      // not interested in empty files.... may as well be missing
      if (data?.count == 0 ) {
        data = nil
      }
    }
    return data
  }
  
  // MARK: RecordingResource Protocol implementation
  
  // return to first PTS from the ap file, else 0
  // TODO: develop function to read first PTS from recording if ap file is not present
  func firstPts() -> PtsType
  {
    return ap.firstPTS
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
  
  func getBestDurationInSeconds(playerDuration: Double = 0) -> Double
  {
    // get the program duration from all sources and choose the least of the
    // non-zero values
    // It *looks* as though the Execute Cuts plugin does not update metaData or eit file
    // all durations in seconds
    var metaDuration: Double = 0.0
    var eitDuration: Double = 0.0
    var accessPointsDuration: Double = 0.0
    var bestDuration: Double = 0.0
    // eventinfo table
    if (eit.eit.Duration != "00:00:00" && eit.eit.Duration != "") {
      //        self.programDuration.stringValue = eitInfo.eit.Duration
      let timeParts = eit.eit.Duration.components(separatedBy: ":")
      eitDuration = Double(timeParts[0])!*3600.0 + Double(timeParts[1])!*60.0+Double(timeParts[2])!
    }
    
    // metaData
    if (meta.duration != "0" && meta.duration != "")
    {  // meta data looks OK, use it for duration display
      metaDuration = Double(meta.duration)!*CutsTimeConst.PTS_DURATION
    }
    
    // accessPoints
    accessPointsDuration = ap.durationInSecs()
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
      bestDuration = min(bestDuration, metaDuration)
    }
    else if (metaDuration != 0.0) {
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
    return bestDuration
  }
}
