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

protocol RecordingResources {
  func firstPts() -> PtsType
}

/// Class to model the elements of Beyonwiz Tx series recording
/// Also acts a communication delegate between recording components
/// with the objective a interrogation about commonly used elements
/// such a pts ranges, discontinuity in pts and other

class Recording : RecordingResources
{
  var movieName: String?
//  var movie: TransportStream?
  var eit  : EITInfo
  var meta : MetaData
  var cuts : CutsFile
  var ap   : AccessPoints
//  var sc   : StuctureCache?
  static var debug = false
  
  
  convenience init() {
    self.init(rootProgramName: "")
  }
  
  init(rootProgramName: String)
  {
    if (rootProgramName.characters.count == 0)
    {
      cuts = CutsFile()
      meta = MetaData()
      eit = EITInfo()
      ap = AccessPoints()
    }
    else {
      movieName = rootProgramName
      meta = MetaData()
      eit = EITInfo()
      ap = AccessPoints()
      cuts = CutsFile()
      if let cutsRawData = Recording.loadRawDataFrom(file: movieName!+ConstsCuts.CUTS_SUFFIX) {
        cuts = CutsFile(data: cutsRawData)
        cuts.delegate = self
      }
    }
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
//    if let pts = ap.firstPTS
//    {
//      return pts
//    }
//    return PtsType(0)
    return ap.firstPTS
  }
}
