//
//  UserConfigDefinitions.swift
//  CutsEditor
//
//  Created by Alan Franklin on 12/11/16.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation
import Cocoa

/// lookup code for tags of GUI buttons

enum skipButtons:Int {
  case PLUS_A = 501
  case PLUS_B = 502
  case PLUS_C = 503
  case PLUS_D = 504
  case PLUS_E = 505
  case MINUS_A = -501
  case MINUS_B = -502
  case MINUS_C = -503
  case MINUS_D = -504
  case MINUS_E = -505
}

enum CheckMarkState: Int {
  case checked = 99
  case unchecked = 100
  
  static func lookup(_ raw : Int?) -> CheckMarkState
  {
    guard raw != nil else { return .unchecked }
    switch (raw!)
    {
    case checked.rawValue : return .checked
    case unchecked.rawValue : return .unchecked
    default : return .unchecked
    }
  }
}

/// Notification identifiers
let skipsDidChange = "CutsPreferenceControllerSkipsDidChange"
let sortDidChange = "SortPreferenceControllerSortDidChange"
let generalDidChange = "GeneralPreferencesControllerGeneralDidChange"
let playerDidChange = "PlayerPreferencesControllerDidChange"
let fileOpenDidChange = "FileToOpenFromMenuDidChange"
let jobQueueDidChange = "JobQueueDidChange"
let movieDidChange = "MovieDidChange"
let eitDidChange = "EITDidChange"

/// Pair of Strings touple of diskURL and the extracted recording program name
struct namePair {
  var diskURL: String = ""
  var programeName: String = ""
}

/// Configuration parameters for deciding colouring of
/// list of programs in the popup button

enum FileColourStates: String {
  case  allDoneColour = "allDoneColour"
  case  noBookmarksColour = "noBookmarksColour"
  case  readyToCutColour = "readyToCutColour"
  case partiallyReadyToCutColour = "partiallyReadyToCut"
}

struct fileColourParameters {
  static let BOOKMARK_THRESHOLD_COUNT = 3        // number of bookmarks that is considered as raw file
  static let PROGRAM_LENGTH_THRESHOLD = 900.0    // 15 minute or less programs do not need cutting
}

// TODO: enable user config to change colours to suit
/// default colour lookup table for pop list of filenames
let defaultColourLookup : [FileColourStates:NSColor] =
  [.allDoneColour:NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0),
   .noBookmarksColour:NSColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 1.0),
   .readyToCutColour:NSColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1.0),
   .partiallyReadyToCutColour:NSColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 0.7)
 ]

/// Lookup table for colours to use on filename popUp list
/// Utimately to be stored in user configuration and able to be reset to defaults
let colourLookup = defaultColourLookup

/// Dictionary that maps mark types to GUI button identifier strings
let marksDictionary = ["addBookmark":MARK_TYPE.BOOKMARK,"addInMark":MARK_TYPE.IN, "addOutMark":MARK_TYPE.OUT, "addLastPlay":MARK_TYPE.LASTPLAY]

/// Pair of String and Double for association with a GUI "skip" button.
/// The String is the text used on the button and the double is the skip
/// duration in seconds

struct skipPair {
  var display : String = ""
  var value : Double = 0.0
}

/// User configuration of sorting for popupbutton display
struct sortingPreferences {
  var isAscending: Bool = true
  var sortBy: String = ""
}

/// Mimics Cocoa
enum videoControlStyle : Int {
  case inLine, floating
}

/// User configuration of player controls
struct videoPlayerPreferences {
  var playbackControlStyle : videoControlStyle = .inLine
  var playbackShowFastForwardControls: Bool = true // iff style is floating
  var skipCutSections: Bool = true  // play through out/in pairs (alternate is to skip over)
}

/// User configuration enum for type of bulk entry
enum MARK_MODE: Int {
  case FIXED_COUNT_OF_MARKS
  case FIXED_SPACING_OF_MARKS
}

let kHyphen = " - "

/// User configuration general preferences
struct generalPreferences {
  var autoWrite = CheckMarkState.checked
  var markMode = MARK_MODE.FIXED_COUNT_OF_MARKS
  var countModeNumberOfMarks = 10         // 10 equally spaced bookmarks
  var spacingModeDurationOfMarks = 180    // 180 seconds spaced bookmarks
  // cuts application
  var systemConfig = systemConfiguration()
}


/// Property that contains the user preferences for /// the skip buttons.  Organized to mirror screen representation
/// of two columns (rhs/lhs) of 5 buttons
struct skipPreferences {
  var lhs = [skipPair]()
  var rhs = [skipPair]()
  
  /// Default initializer
  init() {
    lhs = [skipPair](repeating: skipPair(), count: 5)
    rhs = [skipPair](repeating: skipPair(), count: 5)
  }
  
  /// Initializer to set values from user preferences
  init(lhs:[skipPair], rhs:[skipPair])
  {
    self.lhs = lhs
    self.rhs = rhs
  }
}

/// Configuration of users system and path to sh and ssh
public struct systemConfiguration {
  var pvrSettings = [pvrPreferences(title:mcutConsts.fixedLocalName),pvrPreferences(title:"Beyonwiz T4"),pvrPreferences(title: "Beyonwiz T2")]
  
  /// args for the external "cutter" program
  var mcutCommandArgs = [String]()
}
