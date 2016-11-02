//
//  ViewController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 2/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa
import AVFoundation
import AVKit


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
  static let CUTS_SUFFIX = ".ts.cuts"
  static let META_SUFFIX = ".ts.meta"
  static let EIT_SUFFIX = ".eit"
  static let TS_SUFFIX = ".ts"
  static let AP_SUFFIX = ".ts.ap"
}

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

/// Notification identifiers
let skipsDidChange = "CutsPreferenceControllerSkipsDidChange"
let sortDidChange = "SortPreferenceControllerSortDidChange"
let generalDidChange = "GeneralPreferencesControllerGeneralDidChange"
let playerDidChange = "PlayerPreferencesControllerDidChange"
let fileOpenDidChange = "FileToOpenFromMenuDidChange"
let jobQueueDidChange = "JobQueueDidChange"

/// Pair of Strings touple of diskURL and the extracted recording program name
struct namePair {
  var diskURL: String = ""
  var programeName: String = ""
}

/// Configuration parameters for deciding colouring of
/// list of programs in the popup button
struct fileColourParameters {
  static let BOOKMARK_THRESHOLD_COUNT = 3        // number of bookmarks that is considered as raw file
  static let PROGRAM_LENGTH_THRESHOLD = 900.0    // 15 minute or less programs do not need cutting
  static let allDoneColor = NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
  static let noBookmarksColor = NSColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 1.0)
  static let readyToCutColor = NSColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1.0)
}

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

/// per pvr preferences
public struct pvrPreferences {
  var title = "Beyonwiz Tx"
  var cutReplace = CheckMarkState.checked
  var cutRenamePrograme = CheckMarkState.unchecked
  var cutOutputFile = CheckMarkState.unchecked
  var cutDescription = CheckMarkState.unchecked
  
  var cutProgramLocalPath = mcutConsts.mcutProgramLocal
  var cutProgramRemotePath = mcutConsts.mcutProgramRemote
  var cutLocalMountRoot = mcutConsts.localMount
  var cutRemoteExport = mcutConsts.remoteExportPath
  var remoteMachineAndLogin = mcutConsts.remoteMachineAndLogin
  var sshPath = mcutConsts.sshPath
  var shPath = mcutConsts.shPath
}

// based on http://stackoverflow.com/questions/38406457/how-to-save-an-array-of-custom-struct-to-nsuserdefault-with-swift
extension pvrPreferences {
  init(title: String) {
    self.title = title
  }
  
  init?(data: NSData)
  {
    if let coding = NSKeyedUnarchiver.unarchiveObject(with: data as Data) as? Encoding
    {
      title = coding.title as String
      cutReplace = CheckMarkState(rawValue: coding.cutReplace)!
      cutRenamePrograme = CheckMarkState(rawValue: coding.cutRenamePrograme)!
      cutOutputFile = CheckMarkState(rawValue: coding.cutOutputFile)!
      cutDescription = CheckMarkState(rawValue: coding.cutDescription)!
      cutProgramLocalPath = coding.cutProgramLocalPath as String
      cutProgramRemotePath = coding.cutProgramRemotePath as String
      cutLocalMountRoot = coding.cutLocalMountRoot as String
      cutRemoteExport = coding.cutRemoteExport as String
      remoteMachineAndLogin = coding.remoteMachineAndLogin as String
      sshPath = coding.sshPath as String
      shPath = coding.shPath as String
    } else {
        return nil
    }
  }

    func encode() -> NSData {
        return NSKeyedArchiver.archivedData(withRootObject: Encoding(self)) as NSData
    }
  
    private class Encoding: NSObject, NSCoding
    {
      let title : String
        let cutReplace : Int
        let cutRenamePrograme : Int
        let cutOutputFile : Int
        let cutDescription : Int
        let cutProgramLocalPath : String
        let cutProgramRemotePath : String
        let cutLocalMountRoot : String
        let cutRemoteExport : String
        let remoteMachineAndLogin : String
        let sshPath : String
        let shPath : String

        init(_ pvr: pvrPreferences) {
          title = pvr.title
          cutReplace = pvr.cutReplace.rawValue
          cutRenamePrograme = pvr.cutRenamePrograme.rawValue
          cutOutputFile = pvr.cutOutputFile.rawValue
          cutDescription = pvr.cutDescription.rawValue
          cutProgramLocalPath = pvr.cutProgramLocalPath
          cutProgramRemotePath = pvr.cutProgramRemotePath
          cutLocalMountRoot = pvr.cutLocalMountRoot
          cutRemoteExport = pvr.cutRemoteExport
          remoteMachineAndLogin = pvr.remoteMachineAndLogin
          sshPath = pvr.sshPath
          shPath = pvr.shPath
        }

        @objc required init?(coder aDecoder: NSCoder) {
          guard aDecoder.containsValue(forKey: "cutReplace") else {
            return nil
          }
          title = aDecoder.decodeObject(forKey: "title") as! String
          cutReplace = aDecoder.decodeInteger(forKey: "cutReplace")
          cutRenamePrograme = aDecoder.decodeInteger(forKey: "cutRenamePrograme")
          cutOutputFile = aDecoder.decodeInteger(forKey: "cutOutputFile")
          cutDescription = aDecoder.decodeInteger(forKey: "cutDescription")
          cutProgramLocalPath = aDecoder.decodeObject(forKey: "cutProgramLocalPath") as! String
          cutProgramRemotePath = aDecoder.decodeObject(forKey: "cutProgramRemotePath") as! String
          cutLocalMountRoot = aDecoder.decodeObject(forKey: "cutLocalMountRoot") as! String
          cutRemoteExport = aDecoder.decodeObject(forKey: "cutRemoteExport") as! String
          remoteMachineAndLogin = aDecoder.decodeObject(forKey: "remoteMachineAndLogin") as! String
          sshPath = aDecoder.decodeObject(forKey: "sshPath") as! String
          shPath = aDecoder.decodeObject(forKey: "shPath") as! String
        }

      @objc func encode(with aCoder: NSCoder) {
        aCoder.encode(title, forKey: "title")
        aCoder.encode(cutReplace, forKey: "cutReplace")
        aCoder.encode(cutRenamePrograme, forKey: "cutRenamePrograme")
        aCoder.encode(cutOutputFile, forKey: "cutOutputFile")
        aCoder.encode(cutDescription, forKey: "cutDescription")
        aCoder.encode(cutProgramLocalPath, forKey: "cutProgramLocalPath")
        aCoder.encode(cutProgramRemotePath, forKey: "cutProgramRemotePath")
        aCoder.encode(cutLocalMountRoot, forKey: "cutLocalMountRoot")
        aCoder.encode(cutRemoteExport, forKey: "cutRemoteExport")
        aCoder.encode(remoteMachineAndLogin, forKey: "remoteMachineAndLogin")
        aCoder.encode(sshPath, forKey: "sshPath")
        aCoder.encode(shPath, forKey: "shPath")
        }
    }
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
/// FIXME: add to preferences panel
public struct systemConfiguration {
  var pvrSettings = [pvrPreferences(title:mcutConsts.fixedLocalName),pvrPreferences(title:"Beyonwiz T4"),pvrPreferences(title: "Beyonwiz T2")]
  
