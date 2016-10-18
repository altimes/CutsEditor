//
//  MovieCutting.swift
//  CutsEditor
//
//  Created by Alan Franklin on 4/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//


import Foundation
/// Class to encapsulate functions involved in setting up and executing
/// cutting of the recording

class  MovieCutting
{
//  var systemSetup: systemConfiguration
//  var generalPrefs: generalPreferences
//  
//  // inject elements of current environment for reference
//  init(systemConfig: systemConfiguration,
//       genPrefs: generalPreferences
//    ) {
//    systemSetup = systemConfig
//    generalPrefs = genPrefs
//  }
//  
//  /// Extract the short movie title from the file path
//  open static func programTitleFrom(movieURLPath: String) -> String
//  {
//    let fileNameSeperator = "-"
//    var programName = "Undetermined"
//    let basename = movieURLPath.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
//    if let fullPathName = basename.replacingOccurrences(of: "file://",
//                                                        with: "").removingPercentEncoding {
//      if let title = fullPathName.components(separatedBy: "/").last {
//        programName = title
//        let fileElements = programName.components(separatedBy: fileNameSeperator)
//        if fileElements.count >= 3 // typically expect "date - channel - program name"
//        {
//          programName = fileElements[2 ..< fileElements.count].joined(separator: fileNameSeperator)
//          programName = programName.trimmingCharacters(in: CharacterSet(charactersIn: " "))
//        }
//      }
//    }
//    return programName
//  }
//
//  /// Extract the short movie title from the file path
//  open static func programDateTitleFrom(movieURLPath: String) -> String
//  {
//    let fileNameSeperator = "-"
//    var programName = "Undetermined"
//    let basename = movieURLPath.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
//    if let fullPathName = basename.replacingOccurrences(of: "file://",
//                                                        with: "").removingPercentEncoding {
//      if let title = fullPathName.components(separatedBy: "/").last {
//        programName = title
//        let fileElements = programName.components(separatedBy: fileNameSeperator)
//        if fileElements.count >= 3 // typically expect "date - channel - program name"
//        {
//          programName = fileElements[0]+fileNameSeperator
//          programName += fileElements[2 ..< fileElements.count].joined(separator: fileNameSeperator)
//          programName = programName.trimmingCharacters(in: CharacterSet(charactersIn: " "))
//        }
//      
//      }
//    }
//    return programName
//  }
//  
//  /// Build and executes an external process to executes movie cuts
//  func movieCutOne(moviePath: String, commandArgs: [String]) -> (result: Int, message:String, newFile: String?)
//  {
//    var resultMessage: String
//    var processResult: Int = 0
//    let FAILED_TO_NORMALIZE_MESSAGE = "Failed to normalize movie path name<\"%@\">"
//    let FAILED_TO_READ_RESULT = "Failed Reading process result"
//    let global_mcut_errors = ["The movie \"%@\" is successfully cut",
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Bad arguments"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .ts file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .cuts file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open input .ap file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .ts file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .cuts file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Couldn't open output .ap file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Empty .ap file"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("No cuts specified"),
//                              ("Cutting failed for movie \"%@\"")+":\n"+("Read/write error (disk full?)"),
//                              ("Cutting was aborted for movie \"%@\""),
//                              (FAILED_TO_READ_RESULT),
//                              (FAILED_TO_NORMALIZE_MESSAGE)]
//    
//    // spawn process to perfrom cut
//    // FIXME: mark entry as locked in some way until process completed
//    // Usage: mcut [-r] [-o output_ts_file] [-n title] [-d description] ts_file [-c start1 end1 [start2 end2] ... ]
//    let outPipe = Pipe()
//    if let cutTask = buildCutTaskFrom(movieURLPath: moviePath, withArgs: commandArgs) {
//      cutTask.standardOutput = outPipe
//      cutTask.launch()
//      let handle = outPipe.fileHandleForReading
//      // FIXME: figure out how to force GUI update BEFORE this blocks main queue
//      let data = handle.readDataToEndOfFile()
//      cutTask.waitUntilExit()
//      processResult = Int(cutTask.terminationStatus)
//      if let resultString = String(data: data, encoding: String.Encoding.utf8) {
//        print( resultString)
//        print("got result of \(processResult)")
//        resultMessage = String.init(format: global_mcut_errors[processResult], MovieCutting.programTitleFrom(movieURLPath: moviePath))
//        print(resultMessage)
//        // TODO: add code to to handle "new output file case"
//      }
//      else {
//        processResult = global_mcut_errors.index(of: FAILED_TO_READ_RESULT)!
//        resultMessage = String.init(format: global_mcut_errors[processResult])
//      }
//    }
//    else {
//      processResult = global_mcut_errors.index(of: FAILED_TO_NORMALIZE_MESSAGE)!
//      resultMessage = String.init(format: global_mcut_errors[processResult], moviePath)
//    }
//    var newOutputFilename = ""
//    if let indexOfOutputSwitch = systemSetup.instanceArgs.index(of: mcutConsts.outputSwitch) {
//      newOutputFilename = systemSetup.instanceArgs[indexOfOutputSwitch+1]
//    }
//    return (processResult, resultMessage, newOutputFilename)
//  }
//  /// Populate the task with app and args appropriate to local or remote
//  /// execution of cut process
//  
//  func buildCutTaskFrom(movieURLPath: String, withArgs: [String]) -> Process?
//  {
//    var targetPathName: String
//    var mcutCommand: String
//    var mcutCommandArgs: [String]
//    
//    let cutTask = Process()
//    let basename = movieURLPath.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
//    if let fullPathName = basename.replacingOccurrences(of: "file://",
//                                                        with: "").removingPercentEncoding {
//      targetPathName = fullPathName
//      
//      // decide if we are doing this locally or remotely and setup commnad line accordingly
//      if (MovieCutting.isRemote(pathName: targetPathName)) {
//        targetPathName = fullPathName.replacingOccurrences(of: mcutConsts.localMount, with: mcutConsts.remoteExportPath)
//        mcutCommand = mcutConsts.mcutProgramRemote
//        cutTask.launchPath = systemSetup.sshPath
//      }
//      else {  // local processing
//        mcutCommand = mcutConsts.mcutProgramLocal
//        cutTask.launchPath = mcutCommand
//      }
//      
//      // build array of command arguments with required switches
//      // array is collapsed to single string for remote or passed on as array of args to local command
////      mcutCommandArgs = getCutsCommandLineArgs()
//      mcutCommandArgs = withArgs
//      mcutCommandArgs = mcutCommandArgs.map({$0.replacingOccurrences(of: " ", with: "\\ ")})
//      if (cutTask.launchPath == mcutConsts.mcutProgramLocal)
//      {
//        mcutCommandArgs.append("\(targetPathName)")
//        cutTask.arguments = mcutCommandArgs
//      }
//      else {
//        mcutCommandArgs.insert(mcutConsts.mcutProgramRemote, at: 0)
//        // FIXME: check handling of apostrophe's in local directories
//        targetPathName = targetPathName.replacingOccurrences(of: "'", with: "\\'")
//        mcutCommandArgs.append(targetPathName.replacingOccurrences(of: " ", with: "\\ ") )
//        cutTask.arguments = [systemSetup.remoteManchineAndLogin, mcutCommandArgs.joined(separator: " ")]
//      }
//      if (true) {
//        print("Sending lauch >\(cutTask.launchPath)<")
//        print("with args:< \(cutTask.arguments)>")
//      }
//      return cutTask
//    }
//    return nil
//  }
//  
//  /// Return is pathname contains a remote mount point.
//  /// That is, guess if we are looking a a local or a remote file
//  /// where remote means on the PVR.  This get bamboozled with networked
//  /// drives.  For now we cut local files locally and assume remote files
//  /// are on a machine that has mcut
//  open static func isRemote(pathName: String) -> Bool
//  {
//    return  (pathName.contains(mcutConsts.localMount)) ? true : false
//  }
}

