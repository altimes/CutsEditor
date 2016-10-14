//
//  FindFilesOperation.swift
//  CutsEditor
//
//  Created by Alan Franklin on 5/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

// MARK: - file search support class


class FindFilesOperation: Operation
{
  var foundfiles = [String]()
  var suffixRequired: String
  var foundRootPath : String
  var localMountPoint: String
  var remoteExportPath: String
  var sysConfig: systemConfiguration
  var onCompletionBlock: FindCompletionBlock
  let debug = false
  
  // get the passed in starting directory
  init(foundRootPath : String, withSuffix: String, localMountPoint: String, remoteExportPath: String, sysConfig: systemConfiguration, completion: @escaping FindCompletionBlock)
  {
    self.foundRootPath = foundRootPath
    self.suffixRequired = withSuffix
    self.localMountPoint = localMountPoint
    self.remoteExportPath = remoteExportPath
    self.onCompletionBlock = completion
    self.sysConfig = sysConfig
  }
  
  override func main()
  {
    // check if killed before starting
    if (self.isCancelled) {
      //      print("was cancelled by user")
      return
    }
    // use a task to get a count of the files in the directory
    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
    // CLI specifics are for BeyonWiz Enigma2 BusyBox 4.4
    let start = clock()
    var searchPath: String
    let fileCountTask = Process()
    let outPipe = Pipe()
    if (self.foundRootPath.contains(self.localMountPoint)) {
      searchPath = self.foundRootPath.replacingOccurrences(of: self.localMountPoint, with: self.remoteExportPath)
      fileCountTask.launchPath = sysConfig.sshPath
      fileCountTask.arguments = [sysConfig.remoteManchineAndLogin, "/usr/bin/find \"\(searchPath)\" -regex \"^.*\\\(self.suffixRequired)$\" | grep -v \\.Trash"]
    }
    else {
      fileCountTask.launchPath = sysConfig.shPath
      fileCountTask.arguments = ["-c", "/usr/bin/find \"\(self.foundRootPath)\" -regex \"^.*\\\(self.suffixRequired)$\" | grep -v \\.Trash"]
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
        // typically replace the /hdd/media with /Volumes/Harddisk for local handling
        let reducedFileNameArray = fileNameArray.map({$0.replacingOccurrences(of: self.remoteExportPath, with: self.localMountPoint)})
        builtURLArray = reducedFileNameArray.map({NSURL(fileURLWithPath: $0.replacingOccurrences(of: "//", with: "/")).absoluteString!})
        //
        // All done dispatch results back to application
        //
        DispatchQueue.main.async(execute:  {
          self.onCompletionBlock(builtURLArray, self.suffixRequired, self.isCancelled)
        })
      }
    }
    
    let delta = Double(clock() - start) / Double(CLOCKS_PER_SEC)
    print("took time \(delta) seconds")
  }
}