  /// args for the external "cutter" program
  var mcutCommandArgs = [String]()
}

typealias FindCompletionBlock = ( _ URLArray:[String]?,  _ forSuffix: String,  _ didCompleteOK:Bool) -> ()
typealias MovieCutCompletionBlock  = (_ message: String, _ resultValue: Int, _ wasCancelled: Bool) -> ()
typealias MovieCutStartBlock  = (_ shortTitle: String) -> ()

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource
{
//  class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSUserInterfaceValidations {
  
  @IBOutlet weak var previousButton: NSButton!
  @IBOutlet weak var nextButton: NSButton!
  @IBOutlet weak var selectDirectory: NSButton!
  @IBOutlet weak var monitorView: AVPlayerView!
  @IBOutlet weak var programTitle: NSTextField!
  @IBOutlet weak var epsiodeTitle: NSTextField!
  @IBOutlet var programDescription: NSTextView!
  @IBOutlet weak var cutsTable: NSTableView!
  @IBOutlet var programDuration: NSTextField!
  @IBOutlet weak var currentFile: NSPopUpButton!
  @IBOutlet weak var statusField: NSTextFieldCell!
  
  // possibly better done as button array
  
  @IBOutlet weak var seekButton1a: NSButton!
  @IBOutlet weak var seekButton1b: NSButton!
  @IBOutlet weak var seekButton1c: NSButton!
  @IBOutlet weak var seekButton1d: NSButton!
  @IBOutlet weak var seekButton1e: NSButton!
  @IBOutlet weak var seekButton2a: NSButton!
  @IBOutlet weak var seekButton2b: NSButton!
  @IBOutlet weak var seekButton2c: NSButton!
  @IBOutlet weak var seekButton2d: NSButton!
  @IBOutlet weak var seekButton2e: NSButton!
  @IBOutlet weak var inButton: NSButton!
  @IBOutlet weak var outButton: NSButton!
//  @IBOutlet weak var markButton: NSButton!
  @IBOutlet weak var cutButton: NSButton!
  @IBOutlet weak var tenMarkButton: NSButton!
  
  @IBOutlet weak var progressBar: NSProgressIndicator!
  
  // MARK: model
  
  var movie = Recording()
  let debug = false
  var startDate = Date()
  var fileSearchCancelled = false
  var filelist: [String] = []
  var namelist: [String] = []
  var filelistIndex : Int {
    set {
      // bounds check before trying to change selection
      if (filelist.count > 0 && newValue >= 0 && newValue < filelist.count) {
        setStatusFieldToCurrentSelection()
        currentFile.selectItem(at: filelistIndex)
      }
    }
    get {
      return self.currentFile.indexOfSelectedItem
    }
  }
  
//  /// list of files in the cutting queue.
//  /// Moved from the presented list into this array when added to the cutting queue
//  /// moved from here into the presented list when cutting completes
//  var cuttingList : [String] = []
//  
  /// flag if cuts list is coherent, enable CUT button if it is
  var cuttable : Bool {
    set {
      cutButton.isEnabled = newValue
    }
    get {
      return movie.cuts.isCuttable
    }
  }
  
  /// Index into the GUI popup captured during the last MouseDownEvent
  var mouseDownPopUpIndex : Int?
  
  /// Current PVR being used for source and for cutting
  var pvrIndex = 0
  var isRemote = false
  
  var lastfileIndex : Int = 0
  var fileWorkingName : String = ""
  var videoDurationFromPlayer: Double = 0.0
  var programDurationInSecs: Double = 0.0
  /// Flag for completion handler to resume playing after seek
  var wasPlaying: Bool = false
  /// Computed var checks if video was playing
  var isPlaying: Bool {
    get {
      if (self.monitorView.player != nil) {
        return (self.monitorView.player!.rate > 0.0)
      }
      else {
        return false
      }
    }
  }
  
  /// readonly computed var of postion of first IN cutmark in PTS units. If no IN is present
  /// then return 0 for begining of video
  var firstInCutPTS:UInt64 {
    get {
      var pts : UInt64 = 0
      if let entry = movie.cuts.firstInCutMark
      {
        pts = entry.cutPts
      }
      return pts
    }
  }
  
  /// Readonly computed var of the position of the last OUT pts.  If no OUT is present,
  /// or it is followed by and IN
  /// then return the max of the metadata duration (which for some broadcasters
  /// can be 0 (!)) and the video duration determined by the AVPlayer
  
  var lastOutCutPTS: UInt64 {
    get {
      var pts : UInt64
      let metaPTS : UInt64 = UInt64( metadata.duration) ?? UInt64(0)
      // FIXME: check if first PTS is always 0??
      let videoPTS : UInt64 = UInt64( videoDurationFromPlayer * Double(CutsTimeConst.PTS_TIMESCALE))
      
      if (metaPTS == UInt64(0)) {
        pts = videoPTS
      }
      else {
        pts = min(metaPTS, videoPTS)
      }
      //
      // get in/out pairs only
      let inOut = movie.cuts.inOutOnly
      if let entry = inOut.last
      {
        if entry.cutType == MARK_TYPE.OUT.rawValue {
          pts = entry.cutPts
        }
      }
      return pts
    }
  }
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  
  var finderOperationsQueue : OperationQueue?
  var localCutterOperationsQueue = CuttingQueue.localQueue()
  var systemSetup = systemConfiguration()

  var currentFileColouringBlock : BlockOperation?
//  var cuts = CutsFile()
  var cutsModified : Bool {
    get {
      return movie.cuts.isModified
    }
  }
  var eit = EITInfo()
  var metadata = MetaData()
  var accessPointData : AccessPoints?
  
  var skips = skipPreferences()
  var sortPrefs = sortingPreferences()
  var generalPrefs = generalPreferences()
  var playerPrefs = videoPlayerPreferences()
  
  /// Controls if avPlayer is dynamically synced to current cut position selection.
  /// This should action should be suppressed during bulk operations.  If not, then
  /// the player will attempt to seek to a new frame each time the table highlight
  /// is changed.  For example, when the user adds 10 bookmarks, the player jumps
  /// to each new bookmark as if the user has just selected it in the table.
  var suppressPlayerUpdate = false
  
  
  /// value to track periodic callbacks in player and suppress execution of multiples at the same time
  var lastPeriodicCallBackTime : Float = -1.0
  
  /// ensure that user selecting a row is not overriden with timed observed updates
  var suppressTimedUpdates = false
  
  /// flag to control if out/in block skipping is honoured
  var honourOutInMarks = true
  
  /// var used to maintain ordered list of movie cuttting jobs added to the cutting queue.
  /// Used as a lightweight queue monitor.  Displayed as "tooltip" on Cut button
  
  var cuttingInQueue = ""
  
//  var cutterQueues = [OperationQueue]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
//    UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
//    UserDefaults.standard.synchronize()
    
    previousButton.isEnabled = false
    nextButton.isEnabled = false
    fileWorkingName = StringsCuts.NO_FILE_CHOOSEN
    statusField.stringValue = StringsCuts.NO_DIRECTORY_SELECTED
    currentFile.removeAllItems()
    currentFile.addItem(withTitle: StringsCuts.NO_FILE_CHOOSEN)
    currentFile.selectItem(at: 0)
    cutsTable.dataSource = self
    cutsTable.delegate = self
    actionsSetEnabled(false)
    
    skips = preferences.skipPreference()
    sortPrefs = preferences.sortPreference()
    generalPrefs = preferences.generalPreference()
    systemSetup = generalPrefs.systemConfig
    playerPrefs = preferences.videoPlayerPreference()
    
    NotificationCenter.default.addObserver(self, selector: #selector(skipsChange(_:)), name: NSNotification.Name(rawValue: skipsDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(sortChange(_:)), name: NSNotification.Name(rawValue: sortDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(generalChange(_:)), name: NSNotification.Name(rawValue: generalDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(playerChange(_:)), name: NSNotification.Name(rawValue: playerDidChange), object: nil )
    
    NotificationCenter.default.addObserver(self, selector: #selector(fileToOpenChange(_:)), name: NSNotification.Name(rawValue: fileOpenDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(fileSelectPopUpChange(_:)), name: NSNotification.Name.NSPopUpButtonWillPopUp, object: nil )
    
    self.progressBar.controlTint = NSControlTint.clearControlTint
    self.view.window?.title = "CutListEditor"
    
//    reconstructScAp.do_movie("/Users/alanf/Movies/20160324 1850 - ABC - Clarke And Dawe.ts")
//    reconstructScAp.readFFMeta("/Users/alanf/Movies/20160324 1850 - ABC - Clarke And Dawe.ts.ap")
//    reconstructScAp.pyProcessScAp("/Users/alanf/Movies/20160324 1850 - ABC - Clarke And Dawe.ts")
  }
  
  override func viewDidDisappear() {
        super.viewDidDisappear()
    
        if let token = timeObserverToken {
          self.monitorView.player?.removeTimeObserver(token)
          self.timeObserverToken = nil
        }
        self.monitorView.player?.pause()
  }
  
  
  override func viewWillDisappear() {
    super.viewWillDisappear()
    NotificationCenter.default.removeObserver(self)
  }
  
  /// Observer function to handle the "seek" changes that are made
  /// during changes in the preferences dialog
  func skipsChange(_ notification: Notification)
  {
    // get the changed skip setting and update the gui to match
    self.skips = preferences.skipPreference()
    skipButtonGUISetup(self.skips)
  }

  /// Performance function.  Retrieve the attributed strings
  /// from the currentFile NSPopUpButton and return for later
  /// re-use.  Working out the attributes is very costly and
  /// should only be done when the entire list contents is changed
  /// - parameter popUpList: the button involved
  /// - returns: array of attributed program titles
  
  func retainAttributedStringList(_ popUpList: NSPopUpButton) -> ([String],[NSMenuItem])
  {
    // Fiddly bit here.
    // To avoid recreating the popupbutton attributed strings (costly to decide on colouring)
    // We save the old one, create a parallel array of titles
    // then for the newly sorted namelist, we pick out
    // the title, look up the old index from the simple string array
    // then use that index to get the old attributed string to associate
    // with the reconstructed nspopbutton
    
    // check that colouring is complete
    if (currentFileColouringBlock != nil) {
      if currentFileColouringBlock!.isExecuting {
        currentFileColouringBlock!.waitUntilFinished()  // yes, this will block on the main queue
      }
    }
    
    let menuItemArray = popUpList.itemArray
    var itemTitles = [String]()
    for item in menuItemArray {
      itemTitles.append(item.title)
    }
    return (itemTitles, menuItemArray)
  }
 
  /// Restore the saved attributed strings to the popUpButton
  
  func restoreAttributedStringList(_ popUp: NSPopUpButton, itemTitles: [String], menuItems:[NSMenuItem])
  {
    for newIndex in 0 ..< self.namelist.count
    {
      let title = namelist[newIndex]
      if let oldIndex = itemTitles.index(of: title)
      {
        self.currentFile.item(at: newIndex)?.attributedTitle = menuItems[oldIndex].attributedTitle
        self.currentFile.item(at: newIndex)?.toolTip = menuItems[oldIndex].toolTip
      }
    }
  }
  
  /// Observer function to handle the "sort order" changes that are made
  /// during changes in the preferences dialog
  
  func sortChange(_ notification: Notification)
  {
    // get the changed skip setting and update the gui to match
    self.sortPrefs = preferences.sortPreference()
    // now update the GUI
    if (filelist.count > 0) {
      // save current item
      let savedCurrentDiskURL = filelist[filelistIndex]
      let savedLastDiskURL = filelist[lastfileIndex]
      
      sortNames()
      lastfileIndex = filelist.index(of: savedLastDiskURL)!
      
      let (itemTitles, itemArray) = retainAttributedStringList(self.currentFile)
      self.currentFile.removeAllItems()
      self.currentFile.addItems(withTitles: namelist)
      restoreAttributedStringList(currentFile, itemTitles: itemTitles, menuItems: itemArray)

      // reselect the current program in the resorted list
      currentFile.selectItem(at: filelist.index(of: savedCurrentDiskURL)!)
      mouseDownPopUpIndex = nil
      setPrevNextButtonState(filelistIndex)
      changeFile(filelistIndex)
    }
  }
  
  /// Observer function to handle the "General Preferences" changes that are made
  /// and saved during changes in the preferences dialog
  
  func generalChange(_ notification: Notification)
  {
    // get the changed general settings and update the gui to match
    self.generalPrefs = preferences.generalPreference()
    self.systemSetup = self.generalPrefs.systemConfig
  }
  
  /// Observer function to handle the "Player Config Preferences" changes that are made
  /// and saved during changes in the preferences dialog
  
  func playerChange(_ notification: Notification)
  {
    // get the changed general settings and update the gui to match
    self.playerPrefs = preferences.videoPlayerPreference()
    self.monitorView.controlsStyle = playerPrefs.playbackControlStyle == videoControlStyle.inLine ? AVPlayerViewControlsStyle.inline : AVPlayerViewControlsStyle.floating
    self.monitorView.showsFrameSteppingButtons = !playerPrefs.playbackShowFastForwardControls
    self.honourOutInMarks = playerPrefs.skipCutSections
  }
  
  /// Observer function that responds to the selection of
  /// a single file (rather than a directory) to be used.
  /// Notitication has filename is the notification "object"
  func fileToOpenChange(_ notification: Notification)
  {
    let filename = notification.object as! String
    if (!appendSingleFileToListAndSelect(filename))
    {
      let message = String.localizedStringWithFormat( StringsCuts.FAILED_TRYING_TO_ACCESS, filename)
      self.statusField.stringValue = message
    }
  }
  
  /// Query the PVR (or directory) for a recursive count of the files with xxx extension.
  /// Written to do a external shell query and then process the resulting message
  /// eg. countFilesWithSuffix(".ts", "/hdd/media/movie")
  /// Used to support sizing of progress bar for background tasks.
  /// If remote query fails for any reason, function returns default value of 100
  /// - parameter fileSuffix: tail of file name, eg .ts, .ts.cuts, etc
  /// - parameter belowPath: root of path to recursively search
  
  func countFilesWithSuffix(_ fileSuffix: String, belowPath: String) -> Int?
  {
    let defaultCount: Int? = nil
    var searchPath: String
    // use a task to get a count of the files in the directory
    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
    // CLI specifics are for BeyonWiz Enigma2 BusyBox 4.4
    let fileCountTask = Process()
    let outPipe = Pipe()
    let localMountRoot = isRemote ? generalPrefs.systemConfig.pvrSettings[pvrIndex].cutLocalMountRoot : mcutConsts.localMount
    if (belowPath.contains(localMountRoot) && isRemote) {
      searchPath = belowPath.replacingOccurrences(of: generalPrefs.systemConfig.pvrSettings[pvrIndex].cutLocalMountRoot, with: generalPrefs.systemConfig.pvrSettings[pvrIndex].cutRemoteExport)
      fileCountTask.launchPath = systemSetup.pvrSettings[pvrIndex].sshPath
      fileCountTask.arguments = [systemSetup.pvrSettings[pvrIndex].remoteMachineAndLogin, "/usr/bin/find \"\(searchPath)\" -regex \"^.*\\\(fileSuffix)$\" | wc -l"]
   }
    else {
      // TODO: look at putting this where the user can change it
      fileCountTask.launchPath = mcutConsts.shPath
      fileCountTask.arguments = ["-c", "/usr/bin/find \"\(belowPath)\" -regex \"^.*\\\(fileSuffix)$\" | wc -l"]
      searchPath = belowPath
    }
    fileCountTask.standardOutput = outPipe
    fileCountTask.standardError = outPipe
    fileCountTask.launch()
    let handle = outPipe.fileHandleForReading
    let data = handle.readDataToEndOfFile()
    if let resultString = String(data: data, encoding: String.Encoding.utf8)
    {
      // trim to just the text and try converting to a number
      let digitString = resultString.trimmingCharacters(in: CharacterSet(charactersIn: " \n"))
      if let fileCount = Int(digitString) {
        return fileCount
      }
      else {
        let message = String.localizedStringWithFormat(StringsCuts.FAILED_COUNTING_FILES, digitString)
        self.statusField.stringValue = message
      }
    }
    return defaultCount
  }
  
//  /// Query the PVR (or directory) for a list of the files with .xxx extension.
//  /// Written to do a external shell query and then process the resulting message
//  /// eg. countFilesWithSuffix(".ts", "/hdd/media/movie")
//  /// - parameter fileSuffix: tail to match including  leading "."
//  /// - parameter belowPath: absolute root path to start from 
//  /// - returns: array of filename strings in URL format
//  
//  func getListOfFilesWithSuffix(_ fileSuffix: String, belowPath: String) -> [String]?
//  {
//    var searchPath: String
//    
//    // use a task to get a count of the files in the directory
//    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
//    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
//    // CLI specifics are for BeyonWiz Enigma2 BusyBox 4.4
//    let fileCountTask = Process()
//    let outPipe = Pipe()
//    if (belowPath.contains(generalPrefs.cutLocalMountRoot)) {
//      searchPath = belowPath.replacingOccurrences(of: generalPrefs.cutLocalMountRoot, with: generalPrefs.cutRemoteExport)
//      fileCountTask.launchPath = systemSetup.sshPath
//      fileCountTask.arguments = [systemSetup.remoteManchineAndLogin, "/usr/bin/find \"\(searchPath)\" -regex \"^.*\\\(fileSuffix)$\" | grep -v \\.Trash"]
//    }
//    else {
//      fileCountTask.launchPath = systemSetup.shPath
//      fileCountTask.arguments = ["-c", "/usr/bin/find \"\(belowPath)\" -regex \"^.*\\\(fileSuffix)$\""]
//      searchPath = belowPath
//    }
//    fileCountTask.standardOutput = outPipe
//    fileCountTask.launch()
//    let handle = outPipe.fileHandleForReading
//    let data = handle.readDataToEndOfFile()
//    
//    if let resultString = String(data: data, encoding: String.Encoding.utf8)
//    {
//      // build array from string result
//      let trimmedString = resultString.trimmingCharacters(in: CharacterSet(charactersIn:" \n"))
//      if (trimmedString.isEmpty ) {
//        return nil
//      }
//      else {
//        let fileNameArray = trimmedString.components(separatedBy: "\n")
////        var reducedFileNameArray = fileNameArray.filter({!$0.contains(".Trash")})
//        // typicall replace the /hdd/media with /Volumes/Harddisk for local handling
//        let reducedFileNameArray = fileNameArray.map({$0.replacingOccurrences(of: generalPrefs.cutRemoteExport, with: generalPrefs.cutLocalMountRoot)})
//        let URLStringArray = reducedFileNameArray.map({NSURL(fileURLWithPath: $0.replacingOccurrences(of: "//", with: "/")).absoluteString!})
//        return URLStringArray
//      }
//    }
//    return nil
//  }
  
//  // TODO: ensure that this can work with mulitple PVRs
//  
//  func makeSearchTaskFor(filesWithSuffix: String,  belowPath: String) -> Process
//  {
//    // use a task to get a count of the files in the directory
//    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
//    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
//    // CLI specifics are for BeyonWiz Enigma2 BusyBox 4.4
//    var searchPath: String
//    let fileCountTask = Process()
//    fileCountTask.standardOutput = Pipe()
//    if (belowPath.contains(self.generalPrefs.systemConfig.pvrSettings[pvrIndex].cutLocalMountRoot)) {
//      searchPath = belowPath.replacingOccurrences(of: self.generalPrefs.systemConfig.pvrSettings[pvrIndex].cutLocalMountRoot, with: self.generalPrefs.systemConfig.pvrSettings[pvrIndex].cutRemoteExport)
//      fileCountTask.launchPath = self.systemSetup.pvrSettings[pvrIndex].sshPath
//      fileCountTask.arguments = [self.systemSetup.pvrSettings[pvrIndex].remoteMachineAndLogin, "/usr/bin/find \"\(searchPath)\" -regex \"^.*\\\(filesWithSuffix)$\" | grep -v \\.Trash"]
//    }
//    else {
//      fileCountTask.launchPath = self.systemSetup.pvrSettings[pvrIndex].shPath
//      fileCountTask.arguments = ["-c", "/usr/bin/find \"\(belowPath)\" -regex \"^.*\\\(filesWithSuffix)$\" | grep -v \\.Trash"]
//      searchPath = belowPath
//    }
//    return fileCountTask
//  }
//  
//  /// Background a potentially slow task.
//  /// Query the PVR (or directory) for a list of the files with .xxx extension.
//  /// Written to do a external shell query and then process the resulting message
//  /// eg. backgroundGetListOfFiles(withSuffix: ".ts", belowPath: "/hdd/media/movie")
//  /// - parameter fileSuffix: tail to match including  leading "."
//  /// - parameter belowPath: absolute root path to start from
//  
//  func backgroundGetListOfFiles(withSuffix: String, belowPath: String)
//  {
//    
//    let userQueue = DispatchQueue.global(qos: .userInitiated)
//    
//    let fileCountTask = makeSearchTaskFor(filesWithSuffix: withSuffix, belowPath: belowPath)
//    userQueue.async(execute: { [unowned self] in
//    // use a task to get a count of the files in the directory
//    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
//    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
//    // CLI specifics are for BeyonWiz Enigma2 BusyBox 4.4
//    fileCountTask.launch()
//    let handle = (fileCountTask.standardOutput as! Pipe).fileHandleForReading
//    let data = handle.readDataToEndOfFile()
//    var builtURLArray: [String]?
//    if let resultString = String(data: data, encoding: String.Encoding.utf8)
//    {
//      // build array from string result
//      let trimmedString = resultString.trimmingCharacters(in: CharacterSet(charactersIn:" \n"))
//      if (!trimmedString.isEmpty ) {
//        let fileNameArray = trimmedString.components(separatedBy: "\n")
//        //  var reducedFileNameArray = fileNameArray.filter({!$0.contains(".Trash")})
//        // typically replace the /hdd/media with /Volumes/Harddisk for local handling
//        let reducedFileNameArray = fileNameArray.map({$0.replacingOccurrences(of: self.generalPrefs.cutRemoteExport, with: self.generalPrefs.cutLocalMountRoot)})
//        builtURLArray = reducedFileNameArray.map({NSURL(fileURLWithPath: $0.replacingOccurrences(of: "//", with: "/")).absoluteString!})
//        // 
//        // All done dispatch results back to application
//        //
//        DispatchQueue.main.async(execute:  {
//          if (!self.fileSearchCancelled) {
//            if (builtURLArray != nil ) {
//              self.filelist = builtURLArray!
//            }
//            else {
//              // post a nothing found message
//              self.statusField.stringValue = "No files found with suffix \(withSuffix)"
//            }
//            print("From "+#function)
//            self.listingOfFilesFinished()
//          } else {
//            self.fileSearchCancelled = false
//            self.selectDirectory.isEnabled = true
//            self.statusField.stringValue = "Search Terminated"
//          }
//          })
//      }
//    }
//    } )
//  }
  
  /// Observer function that responds to a mouseDown event on the
  /// file select popupbutton - purpose is to pick up and retain
  /// the current selection index BEFORE it is changed
  func fileSelectPopUpChange(_ notification: Notification) {
    mouseDownPopUpIndex = self.currentFile.indexOfSelectedItem
  }
  
  override var representedObject: Any? {
    didSet {
      // Update the view, if already loaded.
    }
  }
  
  /// Enable and/or disable the GUI Previous and Next
  /// buttons based on the current selection in the
  /// list of files
  /// - parameter arrayIndex: index into the filelist array
  func setPrevNextButtonState(_ arrayIndex : Int)
  {
    currentFile.selectItem(at: filelistIndex)
    previousButton.isEnabled = (filelistIndex > 0)
    nextButton.isEnabled = (filelistIndex < (filelist.count-1))
  }
  
  /// Flush any pending changes back to the file system if
  /// there are any at index given
  
  func flushPendingChangesFor(_ indexSelector: FileToHandle) -> Bool
  {
    let index = (indexSelector == FileToHandle.current) ? filelistIndex : lastfileIndex
    var proceedWithWrite = true
    let validCuts = movie.cuts.isCuttable
    guard (validCuts) else {
      self.statusField.stringValue = movie.cuts.lastValidationMessage
      return false
    }
    if (cutsModified ) {
      if (generalPrefs.autoWrite == CheckMarkState.unchecked) {
        // pop up a modal dialog to confirm overwrite of cuts file
        let overWriteDialog = NSAlert()
        overWriteDialog.alertStyle = NSAlertStyle.critical
        overWriteDialog.informativeText = "Will overwrite the \(ConstsCuts.CUTS_SUFFIX) file"
        overWriteDialog.window.title = "Save File"
        let programname = self.currentFile.item(at: lastfileIndex)!.title.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
        overWriteDialog.messageText = "OK to overwrite file \n\(programname)"
        overWriteDialog.addButton(withTitle: "OK")
        overWriteDialog.addButton(withTitle: "Cancel")

        let result = overWriteDialog.runModal()
        proceedWithWrite = result == NSAlertFirstButtonReturn
      }
      
      // autowrite is enabled, so just get on with it
      if (proceedWithWrite) {
        // rewrite cuts file
        if movie.saveCuts() {
//    
//        let (fileMgr, found, fullFileName) = Recording.getFileManagerForFile(filelist[index])
//        if (found) {
//          let cutsData = movie.cuts.encodeCutsData()
//          let fileWritten = fileMgr.createFile(atPath: fullFileName, contents: cutsData, attributes: nil)
          if ( debug) {
            print(MessageStrings.DID_WRITE_FILE)
          }
//          self.cuts.saveCutsToFile(fullFileName, using: fileMgr)
          setDropDownColourForIndex(index)
        }
        else {
          self.statusField.stringValue = StringsCuts.FILE_SAVE_FAILED
          // TODO:  needs some sort of try again/ give up options
          return true
        }
      }
    }
    return true
  }
  
  /// Change the selected file to
  /// the one corrensponding to the given index.  Open the
  /// file, extract various information from the related files
  /// and update the GUI to match
  /// - parameter arrayIndex: index in to the array of recording file URLs
  ///
  func changeFile(_ toIndex: Int)
  {
    var startTime : CMTime
    
    guard flushPendingChangesFor(.previous) else
    {
      // ensure that picker list is not changed
      // capture and restore error message
      let flushMessage = self.statusField.stringValue
      currentFile.selectItem(at: lastfileIndex)
      currentFile.toolTip = currentFile.selectedItem?.toolTip
      self.statusField.stringValue = flushMessage
      return
    }

    //  clean out the GUI and context for the next file
    self.monitorView.player?.cancelPendingPrerolls()
    self.monitorView.player?.currentItem?.cancelPendingSeeks()
    resetGUI()
    resetCurrentModel()
    setStatusFieldToCurrentSelection()
    videoDurationFromPlayer = 0.0
   
    currentFile.toolTip = currentFile.selectedItem?.toolTip
    let actualFileName = filelist[filelistIndex].components(separatedBy: CharacterSet(charactersIn: "/")).last
    fileWorkingName = actualFileName!.removingPercentEncoding!
    let baseName = filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    movie = Recording(rootProgramName: baseName)
    
//    let cutsData = Recording.loadRawDataFrom(file: filelist[filelistIndex])
//    if cutsData != nil {
//      cuts = CutsFile(data: cutsData!)
//    }
//    else { // empty table
//      cuts = CutsFile()
//    }
    if (debug) { movie.cuts.printCutsData() }
    self.cutsTable.reloadData()
    
    // select begining of file or earliest bookmark if just a few
    if (movie.cuts.count>0 && movie.cuts.count<=3)
    {
      let startPTS = Int64(movie.cuts.first!.cutPts)
      startTime = CMTimeMake(startPTS, CutsTimeConst.PTS_TIMESCALE)
    }
    else {
      startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
    }
    
    // process eit file
    let EitName = baseName+ConstsCuts.EIT_SUFFIX
    let EITData = Recording.loadRawDataFrom(file: EitName)
    if (EITData != nil ) {
      eit=EITInfo(data: EITData!)
      if (debug) { print(eit.description()) }
    }
    else {
      eit = EITInfo()
    }
    programTitle.stringValue = eit.programNameText()
    epsiodeTitle.stringValue = eit.episodeText()
    programDescription.string = eit.descriptionText()
    
    let metaFilename = baseName+ConstsCuts.META_SUFFIX
    
    metadata = MetaData(fromFilename: URL(string: metaFilename)!)
    
    // load the ap file
    let apName = URL(string: filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.AP_SUFFIX))!
    accessPointData = AccessPoints(fullpath: apName)

    if (debug) { print(metadata.description()) }
    // if description is empty, replicate title in description field
    // some eit entries fail to give a title and put the description
    // in the notional episode title descriptor
    if programDescription.string!.isEmpty
    {
      programDescription.string = eit.episodeText()
    }
    let TSName = baseName+ConstsCuts.TS_SUFFIX
    setupAVPlayerFor(TSName, startTime: startTime)
    // found a loaded a file, update the recent file menu
    let name = baseName+ConstsCuts.CUTS_SUFFIX
    let fileURL = URL(string: name)!
    if  let doc = try? TxDocument(contentsOf: fileURL, ofType: ConstsCuts.CUTS_SUFFIX)
    {
       NSDocumentController.shared().noteNewRecentDocument(doc)
    }
  }

  // MARK: - button responders
  
  /// Direction choice used for stepping through a list of programs
  
  enum ProgramChoiceStepDirection {
    case NEXT, PREVIOUS
  }
  
  /// Common code function for choosing the next or previous
  /// program in the sorted list
  /// - parameter direction : ProgramChoiceStepDirection.NEXT or ProgramChoiceStepDirection.PREVIOUS
  func previousNextButtonAction(_ direction: ProgramChoiceStepDirection)
  {
    if (self.monitorView.player != nil)
    {
      let playerState = self.monitorView.player?.status
      if (playerState != AVPlayerStatus.failed)
      {
        self.monitorView.player?.pause()
      }
    }
    // should not be possible to invoke when index is > count-1 or == 0
    // belt and braces approach bounds checking
    let forwardOK = (filelistIndex<(currentFile.numberOfItems-1) && direction == .NEXT)
    let backwardOK = (direction == .PREVIOUS && filelistIndex > 0)
    if ( forwardOK || backwardOK)
    {
      let adjustment = direction == .NEXT ? 1 : -1
      lastfileIndex = filelistIndex
//      print("filelistIndex is now \(filelistIndex)")
      currentFile.selectItem(at: lastfileIndex+adjustment)
      changeFile(filelistIndex)
      // check sucess of change file, filelistIndex reset to last file on failure
      if (lastfileIndex != filelistIndex)
      { // success
        setPrevNextButtonState(filelistIndex)
      }
      else {
        // failed, put picker has been put back
        setPrevNextButtonState(filelistIndex)
      }
    }
  }
  
  @IBAction func prevButton(sender: NSButton) {
    previousNextButtonAction(ProgramChoiceStepDirection.PREVIOUS)
  }
  
  @IBAction func nextButton(sender: NSButton) {
    previousNextButtonAction(ProgramChoiceStepDirection.NEXT)
  }
  
  /// with thanks for a shortcut to
  /// http://stackoverflow.com/questions/28362472/is-there-a-simple-input-box-in-cocoa
  ///
  static func getString(title: String, question: String, defaultValue: String) -> String {
    let msg = NSAlert()
    msg.addButton(withTitle: "OK")      // 1st button
    msg.addButton(withTitle: "Cancel")  // 2nd button
    msg.messageText = title
    msg.informativeText = question
    
    let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 400, height: 24))
    textField.stringValue = defaultValue
    
