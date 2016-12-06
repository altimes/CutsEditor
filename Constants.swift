//
//  Constants.swift
//  CutsEditor
//
//  Created by Alan Franklin on 12/11/16.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation

struct StringsCuts {
  static let WORKING = "Working getting file list"
  static let NO_DIRECTORY_SELECTED = "No directory Selected"
  static let DIRECTORY_SEPERATOR = "/"
  static let NO_FILE_CHOOSEN = "No file selected"
  static let SELECT_DIRECTORY = "Select Directory"
  static let CANCEL_SEARCH = "Cancel Search"
  static let NO_PROGRAMS_FOUND = "No programs found at location"
  static let TABLE_TIME_COLUMN = "Time"
  static let TABLE_TYPE_COLUMN = "Type"
  static let FILE_SAVE_FAILED = "Failed to save file"
  static let STARTED_SEARCH = "Started Search"
  static let CANCELLED_BY_USER = "Cancelled by User"
  static let DERIVING_PROGRAM_STATUS = "Determining Program State"
  static let COLOUR_CODING_CANCELLED = "Colour Coding Cancelled"
  static let FAILED_TRYING_TO_ACCESS = "Failed trying to access %@"
  static let FAILED_COUNTING_FILES = "Failed counting files expected number, got\n<%@>"
}

/// Engima file extensions and sundry constants
struct ConstsCuts {
  static let filelistSize = 200  // starting size for list of files
  static let titleWordsPick = 6  // abitrary number of words to pick from description if episode title is too long
  static let maxTitleLength = 50 // episode title longer that this is probably not a title, but a description
  static let CUTS_SUFFIX = ".ts.cuts"
  static let META_SUFFIX = ".ts.meta"
  static let EIT_SUFFIX = ".eit"
  static let TS_SUFFIX = ".ts"
  static let AP_SUFFIX = ".ts.ap"
  static let SC_SUFFIX = ".ts.sc"
}

/// Control which file to process "selected" or just worked on
enum FileToHandle {
  case current, previous
}

/// strings for configuring the remote call to the mcut programs
public struct mcutConsts {
  static let replaceSwitch = "-r"
  static let outputSwitch = "-o"
  static let nameSwitch = "-n"
  static let descriptionSwitch = "-d"
  static let cutsSwitch = "-c"
  static let localMount = "/Volumes/Harddisk"
  static let remoteExportPath = "/media/hdd"
  static let mcutProgramRemote = "/usr/lib/enigma2/python/Plugins/Extensions/MovieCut/bin/mcut"
  static let mcutProgramLocal = "/usr/local/bin/mcut2"
  
  static let pleaseWaitMessage = "Cutting <%@> %@ please wait..."
  static let started = "Started"
  static let waiting = "Waiting"
  static let cutOK = "Cut OK"
  static let cutFailed = "Cut Failed"
  
  static let  remoteMachineAndLogin = "root@beyonwizt4.local"
  static let sshPath = "/usr/bin/ssh"
  static let shPath = "/bin/sh"
  
  static let fixedLocalName = "Local"
}

typealias PtsType = UInt64
typealias OffType = UInt64
typealias OffPts = (offset: OffType, pts: PtsType)
