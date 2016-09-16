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
  static let TABLE_TIME_COLUMN = "Time"
  static let TABLE_TYPE_COLUMN = "Type"
  static let FILE_SAVE_FAILED = "Failed to save file"
  static let STARTED_SEARCH = "Started Search"
  static let CANCELLED_BY_USER = "Cancelled by User"
  static let DERIVING_PROGRAM_STATUS = "Determining Program State"
  static let COLOUR_CODING_CANCELLED = "Colour Coding Cancelled"
}

struct ConstsCuts {
  static let filelistSize = 200  // starting size for list of files
  static let CUTS_SUFFIX = ".ts.cuts"
  static let META_SUFFIX = ".ts.meta"
  static let EIT_SUFFIX = ".eit"
  static let TS_SUFFIX = ".ts"
  static let AP_SUFFIX = ".ts.ap"
}

// lookup code for tags of gui buttons

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
  static let remoteLogin = "root@beyonwizT4.local"
  static let localSshPath = "/usr/bin/ssh"
}

let skipsDidChange = "CutsPreferenceControllerSkipsDidChange"
let sortDidChange = "SortPreferenceControllerSortDidChange"
let generalDidChange = "GeneralPreferencesControllerGeneralDidChange"
let fileOpenDidChange = "FileToOpenFromMenuDidChange"

/// Pair of Strings touple of diskURL and the extracted recording program name
struct namePair {
  var diskURL: String = ""
  var programeName: String = ""
}

/// structure to hold configuration parameters for deciding colouring of
/// list of programs in GUI
struct fileColourParameters {
  static let BOOKMARK_THRESHOLD_COUNT = 5
  static let PROGRAM_LENGTH_THRESHOLD = 900.0    // 15 minute or less programs do not need cutting
  static let allDoneColor = NSColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)
  static let noBookmarksColor = NSColor(red: 0.5, green: 0.2, blue: 0.2, alpha: 1.0)
  static let readyToCutColor = NSColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1.0)
}

/// Pair of String and Double for association with a GUI "skip" button.
/// The String is the text used on the button and the double is the skip
/// duration in seconds

struct skipPair {
  var display : String = ""
  var value : Double = 0.0
}

struct sortingPreferences {
  var isAscending: Bool = true
  var sortBy: String = ""
}

enum MARK_MODE: Int {
  case FIXED_COUNT_OF_MARKS
  case FIXED_SPACING_OF_MARKS
}

let kHyphen = " - "

struct generalPreferences {
  var autoWrite: Bool = true
  var markMode = MARK_MODE.FIXED_COUNT_OF_MARKS
  var countModeNumberOfMarks = 10         // 10 equally spaced bookmarks
  var spacingModeDurationOfMarks = 180    // 180 seconds spaced bookmarks
  // cuts application
  var cutReplace = NSOnState
  var cutRenamePrograme = NSOffState
  var cutOutputFile = NSOffState
  var cutDescription = NSOffState
  var cutProgramLocalPath = mcutConsts.mcutProgramLocal
  var cutProgramRemotePath = mcutConsts.mcutProgramRemote
  var cutLocalMountRoot = mcutConsts.localMount
  var cutRemoteExport = mcutConsts.remoteExportPath
}