    msg.accessoryView = textField
    let response: NSModalResponse = msg.runModal()
    
    if (response == NSAlertFirstButtonReturn) {
      return textField.stringValue
    } else {
      return ""
    }
  }
  
  @IBAction func cutButton(_ sender: NSButton)
  {
    // disconnect player display from the item about to be processed
    guard flushPendingChangesFor(.current) else
    {
      return
    }
    removePlayerObserversAndItem()
    // clear current dialog entries
    resetCurrentModel()
    resetGUI()
    let moviePathURL = filelist[filelistIndex]
    cutMovie(moviePathURL)
    currentFile.isEnabled = true
    setPrevNextButtonState(filelistIndex)
  }
  
  /// Invokes "change program" code on action with the
  /// GUI Program Picker - NSPopUpButton list of programs
  
  @IBAction func selectFile(_ sender: NSPopUpButton) {
    lastfileIndex = mouseDownPopUpIndex!
    let indexSelected = sender.indexOfSelectedItem
    if (debug) { print("New file selected is [\(indexSelected) - \(sender.itemArray[indexSelected])") }
    if (indexSelected != mouseDownPopUpIndex) // file selection has really changed
    {
      setPrevNextButtonState(indexSelected)
      changeFile(indexSelected)
      // check if change succeeded or it has reset the selected index
      if (indexSelected == lastfileIndex) {
        sender.selectItem(at: indexSelected)
      }
      currentFile.toolTip = currentFile.selectedItem?.toolTip
    }
    mouseDownPopUpIndex = nil
  }
  
  // for the user to select a directory and populate an array with
  // the names of files that match the pattern on interest
  // toggles to CANCEL on start of search
  
  @IBAction func findFileAction(_ sender: NSButton)
  {
    guard flushPendingChangesFor(.current) else
    {
      return
    }
    resetSearch()

    let completionBlock : FindCompletionBlock = {  foundList,  forSuffix,  wasCancelled in
      /// Call back function for each completed operation.
      /// Can return list of files, no files and SUCCESS
      /// or nil list and CANCELLED
      if (!wasCancelled) {
        if (foundList != nil ) {
          self.filelist = foundList!
        }
        else {
          // post a nothing found message
          self.filelist.removeAll()
          self.statusField.stringValue = "No files found with suffix \(forSuffix)"
        }
//        print("From "+#function)
        self.listingOfFilesFinished()
        self.actionsSetEnabled(true)
      } else {
        self.fileSearchCancelled = false
        self.selectDirectory.isEnabled = true
        self.statusField.stringValue = "Search Terminated"
      }
    }
    
    if (sender.title == StringsCuts.SELECT_DIRECTORY)
    {
      if  let pickedPath = self.browseForFolder()
      {
        var rootPath : String
        rootPath = pickedPath + StringsCuts.DIRECTORY_SEPERATOR
        let foundRootPath = rootPath
        self.progressBar.isHidden = false
        (isRemote, pvrIndex) = pvrLocalMount(containedIn: rootPath)
        if let maxFiles = countFilesWithSuffix(ConstsCuts.TS_SUFFIX, belowPath: foundRootPath)
        {
          self.progressBar.maxValue = Double(maxFiles)
          // check if the message can be converted into a number
          self.finderOperationsQueue = FindFilesOperation.createQueue()
          let findFilesOperation = FindFilesOperation(foundRootPath: foundRootPath,
                                                      withSuffix: ConstsCuts.CUTS_SUFFIX,
                                                      pvrIndex: pvrIndex,
                                                      isRemote: isRemote,
                                                      sysConfig: systemSetup,
                                                      completion: completionBlock)
          self.finderOperationsQueue?.addOperation(findFilesOperation)
          self.statusField.stringValue = "Collecting List of files started ..."
          sender.title = StringsCuts.CANCEL_SEARCH
          // work out if local or remote and if remote, the index to the configuation
          fileSearchCancelled = false
        }
      }
      else {
        sender.title = StringsCuts.SELECT_DIRECTORY
      }
    }
    else    // user clicked on Cancel Search
    {
      fileSearchCancelled = true
      sender.title = StringsCuts.SELECT_DIRECTORY
      actionsSetEnabled(false)
      sender.isEnabled = false
      statusField.stringValue = "Waiting on cancellation of search opertion"
    }
   }

  func pvrLocalMount(containedIn dirPath: String) -> (isLocal: Bool, configIndex: Int)
  {
    // note index 0 is always local cutting configuration
    // so only look at remote mounts roots
    for i in 1 ..< self.systemSetup.pvrSettings.count {
      let pvr = systemSetup.pvrSettings[i]
      if dirPath.contains(pvr.cutLocalMountRoot)
      {
        let isRemote = (pvr.title != mcutConsts.fixedLocalName)
        return (isRemote, i)
      }
    }
    return (false, 0)
  }
  /// respond to configured skip buttons
  // TODO: Create the logic to handle honour skipping into Out/In sections
  // TODO: when skipping is to be honoured
  @IBAction func seekToAction(_ sender: NSButton) {
    if let key = skipButtons(rawValue: sender.tag) {
      switch key {
        case skipButtons.MINUS_A: seekToSkip(skips.lhs[0].value)
        case skipButtons.PLUS_A: seekToSkip(skips.rhs[0].value)
        
        case skipButtons.MINUS_B: seekToSkip(skips.lhs[1].value)
        case skipButtons.PLUS_B: seekToSkip(skips.rhs[1].value)
        
        case skipButtons.MINUS_C: seekToSkip(skips.lhs[2].value)
        case skipButtons.PLUS_C: seekToSkip(skips.rhs[2].value)
        
        case skipButtons.MINUS_D: seekToSkip(skips.lhs[3].value)
        case skipButtons.PLUS_D: seekToSkip(skips.rhs[3].value)
        
        case skipButtons.MINUS_E: seekToSkip(skips.lhs[4].value)
        case skipButtons.PLUS_E: seekToSkip(skips.rhs[4].value)
      }
    }
  }
  
  // files on disk are unique.. therefore easy sorting
  // Duplicate names may occur in multiple directories.  We don't care
  // where they are, we want all 'like' names brought together
  
  func pairsListNameSorter( _ s1: namePair, s2: namePair) -> Bool
  {
    var names1, names2: String
    let names1Array = s1.programeName.components(separatedBy: kHyphen)
    let names2Array = s2.programeName.components(separatedBy: kHyphen)
    // pick program name from expected format of "DateTime - Channel - ProgramName"
    if (names1Array.count >= 3 && names2Array.count >= 3) { // pick name from expected
     names1 = names1Array[2 ... names1Array.count-1].joined(separator: kHyphen)
     names2 = names2Array[2 ... names2Array.count-1].joined(separator: kHyphen)
    }
    else { // not expected format use full name
      names1 = s1.programeName
      names2 = s2.programeName
    }
    var greaterThan: Bool
    if sortPrefs.isAscending {
      greaterThan = names1 < names2
    }
    else {
      greaterThan =  names1 > names2
    }
    return greaterThan
  }
  
  func pairsListChannelSorter( _ s1:namePair, s2: namePair) -> Bool
  {
    var greaterThan: Bool
    let names1 = s1.programeName.components(separatedBy: kHyphen)[1]
    let names2 = s2.programeName.components(separatedBy: kHyphen)[1]
    if sortPrefs.isAscending {
      greaterThan = names1 < names2
    }
    else {
      greaterThan =  names1 > names2
    }
    return greaterThan
  }
  
  func pairsListDateSorter( _ s1: namePair, s2: namePair) -> Bool
  {
    var greaterThan: Bool
    if sortPrefs.isAscending {
      greaterThan = s1.programeName < s2.programeName
    }
    else {
      greaterThan =  s1.programeName > s2.programeName
    }
    return greaterThan
  }
 
  func sortNames()
  {
    // build a pair list from namelist and filelist
    var namePairs = [namePair]()
    for name in namelist
    {
      let pair = namePair(diskURL: filelist[namelist.index(of: name)!], programeName: name)
      namePairs.append(pair)
    }
    sortNamePairs(&namePairs)
    
    // now rewrite namelist / filelist
    
    buildNameFileListFrom(namePairs)
  }
  
  /// Given the ordered array of namePairs
  /// Build the name list and file list arrays.
  /// Modify the name entry if duplication of name
  /// occurs with different associated storage locations
  /// - parameter namePairs: usually ordered by name, but not mandatory
  
  func buildNameFileListFrom(_ namePairs: [namePair])
  {
    // now rewrite namelist / filelist
    
    filelist.removeAll()
    namelist.removeAll()
    var count = 0
    for pair in namePairs
    {
      filelist.append(pair.diskURL)
      
      // take care of duplication of names in different directories by appending (n) to name
      if (namelist.contains(pair.programeName)) {
        count += 1
        let secondaryName = pair.programeName + " (\(count))"
        namelist.append(secondaryName)
      }
      else {
        namelist.append(pair.programeName)
        count = 0
      }
    }
  }
  
  func sortNamePairs(_ namePairs: inout [namePair])
  {
    // pick a sorter
    if (sortPrefs.sortBy == sortStringConsts.byDate)
    {
      namePairs.sort(by: pairsListDateSorter)
    }
    else if (sortPrefs.sortBy == sortStringConsts.byName)
    {
      namePairs.sort(by: pairsListNameSorter)
    }
    else if (sortPrefs.sortBy == sortStringConsts.byChannel)
    {
      namePairs.sort(by: pairsListChannelSorter)
    }
  }
  
  /// If the file matching the given path exists, add it to the
  /// current filelist and select it
  /// If it is already in the list, simply find it and select it
  /// If the file does not exist, then bail out
  /// - parameter filename: full path to file
  /// - returns: true on success of selecting file and false if no such file
  
  // FIXME: update file count in gui and work out why duplication is happening
  
  func appendSingleFileToListAndSelect(_ filename: String) -> Bool
  {
    // check file still exists and is in the current list
    let fileManager = FileManager.default
    guard (!filelist.contains(filename)) else {
      // simply find it and select it
      currentFile.selectItem(at: filelist.index(of: filename)!)
      setPrevNextButtonState(filelistIndex)
      changeFile(filelistIndex)
      return true
    }
    
    // check that a file of the given name exists
    // can still get into trouble after this from network failures
    // but that level of network robustness needs to be built in at a 
    // much lower level and is for another day
    guard (fileManager.fileExists(atPath: filename) ) else {
      return false
    }
    
    // file exists but is not in currentFile list
    // new entry, create URL from disk path
    
    let urlName = URL(fileURLWithPath: filename)
    appendSingleFileURLToListAndSelect(urlName)
    return true
  }
  
  func appendSingleFileURLToListAndSelect(_ fileURL:URL) {
    
    filelist.append(fileURL.absoluteString)
    
    // sort and select
    let (menuTitles, menuItemArray) = retainAttributedStringList(currentFile)
    sortFilelist()
    restoreAttributedStringList(currentFile, itemTitles: menuTitles, menuItems: menuItemArray)
    
    currentFile.selectItem(at: filelist.index(of: fileURL.absoluteString)!)
    setDropDownColourForIndex(filelistIndex)
    setPrevNextButtonState(filelistIndex)
    changeFile(filelistIndex)
  }
  
  /// Create a list from the filelist that is sorted by program name
  /// ignoring pathname elements. Populates the variable used by the
  /// dropdown list in the GUI
  
  func sortFilelist()
  {
      var namePairs = [namePair]()
      for diskName in filelist
      {
        let programNameComponent = diskName.components(separatedBy: CharacterSet(charactersIn: "/")).last
        let programName = programNameComponent!.removingPercentEncoding!
        let pair = namePair(diskURL: diskName, programeName: programName)
        namePairs.append(pair)
      }
      
      sortNamePairs(&namePairs)
      buildNameFileListFrom(namePairs)
      
      self.currentFile.removeAllItems()
      self.currentFile.addItems(withTitles: namelist)
      // add a tip of the actual file path 
      for index in 0 ..< self.currentFile.itemArray.count {
        let path = filelist[index].replacingOccurrences(of: "file://", with: "")
        self.currentFile.item(at: index)?.toolTip = path.removingPercentEncoding
      }
    
  }
  
  /// Routine to work out the colour coding for the list of programs.
  /// This can be a lengthy task and is done as a detached process with
  /// the GUI being updated on completion.  The process may be cancelled
  /// or restarted as a consequence of user actions that change the base
  /// list of files that it is working on.
  /// - returns: reference such parent can query and cancel the process
  
  fileprivate func colourCodeProgramList() -> BlockOperation
  {
    self.statusField.stringValue = StringsCuts.DERIVING_PROGRAM_STATUS
    let queue = OperationQueue()
    let blockOperation = BlockOperation()
    var resultNotWanted = false
    self.progressBar.maxValue = Double(self.namelist.count)
    self.progressBar.doubleValue = 0.0
    blockOperation.addExecutionBlock(
      {
        var attributedStrings = [NSAttributedString]()
        
        // progressively construct a duplicate of NSPopUpButton to query & update without interfering with UI
        for index in 0 ..< self.namelist.count
        {
          // each time through the loop check that we are still wanted
          if blockOperation.isCancelled {
            resultNotWanted = true
            break
          }
          let (fontAttribute, colourAttribute) = self.getFontAttributesForIndex(index)
          if let menuItem = self.currentFile.item(at: index)
          {
            attributedStrings.append(NSAttributedString(string: menuItem.title, attributes:[NSForegroundColorAttributeName: colourAttribute, NSFontAttributeName:fontAttribute]))
          }
          // update the application each time we have completed one program except the last
          if (index < self.namelist.count-1) {
            OperationQueue.main.addOperation (
            {
//              print("deriving is \(index) of \(self.namelist.count)... working")
              self.progressBar.doubleValue = Double(index)
  //            self.statusField.stringValue = "deriving is \(index) of \(self.namelist.count)... working"
              self.statusField.stringValue = "Working out program colouring in background"
            })
          }
        }
        
        if (resultNotWanted) {
          OperationQueue.main.addOperation (
            {
              self.statusField.stringValue = StringsCuts.COLOUR_CODING_CANCELLED
              self.progressBar.isHidden = true
            }
          )
        }
        else {        // completed normally
          OperationQueue.main.addOperation (
            {
//              print("setting colors")
              for index in 0 ..< self.namelist.count
              {
                self.currentFile.item(at: index)?.attributedTitle = attributedStrings[index]
              }
              // now as we have been scribbling in the status field, we ensure that is brought
              // back into sync with the current user selection
              self.setStatusFieldToCurrentSelection()
              self.progressBar.isHidden = true
            }
          )
        }
      }
    )
    
    queue.addOperation(blockOperation)
    return blockOperation
  }
  
  /// Determine the colour and font for an attributed string for the program at the given Index
  /// - parameter index: index into filelist array
  /// - returns: tuple of NSColor and NSFont
  
  func getFontAttributesForIndex( _ index : Int) -> (font :NSFont, colour: NSColor)
  {
    // set defaults
    var attributeColour = NSColor.black
    let fontSize = NSFont.systemFontSize()
    var font = NSFont.systemFont(ofSize: fontSize)
    var thisProgramDuration = 0.0
    
    // work through the set of files
    let cutsData = Recording.loadRawDataFrom(file: filelist[index])
    let metaName = URL(string: filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.META_SUFFIX))!
    let metaData = MetaData(fromFilename: metaName)
    let eitName = URL(string: filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.EIT_SUFFIX))!
    let EITData = Recording.loadRawDataFrom(file: eitName.path)
    var eitdata : EITInfo?
    if (EITData != nil  && (EITData?.count)! > 0) {
      eitdata=EITInfo(data: EITData!)
    }
    else {
      eitdata = EITInfo()
    }
    // load the ap file
    let apName = URL(string: filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.AP_SUFFIX))!
    let apData = AccessPoints(fullpath: apName)
    
    thisProgramDuration = self.getBestDurationInSeconds(metaData, eit: eitdata, ap: apData, player: nil)
    
    if cutsData != nil {
      let thisCuts = CutsFile(data: cutsData!)
      attributeColour = (thisCuts.count > fileColourParameters.BOOKMARK_THRESHOLD_COUNT) ? fileColourParameters.allDoneColor : fileColourParameters.noBookmarksColor
      
      // override if we have in/out pairs
      if ( thisCuts.containsINorOUT()) {
        font = NSFont.boldSystemFont(ofSize: fontSize)
        attributeColour = fileColourParameters.readyToCutColor
      }
      
      // override if it is a short
      if (attributeColour == fileColourParameters.noBookmarksColor  &&
          (thisProgramDuration > 0.0 && thisProgramDuration < fileColourParameters.PROGRAM_LENGTH_THRESHOLD)) {
        attributeColour = fileColourParameters.allDoneColor
      }
    }
    else { // no cuts data implies unprocessed (not guaranteed since a cut program, may simply have no bookmarks but....)
      if (thisProgramDuration > 0.0 && thisProgramDuration < fileColourParameters.PROGRAM_LENGTH_THRESHOLD) {
        attributeColour = fileColourParameters.allDoneColor
      }
      else {
        attributeColour = fileColourParameters.noBookmarksColor
      }
    }
    return (font, attributeColour)
  }
  
  /// Routine that examines the cuts data associated program and
  /// set the colour of the NSPopUpButton based on an estimate that the cuts file
  /// has already been processed
  
  // FIXME: make the number of marks for full processing configurable
  /// Processed fully if more that 5 bookmarks (green)
  /// Processed partially if IN and/or OUT marks present (blue)
  /// Unprocessed if less than 5 bookmarks (red)

  func setDropDownColourForIndex(_ index: Int)
  {
    let (fontAttribute, colourAttribute) = getFontAttributesForIndex(index)
    if  let menuItem = currentFile.item(at: index)
    {
      menuItem.attributedTitle = NSAttributedString(string: menuItem.title, attributes: [NSForegroundColorAttributeName: colourAttribute, NSFontAttributeName: fontAttribute])
    }
  }
  
  /// Routine that examines the cuts data associated with each program and
  /// set the colour of the NSPopUpButton based on a guess that the cuts file
  /// has already been processed
  
