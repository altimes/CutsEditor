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
  var foundfiles = [String]()
  let moviePath : String
  var resultMessage = ""
  var targetPathName = ""
  var mcutCommand = ""
  var mcutSystem = ""
  let debug = false
  var sysConfig: systemConfiguration
  let onCompletion : MovieCutCompletionBlock
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
                            ("Cutting was aborted for movie \"%@\"")]
  
  
  // get the passed in starting directory
  init(movieToBeCutPath : String, sysConfig: systemConfiguration, onCompletion: @escaping MovieCutCompletionBlock)
  {
    self.moviePath = movieToBeCutPath
    self.onCompletion = onCompletion
    self.sysConfig = sysConfig
  }
  
  override func main() {
    var cutResultStatusValue: Int = 11 // aborted
    if (self.isCancelled) {
      //      print("was cancelled by user")
      DispatchQueue.main.async {
        //      print(self.foundfiles)
        self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
      }
    }
    
    //    print("invoked cutting")
    //    DispatchQueue.main.async {
    //      //      print(self.founfiles)
    //      self.parentDialog.statusField.stringValue = StringsCuts.STARTED_SEARCH
    //    }
    
    // MARK:  create task stuff here
    let cutTask = Process()
    let outPipe = Pipe()
    let basename = moviePath.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    if let fullPathName = basename.replacingOccurrences(of: "file://",
                                                        with: "").removingPercentEncoding {
      targetPathName = fullPathName
      // decide if we are doing this locally or remotely and setup commnad line accordingly
      if fullPathName.contains(mcutConsts.localMount) {
        targetPathName = fullPathName.replacingOccurrences(of: mcutConsts.localMount, with: mcutConsts.remoteExportPath)
        mcutCommand = mcutConsts.mcutProgramRemote
        cutTask.launchPath = sysConfig.sshPath
      }
      else {  // local processing
        mcutCommand = mcutConsts.mcutProgramLocal
        cutTask.launchPath = mcutCommand
      }
      // build array of command arguments with required switches
      // array is collapsed to single string for remote or passed on as array of args to local command
      //      var mcutCommandArgs = parentDialog.getCutsCommandLineArgs()
      //      mcutCommandArgs = mcutCommandArgs.map({$0.replacingOccurrences(of: " ", with: "\\ ")})
      //      if (cutTask.launchPath == mcutConsts.mcutProgramLocal)
      //      {
      //        mcutCommandArgs.append("\(targetPathName)")
      //        cutTask.arguments = mcutCommandArgs
      //        mcutSystem = "locally"
      //      }
      //      else {
      //        mcutCommandArgs.insert(mcutConsts.mcutProgramRemote, at: 0)
      //        mcutCommandArgs.append(targetPathName.replacingOccurrences(of: " ", with: "\\ ") )
      //        cutTask.arguments = [mcutConsts.remoteLogin, mcutCommandArgs.joined(separator: " ")]
      //        mcutSystem = "remotely"
      //      }
      if (true) {
        print("Sending lauch >\(cutTask.launchPath)<")
        print("with args:< \(cutTask.arguments)>")
      }
      //      let messageString = String(format: mcutConsts.pleaseWaitMessage , parentDialog.currentFile.selectedItem!.title, mcutSystem)
      //      print(messageString)
      //      parentDialog.statusField.stringValue = messageString
      cutTask.standardOutput = outPipe
      cutTask.launch()
      let handle = outPipe.fileHandleForReading
      // FIXME: figure out how to force GUI update BEFORE this blocks main queue
      let data = handle.readDataToEndOfFile()
      //      cutTask.waitUntilExit()
      let result = cutTask.terminationStatus
      cutResultStatusValue = Int(result)
      if let resultString = String(data: data, encoding: String.Encoding.utf8) {
        print( resultString)
        print("got result of \(result)")
        let programName = targetPathName.components(separatedBy: "/").last
        resultMessage = String.init(format: global_mcut_errors[Int(result)], programName!)
        print(resultMessage)
        // TODO: add code to to handle "new output file case"
        //        parentDialog.setDropDownColourForIndex(filelistIndex)
        //        parentDialog.changeFile(filelistIndex)
        //        self.statusField.title = message
      }
    }
    else {
      resultMessage = "Failed converting to native pathname"
    }
    
    // job done.  Send results back to caller
    DispatchQueue.main.async {
      //      print(self.foundfiles)
      self.onCompletion(self.resultMessage, cutResultStatusValue, self.isCancelled)
    }
  }
  
}

