//
//  MovieCuttingOperation.swift
//  CutsEditor
//
//  Created by Alan Franklin on 5/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

class MovieCuttingOperation: Operation
{
  let moviePath : String
  var resultMessage = ""
  var targetPathName = ""
  var mcutCommand = ""
  var mcutSystem = ""
  var mcutCommandArgs = [String]()
  let debug = false
  var sysConfig: systemConfiguration
  let onCompletion : MovieCutCompletionBlock
  let onStart : MovieCutStartBlock
  
  // get the passed in starting directory
  init(movieToBeCutPath : String, sysConfig: systemConfiguration, commandArgs: [String], onCompletion: @escaping MovieCutCompletionBlock, onStart: @escaping MovieCutStartBlock)
  {
    self.moviePath = movieToBeCutPath
    self.onCompletion = onCompletion
    self.onStart = onStart
    self.sysConfig = sysConfig
    self.mcutCommandArgs = commandArgs
  }
  
  override func main() {
    let FAILED_TO_NORMALIZE_MESSAGE = "Failed to normalize movie path name \"%@\""
    let FAILED_TO_READ_RESULT = "Failed Reading process result"
    let UNKNOWN_ERROR_CODE = "Unknown error code %@ for \"%@\""
    let ABORTED_MESSAGE = "Cutting was aborted for movie \"%@\""
    let global_mcut_errors = ["The movie \"%@\" is successfully cut",
                              ("Cutting failed for movie \"%@\"")+":\n"+("Bad arguments"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .ts file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .cuts file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .ap file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .ts file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .cuts file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .ap file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Empty .ap file"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("No cuts specified"),
                              ("Cutting failed for movie \"%@\"")+":\n"+("Read/write error (disk full?)"),
                              (ABORTED_MESSAGE),
                              (FAILED_TO_READ_RESULT),
                              (FAILED_TO_NORMALIZE_MESSAGE),
                              (UNKNOWN_ERROR_CODE)]
    
    var cutResultStatusValue: Int = global_mcut_errors.index(of: ABORTED_MESSAGE)! // aborted
    
    // have we been cancelled ?
    let shortTitle = ViewController.programDateTitleFrom(movieURLPath: moviePath)
    guard (!self.isCancelled) else {
      //      print("was cancelled by user")
      resultMessage = String.init(format: global_mcut_errors[cutResultStatusValue], shortTitle)
      DispatchQueue.main.async {
        self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
      }
      return
    }
    
    // check that we form a normal file path from the url ?
    guard let diskPathName = moviePath.replacingOccurrences(of: "file://",
                                                        with: "").removingPercentEncoding else
    {
      cutResultStatusValue = global_mcut_errors.index(of: FAILED_TO_NORMALIZE_MESSAGE)!
      resultMessage = String.init(format: global_mcut_errors[Int(cutResultStatusValue)], targetPathName)
      DispatchQueue.main.async {
        self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
      }
      return
    }
    
    // MARK:  remote / detached task fabricated here
    let outPipe = Pipe()
    if let cutTask = buildCutTaskFrom(movieDiskPath: diskPathName, withArgs: mcutCommandArgs)
    {
      cutTask.standardOutput = outPipe
      let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
      print("\(timestamp) Launching for >\(shortTitle)<")
      DispatchQueue.main.async { [unowned self] in
        // callback that job has been started for name returned (update tooltip entry)
        self.onStart(shortTitle)
      }
      
      cutTask.launch()
      let handle = outPipe.fileHandleForReading
      let data = handle.readDataToEndOfFile()
      cutTask.waitUntilExit()
      let result = cutTask.terminationStatus
      cutResultStatusValue = Int(result)
      if let resultString = String(data: data, encoding: String.Encoding.utf8) {
        print( resultString)
//        print("got result of \(result)")
        // bounds limit message lookup - remote program may change and introduce unknown result values
        
        let messageIndex = (cutResultStatusValue >= 0 && cutResultStatusValue < global_mcut_errors.count) ? cutResultStatusValue : global_mcut_errors.count-1
        resultMessage = String.init(format: global_mcut_errors[messageIndex], shortTitle)
        print(resultMessage)
        // TODO: add code to to handle "new output file case"
      }
    }
  
    // job done.  Send results back to caller
    DispatchQueue.main.async {
      self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
    }
  }
  
  /// Populate the task with app and args appropriate to local or remote
  /// execution of cut process
  /// - parameter movieDiskPath: disk format path the cuts file
  /// - parameter withArgs: list of arguments to cutting program from context and user prefs
  
  func buildCutTaskFrom(movieDiskPath: String, withArgs: [String]) -> Process?
  {
    var mcutCommand: String
    var mcutCommandArgs: [String]
    
    let cutTask = Process()
    var targetPathName = movieDiskPath.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    
    // determine if we are this process is local or remote and fabricate commnad line accordingly
    // local has multiple args, remote has program and args passed as single arg to be interpretted by
    // the remote system
    
    if (isRemote(pathName: targetPathName)) {
      targetPathName = targetPathName.replacingOccurrences(of: mcutConsts.localMount, with: mcutConsts.remoteExportPath)
      mcutCommand = mcutConsts.mcutProgramRemote
      cutTask.launchPath = sysConfig.sshPath
    }
    else {  // local processing
      mcutCommand = mcutConsts.mcutProgramLocal
      cutTask.launchPath = mcutCommand
    }
    
    // build array of command arguments with required switches
    // array is collapsed to single string for remote or passed on as array of args to local command
    //      mcutCommandArgs = getCutsCommandLineArgs()
    mcutCommandArgs = withArgs
    mcutCommandArgs = mcutCommandArgs.map({$0.replacingOccurrences(of: " ", with: "\\ ")})
    if (cutTask.launchPath == mcutConsts.mcutProgramLocal)
    {
      mcutCommandArgs.append("\(targetPathName)")
      cutTask.arguments = mcutCommandArgs
    }
    else {
      mcutCommandArgs.insert(mcutConsts.mcutProgramRemote, at: 0)
      // FIXME: check handling of apostrophe's in local directories
      targetPathName = targetPathName.replacingOccurrences(of: "'", with: "\\'")
      mcutCommandArgs.append(targetPathName.replacingOccurrences(of: " ", with: "\\ ") )
      cutTask.arguments = [sysConfig.remoteManchineAndLogin, mcutCommandArgs.joined(separator: " ")]
    }
    if (debug) {
      let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
      print("\(timestamp) Creating launch >\(cutTask.launchPath)<")
      print("with args:< \(cutTask.arguments)>")
    }
    return cutTask
  }

  /// Return is pathname contains a remote mount point.
  /// That is, guess if we are looking a a local or a remote file
  /// where remote means on the PVR.  This get bamboozled with networked
  /// drives.  For now we cut local files locally and assume remote files
  /// are on a machine that has mcut
  func isRemote(pathName: String) -> Bool
  {
    return  (pathName.contains(mcutConsts.localMount)) ? true : false
  }
}