//  // FIXME: Check what happens if user changes directory selection whilst this
//  // detached process in running....it should probably find some way of killing it.
  func setCurrentFileListColors()
  {
    self.progressBar.isHidden = false
    self.progressBar.needsDisplay = true
    self.view.needsDisplay = true
    currentFileColouringBlock = colourCodeProgramList()
  }
  
  /// callback function when detached file search process has finished
  /// creates the NSPopButton (dropdown list) of programs to be 
  /// handled
  
  func listingOfFilesFinished()
  {
//    statusField.stringValue = "file count is \(filelist.count) ... finished"
    self.selectDirectory.title = StringsCuts.SELECT_DIRECTORY
    guard (filelist.count != 0 ) else
    {
      // FIXME: should reset to all empty state
      currentFile.removeAllItems()
      currentFile.addItem(withTitle: StringsCuts.NO_FILE_CHOOSEN)
      return
    }
    sortFilelist()
    setCurrentFileListColors()
    setPrevNextButtonState(filelistIndex)
    changeFile(filelistIndex)
  }

  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if (menuItem.action == #selector(clearBookMarks(_:))
      || menuItem.action == #selector(clearCutMarks(_:))
      || menuItem.action == #selector(clearLastPlayMark(_:))
      || menuItem.action == #selector(add10Bookmarks(_:))
      || menuItem.action == #selector(clearAllMarks(_:))
      )
    {
      return (filelist.count > 0 )
    }
    else {
      return true
    }
  }

  