/// Property that contains the user preferences for
/// the skip buttons.  Organized to mirror screen representation
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

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {
  
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
  
  let debug = false
  var filelist: [String] = []
  var namelist: [String] = []
  var filelistIndex : Int {
    set {
      setStatusFieldToCurrentSelection()
    }
    get {
      return self.currentFile.indexOfSelectedItem
    }
  }
  
  /// Index into the popup captured during the last MouseDownEvent
  var mouseDownPopUpIndex : Int?
  
  var lastfileIndex : Int = 0
  var fileWorkingName : String = ""
  var videoDurationFromPlayer: Double = 0.0
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
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  
  var finderOperationsQueue : OperationQueue = OperationQueue()
  var currentFileColouringBlock : BlockOperation?
  var cuts = CutsFile()
  var cutsModified: Bool = false
  var eit = EITInfo()
  var metadata = MetaData()
  var accessPointData : AccessPoints?
  
  var skips = skipPreferences()
  var sortPrefs = sortingPreferences()
  var generalPrefs = generalPreferences()
  /// Controls if avPlayer is dynamically synced to current cut position selection.
  /// This should action should be suppressed during bulk operations.  If not, then
  /// the player will attempt to seek to a new frame each time the table highlight
  /// is changed.  For example, when the user adds 10 bookmarks, the player jumps
  /// to each new bookmark as if the user has just selected it in the table.
  var suppressPlayerUpdate = false
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    
    previousButton.isEnabled = false
    nextButton.isEnabled = false
    fileWorkingName = StringsCuts.NO_FILE_CHOOSEN
    statusField.stringValue = StringsCuts.NO_DIRECTORY_SELECTED
//    currentFile.stringValue = StringsCuts.NO_FILE_CHOOSEN
    currentFile.removeAllItems()
    currentFile.addItem(withTitle: StringsCuts.NO_FILE_CHOOSEN)
    currentFile.selectItem(at: 0)
    cutsTable.dataSource = self
    cutsTable.delegate = self
    actionsSetEnabled(false)
    skips = preferences.skipPreference()
    sortPrefs = preferences.sortPreference()
    
//    let application = NSApplication.sharedApplication()
//    application.addObserver(self, forKeyPath: "skipsChange", options: NSKeyValueObservingOptions.New, context: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(skipsChange(_:)), name: NSNotification.Name(rawValue: skipsDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(sortChange(_:)), name: NSNotification.Name(rawValue: sortDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(generalChange(_:)), name: NSNotification.Name(rawValue: generalDidChange), object: nil )
    
    NotificationCenter.default.addObserver(self, selector: #selector(fileToOpenChange(_:)), name: NSNotification.Name(rawValue: fileOpenDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(fileSelectPopUpChange(_:)), name: NSNotification.Name.NSPopUpButtonWillPopUp, object: nil )
    
    self.progressBar.controlTint = NSControlTint.clearControlTint
    
//    reconstructScAp.do_movie("/Users/alanf/Movies/20160324 1850 - ABC - Clarke And Dawe.ts")
//    reconstructScAp.readFFMeta("/Users/alanf/Movies/20160324 1850 - ABC - Clarke And Dawe.ts.ap")
//    reconstructScAp.pyProcessScAp("/Users/alanf/Movies/20160324 1850 - ABC - Clarke And Dawe.ts")
  }
  
  override func viewWillDisappear() {
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
    // Fiddly bit here
    // To avoid recreating the popupbutton attributed strings (costly)
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
  
  /// Observer function to handle the "general" changes that are made
  /// during changes in the preferences dialog
  
  func generalChange(_ notification: Notification)
  {
    // get the changed general settings and update the gui to match
    self.generalPrefs = preferences.generalPreference()
    // now update the GUI
//    if (filelist.count > 0) {
//      // save current item
//      let savedDiskURL = filelist[filelistIndex]
//      
//      sortNames()
//      
//      filelistIndex = filelist.indexOf(savedDiskURL)!
//      
//      self.currentFile.removeAllItems()
//      self.currentFile.addItemsWithTitles(namelist)
//      setPrevNextButtonState(filelistIndex)
//      changeFile(filelistIndex)
//    }
    
  }
  
  /// Observer function that responds to the selection of
  /// a single file (rather than a directory) to be used.
  /// Notitication has filename is the notification "object"
  func fileToOpenChange(_ notification: Notification)
  {
    let filename = notification.object as! String
    if (appendSingleFileToListAndSelect(filename))
    {
      print("failed")
    }
  }
  
  /// Query the PVR (or directory) for a recursive count of the files with xxx extension.
  /// Written to do a external shell query and then process the resulting message
  /// eg. countFilesWithSuffix(".ts", "/hdd/media/movie")
  /// Written to support sizing of progress bar for background tasks
  /// If remote query fails for any reason, function returns default value of 100
  
  func countFilesWithSuffix(_ fileSuffix: String, belowPath: String) -> Int
  {
    var fileCount = 100
    var searchPath: String
    // use a task to get a count of the files in the directory
    // this does pick up current recordings, but we only later look for "*.cuts" of finished recordings
    // so no big deal, this is just the quickest sizing that I can think of for setting up a progress bar
    // CLI specifics are for Enigma2 BusyBox
    let fileCountTask = Process()
    let outPipe = Pipe()
    if (belowPath.contains("Harddisk")) {
      searchPath = belowPath.replacingOccurrences(of: "/Volumes/Harddisk", with: "/media/hdd")
      fileCountTask.launchPath = "/usr/bin/ssh"
      fileCountTask.arguments = ["root@beyonwizt4.local", "/usr/bin/find \"\(searchPath)\" -regex \"^.*\\\(fileSuffix)$\" | wc -l"]
   }
    else {
      fileCountTask.launchPath = "/bin/sh"
      fileCountTask.arguments = ["-c", "/usr/bin/find \"\(belowPath)\" -regex \"^.*\\\(fileSuffix)$\" | wc -l"]
      searchPath = belowPath
    }
    fileCountTask.standardOutput = outPipe
    fileCountTask.launch()
    let handle = outPipe.fileHandleForReading
    let data = handle.readDataToEndOfFile()
    if let resultString = String(data: data, encoding: String.Encoding.utf8)
    {
      // trim to just the text
      let digitString = resultString.trimmingCharacters(in: CharacterSet(charactersIn: " \n"))
      fileCount = Int(digitString)!
    }
    return fileCount
  }
  
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
  
  func flushPendingChangesForFileIndex(_ index: Int)
  {
    var proceedWithWrite = true
    if (cutsModified) {
      if (!generalPrefs.autoWrite) {
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
      
      if (proceedWithWrite) {
        // rewrite cuts file
        let (fileMgr, found, fullFileName) = getFileManagerForFile(filelist[index])
        if (found) {
          self.cuts.saveCutsToFile(fullFileName, using: fileMgr)
          setDropDownColourForIndex(index)
          cutsModified = false
        }
        else {
          self.statusField.stringValue = StringsCuts.FILE_SAVE_FAILED
          return
        }
      }
    }
  }
  
  
//  /// Flush any pending changes back to the file system if
//  /// there are any.
//  
//  func flushPendingChanges()
//  {
//    var proceedWithWrite = true
//    if (cutsModified) {
//      if (!generalPrefs.autoWrite) {
//        // pop up a modal dialog to confirm overwrite of cuts file
//        let overWriteDialog = NSAlert()
//        overWriteDialog.alertStyle = NSAlertStyle.CriticalAlertStyle
//        overWriteDialog.informativeText = "Will overwrite the \(ConstsCuts.CUTS_SUFFIX) file"
//        overWriteDialog.window.title = "Save File"
//        let programname = self.currentFile.itemAtIndex(lastfileIndex)!.title.stringByReplacingOccurrencesOfString(ConstsCuts.CUTS_SUFFIX, withString: "")
//        overWriteDialog.messageText = "OK to overwrite file \n\(programname)"
//        overWriteDialog.addButtonWithTitle("OK")
//        overWriteDialog.addButtonWithTitle("Cancel")
//        
//        let result = overWriteDialog.runModal()
//        proceedWithWrite = result == NSAlertFirstButtonReturn
//      }
//      
//      if (proceedWithWrite) {
//        // rewrite cuts file
//        let (fileMgr, found, fullFileName) = getFileManagerForFile(filelist[lastfileIndex])
//        if (found) {
//          self.cuts.saveCutsToFile(fullFileName, using: fileMgr)
//          setDropDownColourForIndex(lastfileIndex)
//          cutsModified = false
//        }
//        else {
//          self.statusField.stringValue = StringsCuts.FILE_SAVE_FAILED
//          return
//        }
//      }
//    }
//  }
  
  
  /// Change the selected file to
  /// the one corrensponding to the given index.  Open the
  /// file, extract various information from the related files
  /// and update the GUI to match
  /// - parameter arrayIndex: index in to the array of recording file URLs
  ///
  func changeFile(_ arrayIndex: Int)
  {
    var startTime : CMTime
    
    flushPendingChangesForFileIndex(lastfileIndex)

    //  clean out the GUI and context for the next file
    self.monitorView.player?.cancelPendingPrerolls()
    self.monitorView.player?.currentItem?.cancelPendingSeeks()
    resetGUI()
    resetCurrentModel()
    setStatusFieldToCurrentSelection()
    videoDurationFromPlayer = 0.0
   
    let actualFileName = filelist[filelistIndex].components(separatedBy: CharacterSet(charactersIn: "/")).last
//    fileWorkingName = actualFileName!.stringByRemovingPercentEncoding()
    fileWorkingName = actualFileName!.removingPercentEncoding!
    let baseName = filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    
    let cutsData = loadRawDataFromFile(filelist[filelistIndex])
    if cutsData != nil {
      cuts = CutsFile(data: cutsData!)
      if (debug) { cuts.printCutsData() }
      self.cutsTable.reloadData()
      
      // select begining of file or earliest bookmark if just a few
      if (cuts.cutsArray.count>0 && cuts.cutsArray.count<=3)
      {
        let startPTS = Int64(cuts.cutsArray.first!.cutPts)
        startTime = CMTimeMake(startPTS, CutsTimeConst.PTS_TIMESCALE)
      }
      else {
        startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
      }
      
      // process eit file
      let EitName = baseName+ConstsCuts.EIT_SUFFIX
      let EITData = loadRawDataFromFile(EitName)
      if (EITData != nil) {
        eit=EITInfo(data: EITData!)
        if (debug) { print(eit.description()) }
        
        let metaFilename = baseName+ConstsCuts.META_SUFFIX
        
        metadata = MetaData(fromFilename: URL(string: metaFilename)!)
        
        // load the ap file
        let apName = URL(string: filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.AP_SUFFIX))!
        accessPointData = AccessPoints(fullpath: apName)

        if (debug) { print(metadata.description()) }
        programTitle.stringValue = eit.programNameText()
        epsiodeTitle.stringValue = eit.episodeText()
        programDescription.string = eit.descriptionText()
        // if description is empty, replicate title in description field
        // some eit entries fail to give a title and put the description
        // in the notional episode title descriptor
        if programDescription.string!.isEmpty
        {
          programDescription.string = eit.episodeText()
        }
        let TSName = baseName+ConstsCuts.TS_SUFFIX
        setupAVPlayerFor(TSName, startTime: startTime)
      }
      // found a loaded a file, update the recent file menu
      let name = baseName+ConstsCuts.CUTS_SUFFIX
      let fileURL = URL(string: name)!
      if  let doc = try? TxDocument(contentsOf: fileURL, ofType: ConstsCuts.CUTS_SUFFIX)
      {
         NSDocumentController.shared().noteNewRecentDocument(doc)
      }
    }
  }

  // MARK: button responders
  
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
      currentFile.selectItem(at: lastfileIndex+adjustment)
      print("filelistIndex is now \(filelistIndex)")
      setPrevNextButtonState(filelistIndex)
      changeFile(filelistIndex)
    }
  }
  
  @IBAction func prevButton(sender: NSButton) {
    previousNextButtonAction(ProgramChoiceStepDirection.PREVIOUS)
  }
  
  @IBAction func nextButton(sender: NSButton) {
    previousNextButtonAction(ProgramChoiceStepDirection.NEXT)
  }
  
  
  
  /// perform a live "while you wait" cut.  Based on contents of Advanced
  /// preferences dialog
  
  // FIXME: post please wait + local | remote message
  // FIXME: disable all buttons except cancel?
  // FIXME: close all files and clear dialogs - set model to nil?
  
  @IBAction func cutButton(_ sender: NSButton)
  {
    var targetPathName: String
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
    var mcutCommand: String
    
    let cutTask = Process()
    let outPipe = Pipe()
    flushPendingChangesForFileIndex(filelistIndex)
    // FIXME: add spinner
    // FIXME: add result report somewhere
    // FIXME: reload file on success
    // FIXME: configure in mcut arguments respond to user preferences
    sender.isEnabled = false // stop double clicking and sinking the processor
    // TODO: WHAT THE HECK
    // spawn process to perfrom cut
    // FIXME: mark entry as locked in some way until process completed
    // Usage: mcut [-r] [-o output_ts_file] [-n title] [-d description] ts_file [-c start1 end1 [start2 end2] ... ]
    let basename = filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    if let fullPathName = basename.replacingOccurrences(of: "file://",
                                                                        with: "").removingPercentEncoding {
      targetPathName = fullPathName
      // decide if we are doing this locally or remotely and setup commnad line accordingly
      if fullPathName.contains(mcutConsts.localMount) {
        targetPathName = fullPathName.replacingOccurrences(of: mcutConsts.localMount, with: mcutConsts.remoteExportPath)
        mcutCommand = mcutConsts.mcutProgramRemote
        cutTask.launchPath = mcutConsts.localSshPath
      }
      else {  // local processing
        mcutCommand = mcutConsts.mcutProgramLocal
        cutTask.launchPath = mcutCommand
      }
      // build array of command arguments with required switches
      // array is collapsed to single string for remote or passed on as array of args to local command
      var mcutCommandArgs = [String]()
      if (generalPrefs.cutReplace == NSOnState) {
         mcutCommandArgs.append(mcutConsts.replaceSwitch)
      }
      if (cutTask.launchPath == mcutConsts.mcutProgramLocal)
      {
        mcutCommandArgs.append("\(targetPathName)")
        cutTask.arguments = mcutCommandArgs
      }
      else {
        mcutCommandArgs.insert(mcutConsts.mcutProgramRemote, at: 0)
        mcutCommandArgs.append("\"\(targetPathName)\"")
        cutTask.arguments = [mcutConsts.remoteLogin, mcutCommandArgs.joined(separator: " ")]
      }
      if (debug) {
        print("Sending lauch >\(cutTask.launchPath)<")
        print("with args:< \(cutTask.arguments)>")
      }
      cutTask.standardOutput = outPipe
      cutTask.launch()
      let handle = outPipe.fileHandleForReading
      let data = handle.readDataToEndOfFile()
      cutTask.waitUntilExit()
      let result = cutTask.terminationStatus
      if let resultString = String(data: data, encoding: String.Encoding.utf8) {
        print( resultString)
        print("got result of \(result)")
        let programName = targetPathName.components(separatedBy: "/").last
        let message = String.init(format: global_mcut_errors[Int(result)], programName!)
        print(message)
        setDropDownColourForIndex(filelistIndex)
        changeFile(filelistIndex)
        self.statusField.title = message
      }
    }
    sender.isEnabled = true
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
    }
    mouseDownPopUpIndex = nil
  }
  
  // for the user to select a directory and populate an array with
  // the names of files that match the pattern on interest
  // toggles to CANCEL on start of search
  
  @IBAction func findFileAction(_ sender: NSButton)
  {
    flushPendingChangesForFileIndex(filelistIndex)
    resetSearch()
//    print("button label is \(sender.title)")
    if (sender.title == StringsCuts.SELECT_DIRECTORY)
    {
      if  let pickedPath = self.browseForFolder()
      {
        var rootPath : String
        rootPath = pickedPath + StringsCuts.DIRECTORY_SEPERATOR
        let foundRootPath = rootPath;
        self.progressBar.isHidden = false
        self.progressBar.maxValue = Double(countFilesWithSuffix(ConstsCuts.TS_SUFFIX, belowPath: foundRootPath))
        findfilesOperationQueue(foundRootPath)
        sender.title = StringsCuts.CANCEL_SEARCH
      }
      else {
        sender.title = StringsCuts.SELECT_DIRECTORY
      }
    }
    else    // user clicked on cancel search
    {
      sender.title = StringsCuts.SELECT_DIRECTORY
      let runningOperations = self.finderOperationsQueue.operations
      for operation in runningOperations {
       operation.cancel()
      }
      actionsSetEnabled(false)
      self.progressBar.isHidden = true
      if (debug) { print(runningOperations) }
    }
    actionsSetEnabled(false)
 }
  
  // respond to configurable skip buttons
  
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
  // names may occur in multiple directories.  We don't care
  // where they are, we want all 'like' names brought together
  
  func pairsListNameSorter( _ s1: namePair, s2: namePair) -> Bool
  {
    let names1Array = s1.programeName.components(separatedBy: kHyphen)
    let names2Array = s2.programeName.components(separatedBy: kHyphen)
    let names1 = names1Array[2 ... names1Array.count-1].joined(separator: kHyphen)
    let names2 = names2Array[2 ... names2Array.count-1].joined(separator: kHyphen)
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
    let cutsData = loadRawDataFromFile(filelist[index])
    let metaName = URL(string: filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.META_SUFFIX))!
    let metaData = MetaData(fromFilename: metaName)
    let eitName = URL(string: filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.EIT_SUFFIX))!
    let EITData = loadRawDataFromFile(eitName.path)
    var eitdata : EITInfo?
    if (EITData != nil) {
      eitdata=EITInfo(data: EITData!)
    }
    // load the ap file
    let apName = URL(string: filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.AP_SUFFIX))!
    let apData = AccessPoints(fullpath: apName)
    
    thisProgramDuration = self.getBestDurationInSeconds(metaData, eit: eitdata, ap: apData, player: nil)
    
    if cutsData != nil {
      let thisCuts = CutsFile(data: cutsData!)
      attributeColour = (thisCuts.cutsArray.count > fileColourParameters.BOOKMARK_THRESHOLD_COUNT) ? fileColourParameters.allDoneColor : fileColourParameters.noBookmarksColor
      
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
  
  func setCurrentFileListColors()
  {
    self.progressBar.isHidden = false
    self.progressBar.needsDisplay = true
    self.view.needsDisplay = true
    currentFileColouringBlock = colourCodeProgramList()
//    setCurrentFileAttributedString()
  }

//  // FIXME: Check what happens if user changes directory selection whilst this
//  // detached process in running....it should probably find some way of killing it.
//  
//  func setCurrentFileAttributedString()
//  {
//    weak var weakself = self
//    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
//
//      var attributedStrings = [NSAttributedString]()
//      
//      // make copy of NSPopUpButton to query & update without interfering with UI
//      
//      weakself!.statusField.stringValue = StringsCuts.DERIVING_PROGRAM_STATUS
//      for index in 0 ..< weakself!.namelist.count
//      {
//        let (fontAttribute, colourAttribute) = weakself!.getFontAttributesForIndex(index)
//        // FIXME: consider consequences of user changing sort order whilst this is going on
//        // in the background - should be killed and restarted - beware race condition of this
//        // and sort finishing close together.  Sort should know how cancel this process and start
//        // a new one if it is not complete.... OR this process should block changing sort order
//        
//        if let menuItem = weakself!.currentFile.itemAtIndex(index)
//        {
//          attributedStrings.append(NSAttributedString(string: menuItem.title, attributes:[NSForegroundColorAttributeName: colourAttribute, NSFontAttributeName:fontAttribute]))
//        }
//        dispatch_async(dispatch_get_main_queue()) {
//           weakself!.statusField.stringValue = "deriving is \(index) of \(weakself!.namelist.count)... working"
//        }
//      }
//      
//      // all done
//      
//      dispatch_async(dispatch_get_main_queue()) {
//        for index in 0 ..< weakself!.namelist.count
//        {
//          weakself!.currentFile.itemAtIndex(index)?.attributedTitle = attributedStrings[index]
//        }
//        // now as we have been scribbling in the status field, we ensure that is brougth
//        // back into sync with the current user selection
//        weakself!.setStatusFieldToCurrentSelection()
//      }
//    }
//  }

  
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
  
  func findfilesOperationQueue(_ rootPath:String)
  {
    let fileFinder = FileFindingOperation(foundRootPath: rootPath, finderDialog: self)
    fileFinder.completionBlock = {
      if fileFinder.isCancelled  {
        return
      }
      self.filelist = fileFinder.foundfiles
      weak var weakself = self
      DispatchQueue.main.async {
          weakself!.listingOfFilesFinished()
        
      }
    }
    self.finderOperationsQueue = {
      let queue = OperationQueue()
      queue.name = "Search queue"
      queue.maxConcurrentOperationCount = 1
      return queue
    } ()
    finderOperationsQueue.addOperation(fileFinder)
  }
  
//  func findfilesGCD(rootPath:String)
//  {
//    weak var weakself = self
//    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
//      
//      let dirWalker = NSFileManager.defaultManager().enumeratorAtPath(rootPath)
//      self.statusField.stringValue = StringsCuts.WORKING
//      var lookedAtCount=0
//      while let file = dirWalker?.nextObject() as! String?
//      {
//        // looking for the nominal pattern /xxx/xxx/xxx/xxx/ABC_Oct.26.2014_19.40+56956.70800.tvwiz/header.tvwiz
//        let url = NSURL(fileURLWithPath: file)
//        lookedAtCount += 1
//        let remainder = lookedAtCount%25
//        //          print(remainder)
//        if (remainder == 0)
//        {
//          let snapshot = lookedAtCount
//          dispatch_async(dispatch_get_main_queue() ) {
//            weakself!.statusField.stringValue = "passed count is \(snapshot) ... working"
//          }
//        }
//        if (url.pathExtension == ConstsCuts.BEYONWIZ_DIRECTORY_EXTENSION)
//        {
//          if (url.lastPathComponent == ConstsCuts.HEADER_NAME)
//          {
//            if (weakself!.debug)
//            {
//              print("\(file)")
//            }
//            let fullFilename = url.absoluteString
//            weakself!.filelist.append(fullFilename)
//            dispatch_async(dispatch_get_main_queue()) {
//              weakself!.statusField.stringValue = "TVWIZ Count is \(weakself!.filelist.count) ... working"
//            }
//          }
//        }
//      }
//      
//      dispatch_async(dispatch_get_main_queue()) {
//        weakself!.statusField.stringValue = "file count is \(weakself!.filelist.count) ... finished"
//        if (weakself!.filelist.count > 1 )
//        {
//          weakself!.filelistIndex = 0
//          weakself!.setPrevNextButtonState(weakself!.filelistIndex)
//          weakself!.changeFile(weakself!.filelistIndex)
//        }
//      }
//      
//    }
//  }
//  
  
  override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if (menuItem.action == #selector(clearBookMarks(_:))
      || menuItem.action == #selector(clearCutMarks(_:))
      || menuItem.action == #selector(clearLastPlayMark(_:))
      || menuItem.action == #selector(add10Bookmarks(_:))
      )
    {
      return (filelist.count > 0 )
    }
    else {
      return true
    }
  }
  
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
    cuts.cutsArray.removeAll()
    eit = EITInfo()
    cuts = CutsFile()
    cutsModified = false
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
  
  func findFilesFinished(_ fileIndexCount : Int, listOfFiles : [String])
  {
    self.selectDirectory.title = StringsCuts.SELECT_DIRECTORY
//    print(listOfFiles)
    self.filelist = listOfFiles
    self.statusField.stringValue = "file count is \(fileIndexCount) ... finished"
    self.progressBar.isHidden = true
  }
  
  /// Select folder for processing of file
  /// - returns: full path to directory or nil
  func browseForFolder() -> String?
  {
    // flush any pending writes
    flushPendingChangesForFileIndex(filelistIndex)
    
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
    }
  }
  
  
  override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?)
  {
//    let whatsIt = Mirror(reflecting: object!)
//    print(whatsIt)
//    for case let (label?, value) in whatsIt.children {
//      print (label, value)
//    }
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
            let thisDuration = getBestDurationInSeconds(metadata, eit: eit, ap: accessPointData, player: self.monitorView.player)
            self.programDuration.stringValue = CutEntry.hhMMssFromSeconds(thisDuration)
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
//            let startTime = (self.cuts.cutsArray.count>=1) ? self.cuts.firstBookmark : CMTime(seconds: 0, preferredTimescale: 1)
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
            let startTime = (self.cuts.cutsArray.count>=1) ? self.cuts.firstBookmark : CMTime(seconds: 0, preferredTimescale: 1)
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
      else {
        super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
      }
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
      samplePlayer.addObserver(self, forKeyPath: "status", options: NSKeyValueObservingOptions.new, context: nil)
      samplePlayer.isClosedCaptionDisplayEnabled = true
      self.monitorView.showsFrameSteppingButtons = true
      self.monitorView.player = samplePlayer
      self.monitorView.showsFullScreenToggleButton = true
      self.monitorView.showsFrameSteppingButtons = true
      self.monitorView.player?.seek(to: startTime)
   }
    else {
      self.statusField.stringValue = "Invalid Time duration cannot work with"
    }
  }
  
  func getFileManagerForFile( _ fullFileName : String) -> (FileManager, Bool, String)
  {
    var pathName : String
    let fileMgr : FileManager = FileManager.default
    if (debug) { print (fullFileName) }
    
    pathName = ""
    if let checkIsURLFormat = URL.init(string: fullFileName)
    {
        pathName = checkIsURLFormat.path
    }
    else // assume file system format
    {
      pathName = fullFileName
    }
    let fileExists = fileMgr.fileExists(atPath: pathName)
    return (fileMgr, fileExists, pathName)
  }
  
  /// Common function to write the status field GUI entry to match
  /// the current user selection
  func setStatusFieldToCurrentSelection()
  {
    let arrayIndex = currentFile.indexOfSelectedItem
    self.statusField.stringValue = "file \(arrayIndex+1) of \(filelist.count)"
  }

  
  // MARK: Player related functions
  
  func seekToSkip(_ skipDurationSeconds:Double)
  {
    let pts=Int64(skipDurationSeconds*Double(CutsTimeConst.PTS_TIMESCALE))
    wasPlaying = isPlaying
    self.monitorView.player?.pause()
    let now = (self.monitorView.player?.currentTime())!
    let newtime = CMTimeAdd(now, CMTime(value: pts, timescale: CutsTimeConst.PTS_TIMESCALE))
    self.monitorView.player?.seek(to: newtime, completionHandler: seekCompletedOK)
    if (wasPlaying) {
      self.monitorView.player?.play()
    }
  }
  
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
    self.monitorView.player?.pause()
    self.monitorView.player?.seek(to: CMTime(value: Int64(seekBarPos.cutPts), timescale: CutsTimeConst.PTS_TIMESCALE), completionHandler: seekCompletedOK)
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
  
  // MARK: TableView delegate, datasource and table related functions
  
  // Get the view related to selected cell and populated the data value
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    var cellContent : String
    if tableColumn?.identifier == StringsCuts.TABLE_TIME_COLUMN
    {
      if (self.cuts.cutsArray.count>0)
      {
       cellContent = CutEntry.timeTextFromPTS(self.cuts.cutsArray[row].cutPts)
      }
      else {
       cellContent = "?"
      }
    }
    else if tableColumn?.identifier == StringsCuts.TABLE_TYPE_COLUMN
    {
      if (self.cuts.cutsArray.count>0)
      {
       cellContent = (MARK_TYPE(rawValue: self.cuts.cutsArray[row].cutType)?.description())!
      }
      else {
        cellContent = "??"
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
    return self.cuts.count
  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    let selectedRow = cutsTable.selectedRow
    // seek to associated cutEntry
    guard (selectedRow>=0 && selectedRow<cuts.cutsArray.count) else
    {
      // out of bounds, silently ignor
      return
    }
    let entry = cuts.cutsArray[selectedRow]
    if (!suppressPlayerUpdate) { seekPlayerToMark(entry) }
  }

// provide "swipe" function to delete rows from table
  
  func rowDelete(_ action:NSTableViewRowAction, indexPath:Int)
  {
    self.cuts.cutsArray.remove(at: indexPath)
    self.cutsTable.reloadData()
    cutsModified=true
  }
  
// register swipe actions
  
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
    guard row >= 0 && row < self.cuts.cutsArray.count  else { return }
    
    if let rowType = MARK_TYPE.lookupOnRawValue(self.cuts.cutsArray[row].cutType)
    {
      switch rowType
      {
        case MARK_TYPE.IN:
          colour = NSColor.green
        case MARK_TYPE.OUT:
          colour = NSColor.red
        case MARK_TYPE.LASTPLAY:
          colour = NSColor.blue
        case MARK_TYPE.BOOKMARK:
          colour = NSColor.yellow
      }
    }
    rowView.backgroundColor = colour.withAlphaComponent(0.75)
  }
  
  /// Given a valid cut entry, find it and select the row in
  /// the cuts table display.  Do nothing on a nil entry or 
  /// entry not found in array
  /// - parameter cutEntry: pts and type structure
  
  func selectCutTableEntry(_ cutEntry: CutEntry?)
  {
    if (cutEntry != nil) {
      if let indexOfEntry = self.cuts.cutsArray.index(of: cutEntry!)
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
  
  // MARK: Menu file handling
  
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
  
  /// Add bookmarks to the array at a fixed time interval.
  /// Early simplistic implementation to caculate PTS value from first
  /// PTS value.  Later may interogate .ap file for nearest PTS value.
  /// Uses preference value for time interval
  /// Note that this deliberately avoids a begin boundary bookmark
  /// Cutting occurs on GOP boundaries and can end up with negative
  /// bookmarks.
  
  func addFixedTimeBookmarks ()
  {
    
    let intervalInSeconds = preferences.generalPreference().spacingModeDurationOfMarks
    let ptsIncrement = PtsType( intervalInSeconds*Int(CutsTimeConst.PTS_TIMESCALE))
    // get duration
    if (firstInCutMark < lastOutCutMark)  // important for UIntXX values
    {
      var pts = firstInCutMark + ptsIncrement
      suppressPlayerUpdate = true
      while pts < lastOutCutMark
      {
        //        print("\(pts)  - \(offset)")
        let cutPt = CutEntry(cutPts: pts, cutType: MARK_TYPE.BOOKMARK.rawValue)
        addEntry(cutPt)
        pts += ptsIncrement
      }
      suppressPlayerUpdate = false
//      seekPlayerToCutEntry(cuts.cutsArray.first)
      seekPlayerToMark(firstVideoPosition())
    }
  }
  
  // MARK: cutMark management functions
  
  @IBAction func clearBookMarks(_ send: AnyObject)
  {
    clearAllOfType(.BOOKMARK)
  }
  
  @IBAction func clearLastPlayMark(_ send: AnyObject)
  {
    clearAllOfType(.LASTPLAY)
  }
  
  /// Clears the cutsArray of all IN and OUT marks
  /// - parameter sender: typically menu Item or Button, not used
  @IBAction func clearCutMarks(_ sender: AnyObject)
  {
    clearArrayOfTypes([.IN, .OUT])
  }
  
  /// Menu item action
  
  @IBAction func add10Bookmarks(_ sender: AnyObject)
  {
    if (preferences.generalPreference().markMode == MARK_MODE.FIXED_SPACING_OF_MARKS) {
      addFixedTimeBookmarks()
    }
    else {
      addPercentageBookMarks(preferences.generalPreference().countModeNumberOfMarks)
    }
//    self.cuts.printCutsData()
//    self.cuts.printCutsDataAsHex()
  }
  
  @IBAction func clearAllMarks(_ sender: AnyObject)
  {
    clearArrayOfTypes([.IN, .OUT, .LASTPLAY, .BOOKMARK])
  }
  
  func clearAllOfType(_ markType: MARK_TYPE)
  {
    suppressPlayerUpdate = true
    for entry in self.cuts.cutsArray
    {
      removeEntryOfType(entry, type: markType)
    }
    suppressPlayerUpdate = false
  }
  
  func clearArrayOfTypes(_ markArray: [MARK_TYPE])
  {
    suppressPlayerUpdate = true
    for mark in markArray
    {
      clearAllOfType(mark)
    }
    suppressPlayerUpdate = false

  }
  
  // 10% button action
  @IBAction func addBookMarkSet(_ sender: AnyObject) {
    addPercentageBookMarks()
  }
  
  func addEntry(_ cutEntry: CutEntry) {
    // check if already present
    if (!self.cuts.cutsArray.contains(cutEntry)) {
      self.cuts.cutsArray.append(cutEntry)
      self.cuts.cutsArray.sort(by: <)
      cutsModified = true
      updateTableGUIEntry(cutEntry)
    }
  }
  
  func removeEntryOfType(_ cutEntry: CutEntry, type: MARK_TYPE)
  {
    if (self.cuts.cutsArray.contains(cutEntry))
    {
      if (cutEntry.cutType == type.rawValue)
      {
        let index = self.cuts.cutsArray.index(of: cutEntry)!
        self.cuts.cutsArray.remove(at: index)
        self.cutsTable.reloadData()
        cutsModified = true
        if (cuts.cutsArray.count>0)
        {
          let nextIndex = (index==0) ? 0 : index-1
          let nextEntry = cuts.cutsArray[nextIndex]
          updateTableGUIEntry(nextEntry)
        }
        else {
          updateTableGUIEntry(nil)
        }
      }
    }
  }
  
  func removeEntry(_ cutEntry: CutEntry)  {
    if (self.cuts.cutsArray.contains(cutEntry))
    {
      let index = self.cuts.cutsArray.index(of: cutEntry)!
      self.cuts.cutsArray.remove(at: index)
      self.cutsTable.reloadData()
      self.cutsModified = true
    }
  }
  
  @IBAction func addMark(sender: NSButton) {
    let markTypeLookup = ["addBookmark":MARK_TYPE.BOOKMARK,"addInMark":MARK_TYPE.IN, "addOutMark":MARK_TYPE.OUT]
    let mark = markTypeLookup[sender.identifier!]
    let now = self.playerPositionInPTS()
    let bookmark = CutEntry(cutPts: now, cutType: mark!.rawValue)
    addEntry(bookmark)
  }
  
  /// readonly computed var of postion of first IN cutmark in PTS units. If no IN is present
  /// then return 0 for begining of video
  var firstInCutMark:UInt64 {
    get {
      var pts : UInt64 = 0
      var found = false
      var entry : CutEntry!
      var index = 0
      while !found && (index != cuts.cutsArray.count)
      {
        entry = cuts.cutsArray[index]
        if (entry.cutType == MARK_TYPE.IN.rawValue)
        {
          found = true
          pts = entry.cutPts
        }
        else {
          index += 1
        }
      }
      return pts
    }
  }
  
  /// Readonly computed var of the position of the last OUT pts.  If no OUT is present,
  /// then return the max of the metadata duration (which for some broadcasters
  /// can be 0 (!)) and the video duration determined by the AVPlayer
  
  var lastOutCutMark: UInt64 {
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
//      var pts : UInt64 = max(metaPTS, videoPTS)
      for entry in cuts.cutsArray
      {
        if (entry.cutType == MARK_TYPE.OUT.rawValue)
        {
          pts = entry.cutPts
        }
      }
      return pts
    }
  }
  
  /// Find the earliest position in the video.  This should be
  /// the first IN mark, failing that, if there are <= 3 bookmarks,
  /// use the first bookmark - most likely an unedited file.  If there
  /// are more that 3 book marks, then use then use the initial file position
  /// which may have to be fabricated if it does not exist.
  /// Note that this has become needed since we have stopped trying to put a
  /// "zero" position bookmark due to cutting side effects
  
  func firstVideoPosition() -> CutEntry
  {
    if let entry = self.cuts.firstINMark() {
      return entry
    }
    else
    {
      if self.cuts.cutsArray.count > 3 || self.cuts.cutsArray.count == 0
      {
        return CutEntry(cutPts: UInt64(0), cutType: MARK_TYPE.IN.rawValue)
      }
      else  {
        return self.cuts.cutsArray.first!
      }
    }
  }
  
  /// Note that this deliberately avoids a begin boundary bookmark
  /// Cutting occurs on GOP boundaries and can end up with negative
  /// bookmarks.
  /// Default value give bookmarks at 10 % boundaries
  
  func addPercentageBookMarks(_ numberOfMarks: Int = 9)
  {
    var countAdded = 0
    // get duration
    if (firstInCutMark < lastOutCutMark)  // important for UIntXX values
    {
      let programLength = lastOutCutMark - firstInCutMark
      let ptsOffset = programLength / UInt64(numberOfMarks+1)
      suppressPlayerUpdate = true
      var ptsPosition = firstInCutMark + ptsOffset
      while (ptsPosition < lastOutCutMark && countAdded < numberOfMarks)
      {
//        print("\(pts)  - \(offset)")
        let cutPt = CutEntry(cutPts: ptsPosition, cutType: MARK_TYPE.BOOKMARK.rawValue)
        addEntry(cutPt)
        ptsPosition += ptsOffset
        countAdded += 1
      }
      suppressPlayerUpdate = false
      seekPlayerToCutEntry(firstVideoPosition())
    }
  }
  
  // MARK: OS utility functions
  
  func loadRawDataFromFile(_ filename:String) -> Data?
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
    }
    return data
  }
  
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
      if (eitInfo.eit.Duration != "00:00:00") {
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
  
//  @IBAction func openPreferencePanel(sender: AnyObject) {
//    print (#function)
//    self.preferencePanel = CutsPreferencesController()
//  }
  
//  @IBAction func preferenceSorting(sender: AnyObject) {
//    print(#function)
//  }
//  
//  @IBAction func preferenceSkips(sender: AnyObject) {
//    print(#function)
//  }
  
}


