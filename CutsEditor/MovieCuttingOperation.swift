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
  let debug = false
  var sysConfig: systemConfiguration
  let onCompletion : MovieCutCompletionBlock
  let onStart : MovieCutStartBlock
  var pvrIndex : Int
  var isRemote = true
  let FAILED_TO_NORMALIZE_MESSAGE = "Failed to normalize movie path name \"%@\""
  let FAILED_TO_READ_RESULT = "Failed Reading process result"
  let UNKNOWN_ERROR_CODE = "Unknown error code %@ for \"%@\""
  let ABORTED_MESSAGE = "Cutting was cancelled for movie \"%@\""
  // messaged mirrored from mcut.cpp source code
  var global_mcut_errors = ["The movie \"%@\" is successfully cut",
                            ("Cutting failed for movie \"%@\"")+":\n"+("Bad arguments"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .ts file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .cuts file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .ap file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .ts file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .cuts file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .ap file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Empty .ap file"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("No cuts specified"),
                            ("Cutting failed for movie \"%@\"")+":\n"+("Read/write error (disk full?)")
  ]
  
  
  // designated initializer
  init(movieToBeCutPath : String, sysConfig: systemConfiguration, pvrIndex: Int, isRemote: Bool, onCompletion: @escaping MovieCutCompletionBlock, onStart: @escaping MovieCutStartBlock)
  {
    self.moviePath = movieToBeCutPath
    // call back closures
    self.onCompletion = onCompletion
    self.onStart = onStart
    // global refs
    self.sysConfig = sysConfig
    self.pvrIndex = pvrIndex
    self.isRemote = isRemote
    
    super.init()
    name = movieToBeCutPath
    global_mcut_errors.append(ABORTED_MESSAGE)
    global_mcut_errors.append(FAILED_TO_READ_RESULT)
    global_mcut_errors.append(FAILED_TO_NORMALIZE_MESSAGE)
    global_mcut_errors.append(UNKNOWN_ERROR_CODE)

  }
  
  /// Intercept the Operation  cancel function to update logs and queue tables
  
  override func cancel() {
    // our main executes a remote job that has no means of being stopped once started.
    // Our main only checks for isCancelled status once on startup
    let shouldLogCancelled = !self.isCancelled && !self.isExecuting
    super.cancel()
    // prevent double logging with before and after check
    if (self.isCancelled && shouldLogCancelled) {
      let cutResultStatusValue: Int = global_mcut_errors.firstIndex(of: ABORTED_MESSAGE)! // aborted
      let shortTitle = Recording.programDateTitleFrom(movieURLPath: moviePath)
      resultMessage = String(format: global_mcut_errors[cutResultStatusValue], shortTitle)
      DispatchQueue.main.async {
        self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
      }
    }
  }
  
  override func main() {
    var cutResultStatusValue: Int = global_mcut_errors.firstIndex(of: ABORTED_MESSAGE)! // aborted
    
    // have we been cancelled ?
    let shortTitle = Recording.programDateTitleFrom(movieURLPath: moviePath)
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
      cutResultStatusValue = global_mcut_errors.firstIndex(of: FAILED_TO_NORMALIZE_MESSAGE)!
      resultMessage = String(format: global_mcut_errors[Int(cutResultStatusValue)], targetPathName)
      DispatchQueue.main.async {
        self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
      }
      return
    }
    
    // MARK:  remote / detached task fabricated here
    let outPipe = Pipe()
    if let cutTask = buildCutTaskFrom(movieDiskPath: diskPathName, withArgs: sysConfig.mcutCommandArgs)
    {
      cutTask.standardOutput = outPipe
      let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
      if (debug) {print("\(timestamp) Launching for >\(shortTitle)<")}
      DispatchQueue.main.async { [weak weakSelf = self] in
        // callback that job has been started for name returned (update tooltip entry)
        weakSelf?.onStart(shortTitle)
      }
      
      cutTask.launch()
      let handle = outPipe.fileHandleForReading
      let data = handle.readDataToEndOfFile()
      cutTask.waitUntilExit()
      let result = cutTask.terminationStatus
      cutResultStatusValue = Int(result)
      if let resultString = String(data: data, encoding: String.Encoding.utf8) {
        if (debug) { print( resultString) }
        // bounds limit message lookup - remote program may change and introduce unknown result values
        
        let messageIndex = (cutResultStatusValue >= 0 && cutResultStatusValue < global_mcut_errors.count) ? cutResultStatusValue : global_mcut_errors.count-1
        resultMessage = String.init(format: global_mcut_errors[messageIndex], shortTitle)
        if (debug) { print(resultMessage) }
      }
    }
  
    // job done.  Delay in background process and then send results back to caller on the main queue
    // Delay found necessary due to finding garbage in the ap file after cutting is "Complete" guessed at
    // being due to remote host not having closed and flushed file to disk.
    usleep(1_000) // 1 sec delay allow remote caches to be flushed to disk - can end up re-accessing remote whilst dodgey
    DispatchQueue.main.async  { [weak weakSelf = self] in
      weakSelf?.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
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
    
    if (isRemote)
    {
      targetPathName = targetPathName.replacingOccurrences(of: sysConfig.pvrSettings[pvrIndex].cutLocalMountRoot, with: sysConfig.pvrSettings[pvrIndex].cutRemoteExport)
      mcutCommand = mcutConsts.mcutProgramRemote
      cutTask.launchPath = sysConfig.pvrSettings[pvrIndex].sshPath
    }
    else {  // local processing
      mcutCommand = mcutConsts.mcutProgramLocal
      cutTask.launchPath = mcutCommand
    }
    
    // build array of command arguments with required switches
    // array is collapsed to single string for remote or passed on as array of args to local command
    //      mcutCommandArgs = getCutsCommandLineArgs()
    mcutCommandArgs = withArgs
    if (isRemote) {
      mcutCommandArgs = mcutCommandArgs.map({$0.replacingOccurrences(of: " ", with: "\\ ")})
    }
    if (cutTask.launchPath == mcutConsts.mcutProgramLocal)
    {
      mcutCommandArgs.append("\(targetPathName)")
      cutTask.arguments = mcutCommandArgs
    }
    else {
      mcutCommandArgs.insert(mcutConsts.mcutProgramRemote, at: 0)
      // FIXME: check handling of apostrophe's in local directories
      targetPathName = targetPathName.replacingOccurrences(of: "&", with: "\\&")
      targetPathName = targetPathName.replacingOccurrences(of: "!", with: "\\!")
      targetPathName = targetPathName.replacingOccurrences(of: "'", with: "\\'")
      mcutCommandArgs.append(targetPathName.replacingOccurrences(of: " ", with: "\\ ") )
      cutTask.arguments = [sysConfig.pvrSettings[pvrIndex].remoteMachineAndLogin, mcutCommandArgs.joined(separator: " ")]
    }
    if (debug) {
      let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
      if (debug) {
        print("\(timestamp) Creating launch >\(cutTask.launchPath ?? "missing launchPath")<")
        print("with args:< \(cutTask.arguments ?? ["no args"])>")
      }
    }
    return cutTask
  }
}