//  @IBAction func trim(sender: AnyObject)
//  {
//    print("hello from Trim")
//    self.monitorView.beginTrimming(completionHandler: nil)
//  }
//
//  func validateUserInterfaceItem(_ anItem: NSValidatedUserInterfaceItem) -> Bool
//  {
//    let theAction = anItem.action
//    if ( theAction == #selector(trim)) {
//      if (self.monitorView.canBeginTrimming) {
//        self.monitorView.beginTrimming(completionHandler: {result in
//          if result == .okButton {
//            print ("Ok trimed")
//          }
//          else { print("trim cancelled")
//          }
//        })
//      }
//    }
//    return true
//  }
  
  /// set the GUI elements that are dependent on having at least one
  /// file available enabled or not
  /// - parameter state: true == enabled, false == disabled
  func actionsSetEnabled(_ state: Bool)
  {
    seekButton1a.isEnabled = state
    seekButton1b.isEnabled = state
    seekButton1c.isEnabled = state
    seekButton1d.isEnabled = state
    seekButton1e.isEnabled = state
    seekButton2a.isEnabled = state
    seekButton2b.isEnabled = state
    seekButton2c.isEnabled = state
    seekButton2d.isEnabled = state
    seekButton2e.isEnabled = state
    //    markButton.enabled = state
    cutButton.isEnabled = state
    tenMarkButton.isEnabled = state
    inButton.isEnabled = state
    outButton.isEnabled = state
    currentFile.isEnabled = state
    if (state)
    {
     setPrevNextButtonState(filelistIndex)
    }
    else {
      previousButton.isEnabled = state
      nextButton.isEnabled = state
    }
  }
  
  func resetGUI()
  {
    programTitle.stringValue = ""
    programDescription.string = ""
    epsiodeTitle.stringValue = ""
    cutsTable.reloadData()
    fileWorkingName = ""
    programDuration.stringValue = ""
    statusField.stringValue = ""
    actionsSetEnabled(false)
    self.cutsTable.reloadData()
    currentFile.toolTip = ""
  }
  
  /// Assigns the button text to each button from
  /// the user's skip Preferences
  
  func skipButtonGUISetup(_ skips: skipPreferences)
  {
    seekButton1a.title = skips.lhs[0].display
    seekButton1b.title = skips.lhs[1].display
    seekButton1c.title = skips.lhs[2].display
    seekButton1d.title = skips.lhs[3].display
    seekButton1e.title = skips.lhs[4].display
    
    seekButton2a.title = skips.rhs[0].display
    seekButton2b.title = skips.rhs[1].display
    seekButton2c.title = skips.rhs[2].display
    seekButton2d.title = skips.rhs[3].display
    seekButton2e.title = skips.rhs[4].display
  }
  
  func resetCurrentModel()
  {
    movie.cuts.removeAll()
    eit = EITInfo()
    movie.cuts = CutsFile()
    wasPlaying = false
    metadata = MetaData()
  }
  
  func resetFullModel()
  {
    if currentFileColouringBlock != nil
    {
      currentFileColouringBlock!.cancel()
      currentFileColouringBlock!.waitUntilFinished() // block on cancel completing... may file badly
      currentFileColouringBlock = nil
    }
    resetCurrentModel()
    filelist.removeAll()
    namelist.removeAll()
    currentFile.removeAllItems()
    currentFile.addItem(withTitle: StringsCuts.NO_DIRECTORY_SELECTED)
    currentFile.selectItem(at: 0)
    lastfileIndex = 0
    removePlayerObserversAndItem()
  }
  
  func resetSearch()
  {
//    print("Clearing dialog fields")
    resetFullModel()
    resetGUI()
  }
  
  // count of found matching files
  // call back from detached operation
  
