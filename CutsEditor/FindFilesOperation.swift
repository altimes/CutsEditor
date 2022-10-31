//
//  FindFilesOperation.swift
//  CutsEditor
//
//  Created by Alan Franklin on 5/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

let trashDirectoryName = ".Trash"
let localTrash = ".Trashes"
let NASTrash = "#recycle"
let Olympics = "Olympics_"
let BeyonWizT4 = "BeyonWizT4"
let BeyonWizU4 = "BeyonWizU4"

// MARK: - file search support class

/// This creates and detaches a remote/local system query to build a list of files
/// and return it to the program without doing all the file traversal work within the
/// program.   This is optimization that removes large network delays incurred with
/// programmatic directory traversal.  It is less generic but much quicker.


class FindFilesOperation: Operation
{
  var foundfiles = [String]()
  var suffixRequired: String
  var foundRootPath : String
  var localMountPoint: String
  var remoteExportPath: String
  var pvrIndex: Int
  
  var isRemote: Bool
  var sysConfig: systemConfiguration
  var onCompletionBlock: FindCompletionBlock
  let debug = false
  static let trashes = [trashDirectoryName, NASTrash, localTrash, Olympics, BeyonWizT4, BeyonWizU4]

  /// Create a operation queue for file finding
  /// - returns: the queue
  public static func createQueue() -> OperationQueue
  {
    // create the queue
    let queue = OperationQueue()
    queue.name = "File Search queue"
    // make it serial
    queue.maxConcurrentOperationCount = 1
    return queue
  }
  
  
  init(foundRootPath : String, withSuffix: String, pvrIndex: Int, isRemote: Bool, sysConfig: systemConfiguration, completion: @escaping FindCompletionBlock)
  {
    self.foundRootPath = foundRootPath
    self.suffixRequired = withSuffix
    if (isRemote) {
      self.localMountPoint = sysConfig.pvrSettings[pvrIndex].cutLocalMountRoot
      self.remoteExportPath = sysConfig.pvrSettings[pvrIndex].cutRemoteExport
    }
    else {
      self.localMountPoint = mcutConsts.localMount
      self.remoteExportPath = mcutConsts.remoteExportPath
    }
    self.onCompletionBlock = completion
    self.sysConfig = sysConfig
    self.pvrIndex = pvrIndex
    self.isRemote = isRemote
  }
  
  override func main()
  {
    // check if killed before starting
    if (self.isCancelled) {
      return
    }
    
    // build directory exclusion chain
    
    var excluding = ""
    for dir in FindFilesOperation.trashes {
      excluding += " | grep -v \\\(dir) "
    }
    // use a task to get a count of the files in the directory
    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
    // CLI specifics are for BeyonWiz Enigma2 BusyBox 4.4
    
    
    var searchPath: String
    let fileCountTask = Process()
    let outPipe = Pipe()
    if (self.foundRootPath.contains(self.localMountPoint) && isRemote) {
      searchPath = self.foundRootPath.replacingOccurrences(of: self.localMountPoint, with: self.remoteExportPath)
      fileCountTask.launchPath = sysConfig.pvrSettings[pvrIndex].sshPath
      let limitSize = false
      var flag = ""
      if limitSize {
        flag = " -size -48c"
      }
      fileCountTask.arguments = [sysConfig.pvrSettings[pvrIndex].remoteMachineAndLogin, "/usr/bin/find \"\(searchPath)\" \(flag) -xdev -regex \"^.*\\\(self.suffixRequired)$\" \(excluding) | grep -v denied | grep -v \"^.*/\\.\""]
      print("remote file count args \(fileCountTask.arguments ?? ["Empty args field"])")
// find /Volumes/WizVideo/ -type d -path /Volumes/WizVideo//BeyonWizT4 -prune -false -o -print
    }
    else {
      fileCountTask.launchPath = mcutConsts.shPath
      fileCountTask.arguments = ["-c", "/usr/bin/find \"\(self.foundRootPath)\" -regex \"^.*\\\(self.suffixRequired)$\" \(excluding) | grep -v denied"]
      print("local file count args \(fileCountTask.arguments ?? ["no args"])")
      searchPath = self.foundRootPath
    }
    fileCountTask.standardOutput = outPipe
    fileCountTask.launch()
    let handle = outPipe.fileHandleForReading
    let data = handle.readDataToEndOfFile()
    var builtURLArray: [String]?
    if let resultString = String(data: data, encoding: String.Encoding.utf8)
    {
      // build array from string result
      let trimmedString = resultString.trimmingCharacters(in: CharacterSet(charactersIn:" \n"))
      if (!trimmedString.isEmpty ) {
        let fileNameArray = trimmedString.components(separatedBy: "\n")
        // typically replace the /hdd/media/movie with /Volumes/Movie for local handling
        let reducedFileNameArray = fileNameArray.map({$0.replacingOccurrences(of: self.remoteExportPath, with: self.localMountPoint)})
        builtURLArray = reducedFileNameArray.map({NSURL(fileURLWithPath: $0.replacingOccurrences(of: "//", with: "/")).absoluteString!})
        //
        // All done send results back to interactive code thread
        //
        DispatchQueue.main.async(execute:  {
          self.onCompletionBlock(builtURLArray, self.suffixRequired, self.isCancelled)
        })
      }
      else {
        DispatchQueue.main.async(execute:  {
          self.onCompletionBlock(nil, self.suffixRequired, self.isCancelled)
        })
      }
    }
  }
}