// MARK: file search support class

class FileFindingOperation: Operation
{
  var foundfiles = [String]()
  let foundRootPath : String
  let finderDialog : ViewController
  let debug = false
  
  // get the passed in starting directory
  init(foundRootPath : String, finderDialog:ViewController)
  {
    self.foundRootPath = foundRootPath
    self.finderDialog = finderDialog
  }
  
  override func main() {
    let bouncingDotsMarks = [".  ",".. ","..."," ..","  ."," ..","...",".. "]
    if (self.isCancelled) {
//      print("was cancelled by user")
      return
    }
    
//    print("invoked operation")
    self.finderDialog.statusField.stringValue = StringsCuts.STARTED_SEARCH
    let dirWalker = FileManager.default.enumerator(atPath: self.foundRootPath)
    //        self.statusField.stringValue = StringsCuts.WORKING
    var lookedAtCount=0
    while let file = dirWalker?.nextObject() as! String?
    {
      // looking for the nominal pattern /xxx/xxx/xxx/xxx/ABC_Oct.26.2014_19.40+56956.70800.tvwiz/header.tvwiz
      // looking for the nominal pattern /xxx/xxx/xxx/xxx/*.cuts
//      print ("returned file \(file) look for suffix"+ConstsCuts.CUTS_SUFFIX)
      if (file.hasSuffix(ConstsCuts.CUTS_SUFFIX) && !file.contains(".Trash") )
      {
//        print("matched for \(file)")
        let fullPath = "\(self.foundRootPath)\(file)"
        let url = URL(fileURLWithPath: fullPath)
        lookedAtCount += 1
        let bounceIndex = lookedAtCount%bouncingDotsMarks.count
        if (lookedAtCount % 5 == 0)
        {
          let stageCount = lookedAtCount%25 == 0 ? lookedAtCount : (lookedAtCount/25 * 25)
          DispatchQueue.main.async {
//            self.finderDialog.statusField.stringValue = "passed count is \(stageCount) \(bouncingDotsMarks[bounceIndex]) working"
            self.finderDialog.statusField.stringValue = "Getting list of programs \(bouncingDotsMarks[bounceIndex]) working"
            self.finderDialog.progressBar.doubleValue = Double(stageCount)
          }
        }

        let remainder = lookedAtCount%25
  //      print(remainder)
        if (remainder == 0)
        {
          if self.isCancelled {
//            print("in Cancelled state")
//            print("was cancelled by user")
            DispatchQueue.main.async {
              self.finderDialog.statusField.stringValue = StringsCuts.CANCELLED_BY_USER
            }
            return
          }
//          let snapshot = lookedAtCount
//          dispatch_async(dispatch_get_main_queue() ) {
//            self.finderDialog.statusField.stringValue = "passed count is \(snapshot) \(bouncingDotsMarks[bounceIndex]) working"
//          }
        }
        if (debug)
        {
          print("getting fullname of \(file)")
        }
        let fullFilename = url.absoluteString
//        print("adding to foundfiles - \(fullFilename)")
        self.foundfiles.append(fullFilename)
//                          dispatch_async(dispatch_get_main_queue()) {
//                            self.finderDialog.statusField.stringValue = "\(requiredExtension) Count is \(self.foundfiles.count) ... working"
//                          }
//        }
      }
    }
    
    // job done.  Send results back to caller
    DispatchQueue.main.async {
//      print(self.foundfiles)
      self.finderDialog.findFilesFinished (self.foundfiles.count, listOfFiles: self.foundfiles)
    }
  }
  
}