//  func findFilesFinished(_ fileIndexCount : Int, listOfFiles : [String])
//  {
//    self.selectDirectory.title = StringsCuts.SELECT_DIRECTORY
////    print(listOfFiles)
//    self.filelist = listOfFiles
//    self.statusField.stringValue = "file count is \(fileIndexCount) ... finished"
//    self.progressBar.isHidden = true
//  }
  
  /// Select folder for processing of file
  /// - returns: full path to directory or nil
  func browseForFolder() -> String?
  {
    
    // Create the File Open Dialog class.
    let openDlg = NSOpenPanel()
    
    // Disable  the selection of files in the dialog.
    openDlg.canChooseFiles=false
    
    // Multiple files not allowed
    openDlg.allowsMultipleSelection = false
    
    // Can only select a directory
    openDlg.canChooseDirectories = true
    
    // Display the dialog. If the OK button was pressed,
    // process the files.
    var directory :URL?
    if ( openDlg.runModal() == NSModalResponseOK )
    {
      // Get an array containing the full filenames of all
      // files and directories selected.
      let files = openDlg.urls
      
      directory = (files.count>0) ? files[0]  : nil;
    }
    if (self.debug) {
      print("Selected "+((directory != nil) ? "\(directory)" : "nothing picked"))
    }
    return directory?.path
  }
  
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
  {
    if (debug) {
      let whatsIt = Mirror(reflecting: object!)
      print(whatsIt)
      for case let (label?, value) in whatsIt.children {
        print (label, value)
      }
    }
    if (debug) { print ("keypath <\(keyPath)> for  \((object as AnyObject).className)") }
    if (keyPath == "tracks") {
      if let tracks = change?[NSKeyValueChangeKey.newKey] as? [AVPlayerItemTrack] {
//        print("new value \(tracks)")
        for track in tracks
        {
          if (debug) {
            print("videoFieldMode: \(track.videoFieldMode)")
            print("assetTrack.trackID: \(track.assetTrack.trackID)")
            print("track.assetTrack.mediaType: \(track.assetTrack.mediaType)")
            print("track.assetTrack.playable: \(track.assetTrack.isPlayable)")
          }
          let duration = track.assetTrack.asset?.duration
          let durationInSeconds = CMTimeGetSeconds(duration!)
          if (debug) { print("duration = \(durationInSeconds) secs") }
          videoDurationFromPlayer = durationInSeconds
        }
      }
      else {
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
      }
      
    }
    else if (keyPath == "status" && object is AVPlayerItem)
    {
      if let newStatus = change?[NSKeyValueChangeKey.newKey]
      {
        if let status = AVPlayerStatus(rawValue: Int(newStatus as! Int))
        {
          if (debug) { print("status Enum = \(status)") }
          switch status {
          case .failed:
            if (debug) { print("failed state") }
          case .readyToPlay:
            if (debug) {
              print("ready to play")
              print("metadata duration = \(metadata.duration)")
              print("eit duration = \(eit.eit.Duration)")
            }
            programDurationInSecs = getBestDurationInSeconds(metadata, eit: eit, ap: accessPointData, player: self.monitorView.player)
            
            self.programDuration.stringValue = CutEntry.hhMMssFromSeconds(programDurationInSecs)
//            if (metadata.duration == "0" || metadata.duration == "")
//            {
//              if (eit.eit.Duration != "00:00:00.00") {
//                self.programDuration.stringValue = eit.eit.Duration
//              }
//              else {  // query the player
//                let playerDuration = CMTimeGetSeconds((self.monitorView.player?.currentItem?.duration)!)
//                self.programDuration.stringValue = CutEntry.hhMMssFromSeconds( playerDuration )
//              }
//            }
//            else
//            {  // meta data looks OK, use it for duration display
//              self.programDuration.stringValue = CutEntry.timeTextFromPTS(UInt64(metadata.duration)!)
//            }
//            let startTime = (self.cuts.count>=1) ? self.cuts.firstBookmark : CMTime(seconds: 0, preferredTimescale: 1)
            let startTime = CMTimeMake(Int64(firstVideoPosition().cutPts), CutsTimeConst.PTS_TIMESCALE)
            if (self.monitorView.player?.status == .readyToPlay)
            {
              self.monitorView.player?.seek(to: startTime, completionHandler: seekCompletedOK)
            }
            self.actionsSetEnabled(true)
          case .unknown:
            if (debug) { print("Unknown") }
          }
        }
        if (debug) { print ("new value of status = \(newStatus)") }
      }
      else {
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
      }
    }
    else if (keyPath == "status" && object is AVPlayer)
    {
      if let newStatus = change?[NSKeyValueChangeKey.newKey]
      {
        if let status = AVPlayerStatus(rawValue: Int(newStatus as! Int))
        {
          if (debug) { print("status Enum = \(status)") }
          switch status {
          case .failed:
            if (debug) { print("failed state") }
          case .readyToPlay:
            if (debug) {
              print("Player ready to play")
              print("metadata duration = \(metadata.duration)")
            }
            self.programDuration.stringValue = CutEntry.timeTextFromPTS(UInt64(metadata.duration)!)
            let startTime = (movie.cuts.count>=1) ? movie.cuts.firstMarkTime : CMTime(seconds: 0, preferredTimescale: 1)
            if (self.monitorView.player?.status == .readyToPlay)
            {
              self.monitorView.player?.seek(to: startTime, completionHandler: seekCompletedOK)
            }
            self.actionsSetEnabled(true)
          case .unknown:
            if (debug) { print("Unknown") }
          }
        }
        if (debug) { print ("new value of player status = \(newStatus)") }
      }
    }
    else if (keyPath == "rate" && object is AVPlayer)
    {
      if let newRate = change?[NSKeyValueChangeKey.newKey]
      {
        if (debug) { print ("new value of player rate = \(newRate)") }
      }
    }
    else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
 }

  func removePlayerObserversAndItem()
  {
    if (self.monitorView.player != nil )
    {
      if (self.monitorView.player?.currentItem != nil)
      {
        self.monitorView.player?.currentItem?.removeObserver(self, forKeyPath: "tracks")
        self.monitorView.player?.currentItem?.removeObserver(self, forKeyPath: "status")
        self.monitorView.player?.removeObserver(self, forKeyPath: "status")
        self.monitorView.player?.removeObserver(self, forKeyPath: "rate")
        if let token = self.timeObserverToken {
          self.monitorView.player?.removeTimeObserver(token)
          self.timeObserverToken = nil
        }
      }
    }
    self.monitorView.player = nil
  }
  
  func setupAVPlayerFor(_ fileName:String, startTime: CMTime)
  {
    if (debug) { print ("Setting up av Player with string <\(fileName)") }

    // remove observers before instantiating new objects
    removePlayerObserversAndItem()
    
    let videoURL = URL(string: fileName)
    let avAsset = AVURLAsset(url: videoURL!)
    if (debug) { print("available formats:  \(avAsset.availableMetadataFormats)") }
    
    // ensure all track durations are valid - don't known enough video to 
    // write bad video recovery functions
    var durationIsValid = true
    for trackAsset in avAsset.tracks {
      let track = trackAsset.asset!
      let duration = track.duration
      durationIsValid = durationIsValid && !duration.isIndefinite && duration.isValid && !duration.isNegativeInfinity && !duration.isPositiveInfinity
    }
    
    if (durationIsValid)
    {
      let avItem = AVPlayerItem(asset: avAsset)
//      print("canPlayReverse -> \(avItem.canPlayReverse)")
//      print("canStepForward -> \(avItem.canStepForward)")
//      print("canStepBackward -> \(avItem.canStepBackward)")
//      print("canPlayFastForward -> \(avItem.canPlayFastForward)")
//      print("canPlayFastReverse -> \(avItem.canPlayFastReverse)")
//      print("canPlaySlowForward -> \(avItem.canPlaySlowForward)")
//      print("canPlaySlowReverse -> \(avItem.canPlaySlowReverse)")
      
      avItem.addObserver(self, forKeyPath: "tracks", options: NSKeyValueObservingOptions.new, context: nil)
      avItem.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
      let samplePlayer = AVPlayer(playerItem: avItem)
      samplePlayer.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.new, context: nil)
      samplePlayer.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
      samplePlayer.isClosedCaptionDisplayEnabled = true
      self.monitorView.controlsStyle = playerPrefs.playbackControlStyle == videoControlStyle.floating ? .floating : .inline
      self.monitorView.player = samplePlayer
      self.monitorView.showsFullScreenToggleButton = true
      self.monitorView.showsFrameSteppingButtons = !playerPrefs.playbackShowFastForwardControls
      self.monitorView.player?.seek(to: startTime)
//      print("number of views under avplayerview \(self.monitorView.subviews.count)")
      self.addPeriodicTimeObserver()
   }
    else {
      self.statusField.stringValue = "Invalid Time duration cannot work with"
    }
  }
  
//  /// Utility function that unpacks the file name and check that the file is exists
//  /// and is accessible.
//  /// - parameter fullFileName: path to the file
//  /// - returns : touple of a filemanager, status of files existence and the resolved path to file
//  func getFileManagerForFile( _ fullFileName : String) -> (FileManager, Bool, String)
//  {
//    var pathName : String
//    let fileMgr : FileManager = FileManager.default
//    if (debug) { print (fullFileName) }
//    
//    pathName = ""
//    if let checkIsURLFormat = URL.init(string: fullFileName)
//    {
//        pathName = checkIsURLFormat.path
//    }
//    else // assume file system format
//    {
//      pathName = fullFileName
//    }
//    let fileExists = fileMgr.fileExists(atPath: pathName)
//    return (fileMgr, fileExists, pathName)
//  }
  
  /// Common function to write the status field GUI entry to match
  /// the current user selection
  func setStatusFieldToCurrentSelection()
  {
    let arrayIndex = currentFile.indexOfSelectedItem
    self.statusField.stringValue = "file \(arrayIndex+1) of \(filelist.count)"
  }
  
  // MARK: - Player related functions
  
  func seekCompletedOK(_ isFinished:Bool)
  {
    if (!isFinished ) {
      if (debug) { print("Seek Canceled") }
    }
    else {
      if (debug) { print("Seek completed") }
      if (wasPlaying) {
        self.monitorView.player?.play()
      }
      suppressTimedUpdates = false
    }
  }
  
  
  
  /// Seek player by delta value in seconds.  Retains
  /// current paused or playing state
  
  func seekToSkip(_ skipDurationSeconds:Double)
  {
    let pts=Int64(skipDurationSeconds*Double(CutsTimeConst.PTS_TIMESCALE))
    wasPlaying = isPlaying
//    self.monitorView.player?.pause()
    let now = (self.monitorView.player?.currentTime())!
    let newtime = CMTimeAdd(now, CMTime(value: pts, timescale: CutsTimeConst.PTS_TIMESCALE))
    self.monitorView.player?.seek(to: newtime, completionHandler: seekCompletedOK)
//    if (wasPlaying) {
//      self.monitorView.player?.play()
//    }
  }
  
  /// Seek player to absolute cutMark position.  Retains
  /// current paused or playing state
  func seekPlayerToCutEntry(_ entry: CutEntry?)
  {
    selectCutTableEntry(entry)
  }
  
  /// Seek the video player to the timestamp associated with
  /// the cut file entry mark
  /// - parameter seekBarPos: the CutEntry which has an associated PTS
  func seekPlayerToMark(_ seekBarPos : CutEntry)
  {
    wasPlaying = isPlaying
    if (wasPlaying) {
      self.monitorView.player?.pause()
    }
    self.monitorView.player?.seek(to: CMTime(value: Int64(seekBarPos.cutPts), timescale: CutsTimeConst.PTS_TIMESCALE), toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimePositiveInfinity, completionHandler: seekCompletedOK)
  }
  
  /// Get the video players current position as a PTS value
  /// - returns: Player position current time converted into an Enigma2 scaled PTS value.
  /// the value does not related to the file PTS values unless the initial PTS value is
  /// zero.  That is, to determine a file related position, combine the returned value with
  /// first PTS value from the file.
  func playerPositionInPTS() -> UInt64
  {
    let playPosition = self.monitorView.player?.currentTime().convertScale(CutsTimeConst.PTS_TIMESCALE, method: CMTimeRoundingMethod.default)
    return UInt64((playPosition?.value)!)
  }
  
  private var timeObserverToken: Any?
  
  /// Highlight (without triggering selection actions) the cuttable entry that is
  /// before the given time into the recording in seconds.  This is providing the
  /// "table highlight tracks the playing recording" UI feedback
  /// - parameter currentTime: time offset in seconds into the recording
  
  func highlightCutTableEntryBefore(currentTime: Double)
  {
    if let (entry,index) = movie.cuts.entryBeforeTime(Double(currentTime))
    {
      let cutSecs = entry.asSeconds()
      if (debug) { print("returned cuts table index of \(index) for time \(cutSecs)") }
      if (index != cutsTable.selectedRow)
      {
        let currentSuppressState = suppressPlayerUpdate
        suppressPlayerUpdate = true
        selectCutTableEntry(entry)
        suppressPlayerUpdate = currentSuppressState
      }
    }
    else {
      if (debug) { print("?? no entry for \(currentTime)") }
    }
  }
  
  // from apple code sample
  func addPeriodicTimeObserver() {
    let debug = false
    // Invoke callback every second
    let interval = CMTime(seconds: 1.0,
                          preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    // Queue on which to invoke the callback
    let mainQueue = DispatchQueue.main
    // Add time observer - note that this may get multiple invocations for the SAME time
    timeObserverToken =
      self.monitorView.player?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) {
        [weak self] time in
        // update player transport UI
        // check cut markers and skips over OUT -> IN sections
        let currentCMTime =  self?.monitorView.player?.currentTime()
//          print("currentRate is  \(self?.monitorView.player?.rate)")
        
        let currentTime = Float(CMTimeGetSeconds((self?.monitorView.player?.currentTime())!))
        if (debug)  { print("Saw callback start at \(currentTime)") }
        guard (self?.lastPeriodicCallBackTime != currentTime && self?.suppressTimedUpdates == false ) else {
          // do nothing
          if (debug) { print("skipping callback at \(currentTime)") }
          if (self?.lastPeriodicCallBackTime == currentTime && debug ) {print("duplicate time")}
          if (self?.suppressTimedUpdates == true && debug ) {print("timed updates suppressed")}
          return
        }
        self?.lastPeriodicCallBackTime = currentTime
        let hmsString = CutEntry.hhMMssFromSeconds(Double(currentTime))
        self?.programDuration.stringValue = hmsString + "/" + CutEntry.hhMMssFromSeconds((self?.programDurationInSecs)!)
        if (self?.honourOutInMarks)! {
          if let afterAdTime = self?.movie.cuts.programTimeAfter(currentCMTime!)
          {
            // ensure we seek AFTER the current time, ie don't seek backwards!!
            if (afterAdTime.seconds > (currentCMTime?.seconds)!)
            {
              self?.monitorView.player?.seek(to: afterAdTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimePositiveInfinity)
            }
            if (debug) { print("Will Skip to time \(afterAdTime.seconds)") }
            self?.highlightCutTableEntryBefore(currentTime: Double(afterAdTime.seconds))
//            if let (entry,index) = self?.cuts.entryBeforeTime(Double(afterAdTime.seconds))
//            {
//              if (index != self?.cutsTable.selectedRow) {  // ensure double seek does not happen
//                // due to seek occuring with row selection of table
//                let currentSuppressState = self?.suppressPlayerUpdate
//                self?.suppressPlayerUpdate = true
//                self?.selectCutTableEntry(entry)
//                self?.suppressPlayerUpdate = currentSuppressState!
//              }
//            }
          }
          else {
            self?.highlightCutTableEntryBefore(currentTime: Double(currentTime))
          }
        }
        else {
          self?.highlightCutTableEntryBefore(currentTime: Double(currentTime))
//          if let (entry,index) = self?.cuts.entryBeforeTime(Double(currentTime))
//          {
//            let cutSecs = entry.asSeconds()
//            if (debug) { print("returned cuts table index of \(index) for time \(cutSecs)") }
//            if (index != self?.cutsTable.selectedRow)
//            {
//              let currentSuppressState = self?.suppressPlayerUpdate
//              self?.suppressPlayerUpdate = true
//              self?.selectCutTableEntry(entry)
//              self?.suppressPlayerUpdate = currentSuppressState!
//            }
//          }
//          else {
//            if (debug) { print("?? failed to find entry for \(currentTime)") }
//          }
        }
        if (debug) { print("Saw callback end for \(currentTime)") }
//        }
    }
  }
  
//  func sampleNavigationMarkerGroup() -> AVNavigationMarkersGroup
//  {
//    let group = AVNavigationMarkersGroup(title: "Announcements", timedNavigationMarkers: [
//      timedMetaDataGroupWithTitle("Apple Watch", startTime: 90, endTime: 917),
//      timedMetaDataGroupWithTitle("iPad Pro", startTime: 917, endTime: 1691),
//      timedMetaDataGroupWithTitle("Apple Pencil", startTime: 1691, endTime: 3105),
//      timedMetaDataGroupWithTitle("Apple TV", startTime: 3105, endTime: 4968),
//      timedMetaDataGroupWithTitle("iPhone", startTime: 4968, endTime: 7328)
//      ])
//  }
  
  // MARK: - Movie Cutting functions
  
  /// Callback function for movie cutting Operations
  
  func movieCuttingFinished(_ resultMessage: String, movieAtPath: String)
  {
    if let movieIndex = self.filelist.index(of: movieAtPath) {
      setDropDownColourForIndex(movieIndex)
      changeFile(movieIndex)
    }
    self.statusField.title = resultMessage
    if (debug) {
      print("Saw callback from movie cutting opeations queue")
    }
  }
  
  /// Look at user preferences and  collect the
  /// required information interactively from the user
  func getCutsCommandLineArgs() -> [String]
  {
    // string args wrapped in " for remote usage
    // double quotes are removed for local usage
    // TODO: this is just plain bad....
    var localPVRIndex = 0
    var args = [String]()
    if (isRemote) { // pick the global
      localPVRIndex = pvrIndex
    }
    if (generalPrefs.systemConfig.pvrSettings[localPVRIndex].cutReplace == CheckMarkState.checked) {
      args.append(mcutConsts.replaceSwitch)
    }
    if (generalPrefs.systemConfig.pvrSettings[localPVRIndex].cutDescription == CheckMarkState.checked)
    {
      args.append((mcutConsts.descriptionSwitch))
      let programDescription = ViewController.getString(title: "Description Entry", question: "Enter new Program Description", defaultValue: "-")
      args.append(programDescription)
    }
    if (generalPrefs.systemConfig.pvrSettings[localPVRIndex].cutRenamePrograme == CheckMarkState.checked)
    {
      args.append((mcutConsts.nameSwitch ))
      let programName = ViewController.getString(title: "Program Title", question: "Enter new Program Title", defaultValue: "-")
      args.append(programName)
    }
    if (generalPrefs.systemConfig.pvrSettings[localPVRIndex].cutOutputFile == CheckMarkState.checked)
    {
      var programFileName: String
      args.append((mcutConsts.outputSwitch ))
      let basename = filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
      if let fullPathName = basename.replacingOccurrences(of: "file://",
                                                          with: "").removingPercentEncoding
      {
        programFileName = ViewController.getString(title: "Recording File", question: "Enter new Program File", defaultValue: fullPathName)
      }
      else {
        programFileName = filelist[filelistIndex]
      }
      args.append(programFileName)
    }
    return args
  }
  
//  /// Add to global background queue
//  
//  func cutMovieInBackground(_ pathToMovieToCut: String, title movieTitle: String, cutter: MovieCutting)
//  {
//    let mcutCommandArgs = getCutsCommandLineArgs()
//
//    DispatchQueue.global(qos: .background).async { [unowned self] in
//      print("This is run on the background queue")
//      let cuttingResult = cutter.movieCutOne(moviePath: pathToMovieToCut, commandArgs: mcutCommandArgs)
//      DispatchQueue.main.async {
////        let now = Date()
////        let delta = now.timeIntervalSince(self.startDate)
////        print("Time in cutting block \(delta)")
//        print("This is run on the main queue, after the previous code in outer block")
//        self.statusField.stringValue = cuttingResult.message
//        self.removeFromCutToolTip(message: movieTitle)
//        // acquire index of program, in case environment has changed whilst cutting the recording
//        // only change colour coding on SUCCESS
//        if let index = self.indexOfMovie(of: pathToMovieToCut) {
//            if (cuttingResult.result == 0)  {
//              self.setDropDownColourForIndex(index)
//            }
//            self.changeFile(index)
//            self.statusField.stringValue = cuttingResult.message
//            self.cutButton.isEnabled = true
//        }
//      }
//    }
//  }
  
  /// Create Operation for specific movie and add to Cutting Queue to related pvr
  /// - parameter URLToMovieToCut: full path % encoded url of recording file cuts file
  func cutMovie(_ URLToMovieToCut:String)
  {
    let shortTitle = ViewController.programDateTitleFrom(movieURLPath: URLToMovieToCut)
    let startMessage = mcutConsts.started + " " + shortTitle
    let waitMessage = mcutConsts.waiting + " " + shortTitle
    if let cutterQ = preferences.cuttingQueue(withTitle: generalPrefs.systemConfig.pvrSettings[pvrIndex].title)
    {
      let cutStartBlock : MovieCutStartBlock = { shortTitle in
        self.replaceCutToolTip(oldMessage: waitMessage, with: startMessage)
        cutterQ.jobStarted(moviePath: URLToMovieToCut)
      }
      let cutCompletionBlock : MovieCutCompletionBlock = { resultMessage, statusValue, wasCancelled in
        self.statusField.stringValue = resultMessage
        self.cutButton.isEnabled = true
        if (wasCancelled) {
          cutterQ.jobCancelled(moviePath: URLToMovieToCut, result: statusValue, resultMessage: resultMessage)
        }
        else {
          cutterQ.jobCompleted(moviePath: URLToMovieToCut, result: statusValue, resultMessage: resultMessage)
          if (statusValue == 0)  {
            if let index = self.indexOfMovie(of: URLToMovieToCut) {
              self.setDropDownColourForIndex(index)
              // acquire index of program, in case environment has changed whilst cutting the recording
              // only change colour coding on SUCCESS
              if let index = self.indexOfMovie(of: URLToMovieToCut) {
                if (statusValue == 0)  {
                  self.setDropDownColourForIndex(index)
                  (self.currentFile.item(at: index))?.isEnabled = true
                }
              }
            }
          }
          let successString = (statusValue == 0) ? mcutConsts.cutOK : mcutConsts.cutFailed
          let completedMessage = "\(successString) \(shortTitle)"
          self.replaceCutToolTip(oldMessage: startMessage, with: completedMessage)
        }
      }
      let mcutCommandArgs = getCutsCommandLineArgs()
      systemSetup.mcutCommandArgs = mcutCommandArgs

      let movieCutter = MovieCuttingOperation(movieToBeCutPath: URLToMovieToCut,
                                              sysConfig: systemSetup,
                                              pvrIndex: pvrIndex,
                                              isRemote: isRemote,
                                              onCompletion: cutCompletionBlock,
                                              onStart: cutStartBlock)
      addToCutToolTip(message: waitMessage)
      cutterQ.jobAdd(op: movieCutter)
      let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
      print("\(timestamp): Added  \(shortTitle) to Queue \(cutterQ.queue.name!)")
    }
  }
  
//  func queueForPath(URLPath: String) -> CuttingQueue?
//  {
//    // get the title of the PVR which as the matching root path
//    guard let diskPathName = URLPath.replacingOccurrences(of: "file://",
//                                                            with: "").removingPercentEncoding else {
//                                                              return nil
//    }
//    
//    for entry in self.systemSetup.pvrSettings
//    {
//      if diskPathName.contains(entry.cutLocalMountRoot) {
//        // we have a winner
//        let queue = preferences.cuttingQueue(withTitle: entry.title)
//        return queue
//      }
//    }
//    return nil
//  }
//  
  /// Get the queue associated with the configuration index
  func queueForPVR(index: Int) -> CuttingQueue?
  {
    // bounds check
    guard (systemSetup.pvrSettings.count > 0 && index >= 0 && index < systemSetup.pvrSettings.count) else { return nil }
    let queue = preferences.cuttingQueue(withTitle: systemSetup.pvrSettings[index].title)
    return queue
  }
  
  /// Append string to cut toolTip button
  func addToCutToolTip(message: String) {
    if (cutButton.toolTip != nil) {
      cutButton.toolTip = cutButton.toolTip! + "\n" + message
    }
    else {
      cutButton.toolTip = message
    }
  }
  
  /// Remove string from toolTip button
  /// There is  potential race condition in here but hardly seems worth the effort
  /// to make atomic.  Detail is ensuring that both "title" or "\ntitle" are removed from the tooltip.

  func removeFromCutToolTip(message: String)
  {
    if let currentTip = cutButton.toolTip {
      // remove "blah\n" or "blah". One or the other will occur
      var newTip = currentTip.replacingOccurrences(of: "\(message)\n", with: "")
      newTip = newTip.replacingOccurrences(of: message, with: "")
      newTip = newTip.replacingOccurrences(of: "\n\n", with: "\n")
      cutButton.toolTip = (newTip == "") ? nil : newTip
    }
  }
  /// Replace string in the tooltip.
  /// If it does not contain the old message then do nothing
  /// - parameter oldMessage : message to match
  /// - parameter newMessage : replacement text
  func replaceCutToolTip(oldMessage: String, with newMessage:String)
  {
    if let currentTip = cutButton.toolTip {
      if currentTip.contains(oldMessage) {
        let newTip = currentTip.replacingOccurrences(of: oldMessage, with: newMessage)
        cutButton.toolTip = newTip
      }
    }
  }
  
  /// Method used in mainQueue callback to ensure that "current" filelist is used not
  /// a closure "captured" version
  func indexOfMovie(of movieURLEntry: String) -> Int?
  {
    return filelist.index(of: movieURLEntry)
  }
  
//  /// perform a live "while you wait" cut.  Based on contents of Advanced
//  /// preferences dialog
//  func movieCutAndWait()
//  {
//    // FIXME: add spinner
//    // FIXME: adjust constraints of status field to have a maximum with and scroll
////    startDate = Date()
//    let movieTitle = (currentFile.selectedItem?.title)!
//    let moviePathName = filelist[filelistIndex]
//    addToCutToolTip(message: movieTitle)
//    let mcutSystem = MovieCutting.isRemote(pathName: filelist[filelistIndex]) ? "remotely" : "locally"
//    let messageString = String(format: mcutConsts.pleaseWaitMessage , MovieCutting.programTitleFrom(movieURLPath: moviePathName), mcutSystem)
//    print(messageString)
//    self.statusField.stringValue = messageString
//    actionsSetEnabled(false)
//    let movieCutter = MovieCutting(systemConfig: systemSetup, genPrefs: generalPrefs)
//    cutMovieInBackground(moviePathName, title: movieTitle, cutter: movieCutter)
//  }
  
  
  // MARK: - TableView delegate, datasource and table related functions
  
  // Get the view related to selected cell and populated the data value
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    var cellContent : String
    let cutEntry = movie.cuts.entry(at: row)
    if tableColumn?.identifier == StringsCuts.TABLE_TIME_COLUMN
    {
      if (self.movie.cuts.count>0)
      {
        cellContent = CutEntry.timeTextFromPTS((cutEntry?.cutPts)!)
      }
      else {
       cellContent = "?"
      }
    }
    else if tableColumn?.identifier == StringsCuts.TABLE_TYPE_COLUMN
    {
      cellContent = "??"
      if (self.movie.cuts.count>0)
      {
        if let markValue = cutEntry?.cutType, let mark = MARK_TYPE(rawValue: markValue)
        {
          cellContent = (mark.description())
        }
      }
    }
    else {
       cellContent = "???"
    }
    let result : NSTableCellView  = tableView.make(withIdentifier: tableColumn!.identifier, owner: self)
      as! NSTableCellView
    result.textField?.stringValue = cellContent
    return result
  }
  
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    return self.movie.cuts.count
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    let selectedRow = cutsTable.selectedRow
    // seek to associated cutEntry
    guard (selectedRow>=0 && selectedRow<movie.cuts.count) else
    {
      // out of bounds, silently ignor
      self.suppressTimedUpdates = false
      return
    }
    if let entry = movie.cuts.entry(at: selectedRow) {
      
      if (!suppressPlayerUpdate) {
        if (debug) { print("Seeking to \(entry.asSeconds())") }
        seekPlayerToMark(entry)
        self.suppressTimedUpdates = false
     }
    }
  }

/// "swipe" action function to delete rows from table.
/// Updates model and GUI
  func rowDelete(_ action:NSTableViewRowAction, indexPath:Int)
  {
    if let cutEntry = self.movie.cuts.entry(at: indexPath)  {
      _ = movie.cuts.removeEntry(cutEntry)
      self.cutsTable.reloadData()
      cuttable = movie.cuts.isCuttable
    }
  }
  
/// register swipe actions
  
  func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableRowActionEdge) -> [NSTableViewRowAction] {
    if edge == NSTableRowActionEdge.trailing {
      let delete = NSTableViewRowAction(style: NSTableViewRowActionStyle.destructive, title: "Delete", handler: rowDelete)
      return [delete]
    }
    return [NSTableViewRowAction]()
  }
  
  // Delegate function on row addition.
  // This delegate changes the background colour based on the mark type
  
  func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
    // try to change the color of the rowView
    var colour = NSColor.white
    // bounds checking
    guard row >= 0 && row < self.movie.cuts.count  else { return }
    if let cutEntry = movie.cuts.entry(at: row),  let markType = MARK_TYPE(rawValue: cutEntry.cutType)
    {
      switch markType
      {
        case .IN:
          colour = NSColor.green
        case .OUT:
          colour = NSColor.red
        case .LASTPLAY:
          colour = NSColor.blue
        case .BOOKMARK:
          colour = NSColor.yellow
      }
    }
    rowView.backgroundColor = colour.withAlphaComponent(0.75)
  }
  
  // beware only called on mouse clicks not keyboard
  func tableViewSelectionIsChanging(_ notification: Notification) {
    self.suppressTimedUpdates = true
    if (debug) { print("Saw tableViewSelectionIsChanging change") }
  }
  
  func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
    // user clicked in table, suppress timed updates
    self.suppressTimedUpdates = true
    if (debug) { print("Saw column did Click") }
    
  }
  
  /// Given a valid cut entry, find it and select the row in
  /// the cuts table display.  Do nothing on a nil entry or 
  /// entry not found in array
  /// - parameter cutEntry: pts and type structure
  
  func selectCutTableEntry(_ cutEntry: CutEntry?)
  {
    if (cutEntry != nil) {
      if let indexOfEntry = self.movie.cuts.index(of: cutEntry!)
      {
        self.cutsTable.scrollRowToVisible(indexOfEntry)
        self.cutsTable.selectRowIndexes(IndexSet(integer: indexOfEntry), byExtendingSelection: false)
      }
    }
  }
  
  func updateTableGUIEntry(_ cutEntry: CutEntry?)
  {
    self.cutsTable.reloadData()
    selectCutTableEntry(cutEntry)
  }
  
  // MARK: - Menu file handling
  
  @IBAction  func openDocument(_ sender: AnyObject)
  {
    if (debug) { print("Saw Open document call") }
    let myFileDialog: NSOpenPanel = NSOpenPanel()
    myFileDialog.canChooseFiles = true
    myFileDialog.allowsMultipleSelection = false
    myFileDialog.canChooseDirectories = false
    myFileDialog.title = "Select cuts file"
    myFileDialog.allowedFileTypes=["cuts"]
    myFileDialog.runModal()
    
    if let fileURL = myFileDialog.url
    {
      // returns full path encoded with percentEncoding
      if (debug)  { print("returned name is \(fileURL)") }
      appendSingleFileURLToListAndSelect(fileURL)
    }
  }

  // MARK: - utility functions
  
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

  // MARK: - cutMark management functions
  // TODO: develop more robust bulk addition for multiple in/out pairs
  // currently fails to create bookmarks before first in and after last out
  // when recording is cut but with ads marked out
  @IBAction func clearBookMarks(_ send: AnyObject)
  {
    clearAllOfType(.BOOKMARK)
  }
  
  @IBAction func clearLastPlayMark(_ send: AnyObject)
  {
    clearAllOfType(.LASTPLAY)
  }
  
  /// Clears the cuts object of all IN and OUT marks
  /// - parameter sender: typically menu Item or Button, not used
  @IBAction func clearCutMarks(_ sender: AnyObject)
  {
    clearCutsOfTypes([.IN, .OUT])
  }
  
  /// Menu item action
  
  @IBAction func add10Bookmarks(_ sender: AnyObject)
  {
    suppressPlayerUpdate = true
    let firstPTS =  (movie.cuts.count != 0) ? ((movie.cuts.first!.cutType == MARK_TYPE.IN.rawValue) ? movie.cuts.first!.cutPts : PtsType(0)) : PtsType(0)
    if (preferences.generalPreference().markMode == MARK_MODE.FIXED_SPACING_OF_MARKS) {
      movie.cuts.addFixedTimeBookmarks(interval: preferences.generalPreference().spacingModeDurationOfMarks,
                                 firstInCutPts: firstPTS,
                                 lastOutCutPts: lastOutCutPTS)
    }
    else {
      movie.cuts.addPercentageBookMarks(preferences.generalPreference().countModeNumberOfMarks,
                                  firstInCutPts: firstPTS,
                                  lastOutCutPts: lastOutCutPTS)
    }
    suppressPlayerUpdate = false
    cutsTable.reloadData()
    seekPlayerToMark(firstVideoPosition())
  }
  
  @IBAction func clearAllMarks(_ sender: AnyObject)
  {
    clearCutsOfTypes([.IN, .OUT, .LASTPLAY, .BOOKMARK])
  }
  
  func clearAllOfType(_ markType: MARK_TYPE)
  {
    suppressPlayerUpdate = true
    movie.cuts.removeEntriesOfType(markType)
    cutsTable.reloadData()
    suppressPlayerUpdate = false
  }
  
  func clearCutsOfTypes(_ markArray: [MARK_TYPE])
  {
    suppressPlayerUpdate = true
    for mark in markArray
    {
      clearAllOfType(mark)
    }
    suppressPlayerUpdate = false

  }
  
  /// 10% button action
  /// parameter sender: expect NSButton, but don't care, it is unused
  @IBAction func addBookMarkSet(_ sender: AnyObject)
  {
    suppressPlayerUpdate = true
    let firstPTS =  (movie.cuts.count != 0) ? ((movie.cuts.first!.cutType == MARK_TYPE.IN.rawValue) ? movie.cuts.first!.cutPts : PtsType(0)) : PtsType(0)
    movie.cuts.addPercentageBookMarks(firstInCutPts: firstPTS, lastOutCutPts: lastOutCutPTS)
    cutsTable.reloadData()
    suppressPlayerUpdate = false
    seekPlayerToMark(firstVideoPosition())
  }
  
  /// If present, remove the matching entry from the cut list.
  /// Update GUI on success
  func removeEntry(_ cutEntry: CutEntry)  {
    if (movie.cuts.removeEntry(cutEntry) )
    {
      cutsTable.reloadData()
      cuttable = movie.cuts.isCuttable
    }
  }
  
  @IBAction func addMark(sender: NSButton) {
    let markType = marksDictionary[sender.identifier!]
    let now = self.playerPositionInPTS()
    let mark = CutEntry(cutPts: now, cutType: markType!.rawValue)
    movie.cuts.addEntry(mark)
    updateTableGUIEntry(mark)

    if (markType == .IN || markType == .OUT)  {
      cuttable = movie.cuts.isCuttable
    }
  }
  
  /// Find the earliest position in the video.  This should be;
  /// the first IN mark not preceed by an out Mark, 
  /// failing that, if there are <= 3 bookmarks,
  /// use the first bookmark - most likely an unedited file.
  /// Otherwise use then use the initial file position
  /// which may have to be fabricated if it does not exist.
  
  func firstVideoPosition() -> CutEntry
  {
    if let firstInEntry = self.movie.cuts.firstInCutMark {
      if (self.movie.cuts.index(of: firstInEntry) == 0) {
        return firstInEntry
      }
      else
      {
        if let firstOutEntry = self.movie.cuts.firstOutCutMark
        {
          if (self.movie.cuts.index(of: firstInEntry)! < self.movie.cuts.index(of: firstOutEntry)!) {
            return firstInEntry
          }
          else {
            return CutEntry.InZero
          }
        }
      }
    }
    // if there are a set of bookmarks or no bookmarks
    if self.movie.cuts.count > 3 || self.movie.cuts.count == 0
    {
      return CutEntry.InZero
    }
    else // >0 && <= 2 bookmarks pick the first bookmark
    {
      if let entry = self.movie.cuts.first {
        return entry
      }
      else { // should be technically impossible, however, belt and braces
        return CutEntry.InZero
      }
    }
  }
  
  // MARK: OS utility functions
  
//  /// Binary data loader
//  /// - parameter filename: fully defined file path
//  /// - returns : raw arbitrary data
//  
//  func loadRawDataFrom(file filename:String) -> Data?
//  {
//    var data:Data?
//    
//    let (fileMgr, foundFile, fullFileName) = Recording.getFileManagerForFile(filename)
//    
//    if (foundFile)
//    {
//      data = fileMgr.contents(atPath: fullFileName)
//      if (debug)  {
//        print("Found file ")
//        print("Found file of \((data?.count))! size")
//      }
//      // not interested in empty files.... may as well be missing
//      if (data?.count == 0 ) {
//        data = nil
//      }
//    }
//    return data
//  }
  
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
  
  func getBestDurationInSeconds( _ meta: MetaData?, eit: EITInfo?, ap: AccessPoints? , player: AVPlayer?) -> Double
  {
    // get the program duration from all sources and choose the least of the
    // non-zero values
    // It *looks* as though the Execute Cuts plugin does not update metaData or eit file
    // all durations in seconds
    var metaDuration: Double = 0.0
    var eitDuration: Double = 0.0
    var playerDuration: Double = 0.0
    var accessPointsDuration: Double = 0.0
    var bestDuration: Double = 0.0
    // eventinfo table
    if let eitInfo = eit {
      if (eitInfo.eit.Duration != "00:00:00" && eitInfo.eit.Duration != "") {
//        self.programDuration.stringValue = eitInfo.eit.Duration
        let timeParts = eitInfo.eit.Duration.components(separatedBy: ":")
        eitDuration = Double(timeParts[0])!*3600.0 + Double(timeParts[1])!*60.0+Double(timeParts[2])!
      }
    }
    // query the player if it exists
    if player != nil {
      playerDuration = CMTimeGetSeconds((self.monitorView.player?.currentItem?.duration)!)
    }
    
    // metaData
    if let metadata = meta
    {
      if (metadata.duration != "0" && metadata.duration != "")
      {  // meta data looks OK, use it for duration display
        metaDuration = Double(metadata.duration)!*CutsTimeConst.PTS_DURATION
      }
    }
    
    // accessPoints 
    if let apdata = ap {
      accessPointsDuration = apdata.durationInSecs()
    }
    if (debug) {
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
