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
import Carbon.HIToolbox

typealias FindCompletionBlock = ( _ URLArray:[String]?,  _ forSuffix: String,  _ didCompleteOK:Bool) -> ()
typealias MovieCutCompletionBlock  = (_ message: String, _ resultValue: Int, _ wasCancelled: Bool) -> ()
typealias MovieCutStartBlock  = (_ shortTitle: String) -> ()

//// picked up from stackoverflow - combine dictionaries
//extension Dictionary {
//  mutating func merge(with dictionary: Dictionary) {
//    dictionary.forEach { updateValue($1, forKey: $0) }
//  }
//  
//  func merged(with dictionary: Dictionary) -> Dictionary {
//    var dict = self
//    dict.merge(with: dictionary)
//    return dict
//  }
//}

struct logMessage {
  static let noTrashFolder = "Cannot find folder %@"
  static let adHuntReset = "Reset search state"
}



class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate, NSSpeechRecognizerDelegate
{
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
  var selectedDirectory: String = ""
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
  
  /// flag if cuts list is coherent, enable CUT button, and bookmark bulk insertion if it is
  /// TODO: better done as a KVO oberserver of the movie.isCuttable property setting both button and menu item, for now, this works
  
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
  /// or IN is preceed by OUT, then return 0 for begining of video
  var firstInCutPTS:UInt64 {
    get {
      var pts : UInt64 = 0
      if let entry = movie.cuts.firstInCutMark
      {
        if movie.cuts.inOutOnly.index(of: entry) == 0 {
         pts = entry.cutPts
        }
      }
      return pts
    }
  }
  
  /// opaque var used by video player timed callback
  private var timeObserverToken: Any?
  
  var preferences = NSApplication.shared().delegate as! AppPreferences
  
  var finderOperationsQueue : OperationQueue?
  var localCutterOperationsQueue = CuttingQueue.localQueue()
  var systemSetup = systemConfiguration()

  var currentFileColouringBlock : BlockOperation?
  var cutsModified : Bool {
    get {
      return movie.cuts.isModified
    }
  }
  
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
  
  /// table of three possible durations (player, metadata, eit)
  /// used as tooltip on displayed duration
  var recordingDurations : [Double] = Array(repeating: 0.0, count: 3)
  
  /// value to track periodic callbacks in player and suppress execution of multiples at the same time
  var lastPeriodicCallBackTime : Float = -1.0
  
  /// ensure that user selecting a row is not overriden with timed observed updates
  var suppressTimedUpdates = false
  
  /// flag to control if out/in block skipping is honoured
  var honourOutInMarks = true
  
  /// object to perform speech processing
  var mySpeechRecogizer : NSSpeechRecognizer?
  
//  /// track advert boundary hunting state
//  var boundaryDoubleGreen = false

  /// alias for typical button action from storyboard.
  /// function that has a NSButton arg and returns nothing
  typealias buttonAction = (NSButton) -> ()
  
  /// Dictionary of voice commands with keys that have a one-to-one map to a GUI Button.
  /// TODO: do the I18N to make configurable.  Currrently static english
  var speechDictionary = [String: (action: buttonAction, button: NSButton)]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    
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
    
//    NotificationCenter.default.addObserver(self, selector: #selector(sawDidDeminiaturize(_:)), name: NSNotification.Name.NSWindowDidDeminiaturize, object: nil )
    
//    NotificationCenter.default.addObserver(self, selector: #selector(boundaryDoubleGreen(_:)), name: NSNotification.Name.BoundaryIsDoubleGreen, object: nil )
//    
//    addMatchingCutMark(toMark: prevCut)
    
    self.progressBar.controlTint = NSControlTint.clearControlTint
    self.view.window?.title = "CutListEditor"
    
    microphoneButton.wantsLayer = true
    microphoneButton.layer?.backgroundColor = (voiceRecognition) ? NSColor.green.cgColor : NSColor.red.cgColor
    backwardHuntButton.wantsLayer = true
    forwardHuntButton.wantsLayer = true
    // set button title to inverse of setting
    self.monitorView.showsFrameSteppingButtons = !playerPrefs.playbackShowFastForwardControls
    stepSwapperButton.title = self.monitorView.showsFrameSteppingButtons ? playerStringConsts.ffButtonTitle:playerStringConsts.stepButtonTitle
    stepSwapperButton.isEnabled =  (playerPrefs.playbackControlStyle == videoControlStyle.floating)
    typealias buttonAction = (NSButton) -> ()
    speechDictionary =
      [voiceCommands.advert: (inAdvertisment,backwardHuntButton),
       voiceCommands.program:(inProgram,forwardHuntButton),
       voiceCommands.done:(huntDone,doneHuntButton),
       voiceCommands.reset:(huntReset,resetHuntButton),
       voiceCommands.inCut:(addMark,inButton),
       voiceCommands.out:(addMark,outButton),
       voiceCommands.skipTwoForward:(seekToAction,seekButton2c),
       voiceCommands.skipTwoBackward:(seekToAction,seekButton1c),
       voiceCommands.next:(nextButton,nextButton),
       voiceCommands.previous:(prevButton,previousButton),
       voiceCommands.repeatLast:(seekToAction,seekButton2c)  // non-destructive initial value for "repeat last voice command"
    ]
 }

  override func viewDidAppear() {
    // set window delegate
    self.view.window?.delegate = self
  }
  
  func windowShouldClose(_ sender: Any) -> Bool {
//    print(#file+" "+#function)
    return true
  }
  
  func windowWillClose(_ notification: Notification) {
//    print(#file+" "+#function)
    
    if let token = timeObserverToken
    {
      self.monitorView.player?.removeTimeObserver(token)
      self.timeObserverToken = nil
    }
    self.monitorView.player?.pause()
    NotificationCenter.default.removeObserver(self)
    NSApplication.shared().terminate(self)
  }
  
  func windowWillMiniaturize(_ notification: Notification)
  {
//    print(#file+" "+#function+" \(self.monitorView.player?.rate)")
    wasPlaying = (self.monitorView.player?.rate)! > Float(0.0)
    self.monitorView.player?.pause()
  }
  
//  func windowDidMiniaturize(_ notification: Notification) {
////    print(#file+" "+#function)
//  }
  
  func windowDidDeminiaturize(_ notification: Notification) {
    if wasPlaying {
      self.monitorView.player?.play()
    }
//    print(#file+" "+#function)
  }
  
  
  /// Housekeeping Things to do on window closure
  override func viewDidDisappear() {
//    print(#file+" "+#function)
        super.viewDidDisappear()
  }
  
  /// Housekeeping Things to do after window closure
 
  override func viewWillDisappear() {
//    print(#file+" "+#function)
//    super.viewWillDisappear()
//    NotificationCenter.default.removeObserver(self)
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
 
  /// Restore the saved attributed strings to the popUpButton.
  /// find the index of the old string in the new popup button and
  /// transcribe the related tooltip and attributed title string
  /// - parameter popUp: the button to work with
  /// - parameter itemTitles: array of Strings of the program titles used in the button
  /// - parameter menuItems: array of the old menuitems, which contains the original attributed strings
  
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
    stepSwapperButton.title = self.monitorView.showsFrameSteppingButtons ? playerStringConsts.ffButtonTitle:playerStringConsts.stepButtonTitle
    stepSwapperButton.isEnabled =  (playerPrefs.playbackControlStyle == videoControlStyle.floating)
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
    var abandonWrite = false
    let validCuts = movie.isCuttable
    guard (validCuts) else {
      setStatusFieldStringValue(message: movie.cuts.lastValidationMessage, isLoggable: true)
      NSBeep()
      return false
    }
    guard cutsModified else {
      return true
    }
    if (generalPrefs.autoWrite == CheckMarkState.unchecked) {
      // pop up a modal dialog to confirm overwrite of cuts file
      let overWriteDialog = NSAlert()
      overWriteDialog.alertStyle = NSAlertStyle.critical
      overWriteDialog.informativeText = "Will overwrite the \(ConstsCuts.CUTS_SUFFIX) file"
      overWriteDialog.window.title = "Save File"
      let programname = self.currentFile.item(at: index)!.title.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
      overWriteDialog.messageText = "OK to overwrite file \n\(programname)"
      overWriteDialog.addButton(withTitle: "OK")
      overWriteDialog.addButton(withTitle: "Cancel")
      overWriteDialog.addButton(withTitle: "Don't Save")

      let result = overWriteDialog.runModal()
      proceedWithWrite = result == NSAlertFirstButtonReturn
      abandonWrite = result == NSAlertThirdButtonReturn
    }
    
    // autowrite is enabled, so just get on with it
    if (proceedWithWrite) {
      // rewrite cuts file
      if movie.saveCuts() {
        if ( debug) {
          print(MessageStrings.DID_WRITE_FILE)
        }
        setDropDownColourForIndex(index)
        return true
      }
      else {
        setStatusFieldStringValue(message: StringsCuts.FILE_SAVE_FAILED, isLoggable: true)
        // TODO:  needs some sort of try again / give up options
        return false
      }
    }
    return abandonWrite
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
    let voiceWasOn = voiceRecognition
    if (voiceRecognition) {
      toggleVoiceRecognition(microphoneButton)
    }
    //  clean out the GUI and context for the next file
    self.monitorView.player?.cancelPendingPrerolls()
    self.monitorView.player?.currentItem?.cancelPendingSeeks()
    resetGUI()
    resetCurrentMovie()
    setStatusFieldToCurrentSelection()
   
    currentFile.toolTip = currentFile.selectedItem?.toolTip
    let actualFileName = filelist[filelistIndex].components(separatedBy: CharacterSet(charactersIn: "/")).last
    fileWorkingName = actualFileName!.removingPercentEncoding!
    let baseNameURL = filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    
    // load up a recording
    movie = Recording(rootURLName: baseNameURL)
    preferences.setMovie(movie: movie)
    if (debug) { movie.cuts.printCutsData() }
    self.cutsTable.reloadData()
    cutsUndoRedo = CutsEditCommnands(movie.cuts)
    
    // select begining of file or earliest bookmark if just a few
    if (movie.cuts.count>0 && movie.cuts.count<=3)
    {
      let startPTS = Int64(movie.cuts.first!.cutPts)
      startTime = CMTimeMake(startPTS, CutsTimeConst.PTS_TIMESCALE)
    }
    else {
      startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
    }
    
    // extract eit file information
    programTitle.stringValue = movie.eit.programNameText()
    epsiodeTitle.stringValue = movie.eit.episodeText()
    programDescription.string = movie.eit.descriptionText()
    
    if (debug) { print(movie.meta.description()) }
    // if description is empty, replicate title in description field
    // some eit entries fail to give a title and put the description
    // in the notional episode title descriptor
    // Alternative would be to blank title field and populate description
    if programDescription.string!.isEmpty
    {
      let epTitle = epsiodeTitle.stringValue
      if epTitle.characters.count > ConstsCuts.maxTitleLength {
        // abitrarily pick out the first n words
        let titlewords = epTitle.components(separatedBy: " ")
        let title  = titlewords[0..<min(ConstsCuts.titleWordsPick,titlewords.count)].joined(separator: " ")
        epsiodeTitle.stringValue = title
      }
      programDescription.string = movie.eit.episodeText()
    }
    let TSNameURL = baseNameURL+ConstsCuts.TS_SUFFIX
    setupAVPlayerFor(TSNameURL, startTime: startTime)
    // found a loaded a file, update the recent file menu
    let cutsNameURL = baseNameURL+ConstsCuts.CUTS_SUFFIX
    let fileURL = URL(string: cutsNameURL)!
    if  let doc = try? TxDocument(contentsOf: fileURL, ofType: ConstsCuts.CUTS_SUFFIX)
    {
       NSDocumentController.shared().noteNewRecentDocument(doc)
    }
    if (voiceWasOn) { toggleVoiceRecognition(microphoneButton)}
//    print(mySpeechRecogizer?.commands)
//    print("Have I started?")
    NotificationCenter.default.post(name: Notification.Name(rawValue: movieDidChange), object: nil)
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
    huntButtonsReset()
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
    textField.sizeToFit()
    
    msg.accessoryView = textField
    let response: NSModalResponse = msg.runModal()
    
    if (response == NSAlertFirstButtonReturn) {
      return textField.stringValue
    } else {
      return ""
    }
  }
  
  func disconnectCurrentMovieFromGUI()
  {
    // disconnect player display from the item about to be processed
    guard flushPendingChangesFor(.current) else
    {
      return
    }
    removePlayerObserversAndItem()
    // clear current dialog entries
    resetCurrentMovie()
    resetGUI()
  }
  
  @IBAction func cutButton(_ sender: NSButton)
  {
    guard flushPendingChangesFor(.current) else
    {
      return
    }
    disconnectCurrentMovieFromGUI()
    let moviePathURL = filelist[filelistIndex]
    cutMovie(moviePathURL)
    currentFile.isEnabled = true
    setPrevNextButtonState(filelistIndex)
  }
  
  /// Invokes "change program" code on action with the
  /// GUI Program Picker - NSPopUpButton list of programs
  
  @IBAction func selectFile(_ sender: NSPopUpButton) {
    if let lastfileIndex = mouseDownPopUpIndex
    {
      let indexSelected = sender.indexOfSelectedItem
      if (debug) { print("New file selected is [\(indexSelected) - \(sender.itemArray[indexSelected])") }
      if (indexSelected != mouseDownPopUpIndex) // file selection has really changed
      {
        
        changeFile(indexSelected)
        // check if change succeeded or it has reset the selected index
        if (indexSelected == lastfileIndex) {
          sender.selectItem(at: indexSelected)
        }
        currentFile.toolTip = currentFile.selectedItem?.toolTip
        setPrevNextButtonState(indexSelected)
     }
    }
    mouseDownPopUpIndex = nil
    boundaryAdHunter = nil
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
        selectedDirectory = rootPath
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
      selectedDirectory = ""
      sender.title = StringsCuts.SELECT_DIRECTORY
      actionsSetEnabled(false)
      sender.isEnabled = false
      statusField.stringValue = "Waiting on cancellation of search opertion"
    }
   }

  
  /// Used to determine from recording path which configuration should be used for
  /// setting up the "Cut" task.  Uses a the unchangable local name determining fi
  /// we are doing a local or remote cut.
  /// - parameter dirPath: path of the recording
  /// - returns : touple local or remote cut, index into the configurations array
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
    boundaryHuntReset()
  }
  
  // files on disk are unique.. therefore easy sorting
  // Duplicate names may occur in multiple directories.  We don't care
  // where they are, we want all 'like' names brought together
  
  /// Sorter to sort namePairs by name
  /// picks program name from expected format of "^DateTime - Channel - ProgramName$"
  func pairsListNameSorter( _ s1: namePair, s2: namePair) -> Bool
  {
    var names1, names2: String
    let names1Array = s1.programeName.components(separatedBy: kHyphen)
    let names2Array = s2.programeName.components(separatedBy: kHyphen)
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
  
  /// Sorter to sort namePairs by channel name
  /// picks channel from expected format of "^DateTime - Channel - ProgramName$"
  /// if pattern does not contain "-" then use name alone
  func pairsListChannelSorter( _ s1:namePair, s2: namePair) -> Bool
  {
    var greaterThan: Bool
    let s1Components = s1.programeName.components(separatedBy: kHyphen)
    let s2Components = s2.programeName.components(separatedBy: kHyphen)
    let names1 = (s1Components.count>=2) ? s1Components[1] : s1Components[0]
    let names2 = (s2Components.count>=2) ? s2Components[1] : s2Components[0]
    if sortPrefs.isAscending {
      greaterThan = names1 < names2
    }
    else {
      greaterThan =  names1 > names2
    }
    return greaterThan
  }
  
  /// Sorter to sort namePairs by date field
  /// picks date from expected format of "^DateTime - Channel - ProgramName$"
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
 
  /// Build a namePair array using the namelist as a base
  /// and sort it by name.
  /// Used when user changes the preference sorting configuration
  /// Generates a resorted namelist and filelist array
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
  
  
  /// Sorts a namePairs array based on the sorting order
  /// found in the user preferences
  /// - parameter namePairs: array to be sorted
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
//      var durations = [Double](repeating:0.0, count:namelist.count)
//      durations = apDurations(files: filelist)
      // add a tip of the actual file path
      for index in 0 ..< self.currentFile.itemArray.count {
        let path = filelist[index].replacingOccurrences(of: "file://", with: "")
//        self.currentFile.item(at: index)?.toolTip = path.removingPercentEncoding! + " (" + CutEntry.hhMMssFromSeconds(durations[index])+")"
        self.currentFile.item(at: index)?.toolTip = path.removingPercentEncoding!
      }
  }
  
//  /// Build an array matching the list of files with the correspodning
//  /// calculated rutime of the recording
//  /// - parameter files: array of fully specified disk paths
//  /// - returns: array of same size as input with duration of related file in seconds
//  func apDurations(files list:[String]) -> [Double]
//  {
//    var durations = [Double](repeating: 0.0, count:list.count)
//    for fileIndex in 0 ..< list.count {
//      let filename = list[fileIndex]
//      if let urlName = URL(string: filename.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: ConstsCuts.AP_SUFFIX))
//      {
//        durations[fileIndex] = AccessPoints(url:urlName)?.durationInSecs() ?? 0.0
//      }
//    }
//    return durations
//  }
  
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
    blockOperation.addExecutionBlock (
      { [weak weakself = self] in
        var attributedStrings = [NSAttributedString]()
//        let trailingDurationRegexString = " ([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\)$" // eg " (01:23:35)"
        // progressively construct a duplicate of NSPopUpButton to query & update without interfering with UI
        for index in 0 ..< self.namelist.count
        {
          // each time through the loop check that we are still wanted
          if blockOperation.isCancelled {
            resultNotWanted = true
            break
          }
          if let (fontAttribute, colourAttribute, apDuration) = weakself?.getFontAttributesDurationForIndex(index) {
          if let menuItem = self.currentFile.item(at: index)
          {
            attributedStrings.append(NSAttributedString(string: menuItem.title, attributes:[NSForegroundColorAttributeName: colourAttribute, NSFontAttributeName:fontAttribute]))
//            let path = weakself?.filelist[index].replacingOccurrences(of: "file://", with: "")
//            let tooltip = (path?.removingPercentEncoding!)! + " (\(CutEntry.hhMMssFromSeconds(apDuration)))"
            if let pathURL = weakself?.filelist[index],
               let tooltip = weakself?.tooltipFrom(url: pathURL, duration: apDuration)
            {
              menuItem.toolTip = tooltip
            }
            // else: no path == no tooltip (duh)
          }
          // update the application each time we have completed one program except the last
          if (index < self.namelist.count-1) {
            OperationQueue.main.addOperation (
            {
              self.progressBar.doubleValue = Double(index)
              self.statusField.stringValue = "Working out title colour coding in background"
            })
            }
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
  
  func getFontAttributesDurationForIndex( _ index : Int) -> (font :NSFont, colour: NSColor, apDuration:Double)
  {
    // set defaults
    var attributeColour = NSColor.black
    let fontSize = NSFont.systemFontSize()
    var font = NSFont.systemFont(ofSize: fontSize)
    var thisProgramDuration = 0.0
    var thisMovie: Recording
    
    // work through the set of files
    let baseName = filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    thisMovie = Recording(rootURLName: baseName)
    
    let durations = thisMovie.getBestDurationAndApDurationInSeconds()
    thisProgramDuration = durations.best
    if (thisMovie.cuts.count != 0) {
      attributeColour = (thisMovie.cuts.count > fileColourParameters.BOOKMARK_THRESHOLD_COUNT) ? fileColourParameters.allDoneColor : fileColourParameters.noBookmarksColor
      
      // override if we have in/out pairs
      if ( thisMovie.cuts.containsINorOUT()) {
        font = NSFont.boldSystemFont(ofSize: fontSize)
        // set unbalanced if there are not pairs of in/out - typically flagging MacOS player has trouble with ts file
        // get one in, but cannot seek to set the other
        let unbalanced = (thisMovie.cuts.inOutOnly.count % 2 == 1)
        attributeColour = (unbalanced) ? fileColourParameters.partiallyReadyToCutColor : fileColourParameters.readyToCutColor
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
    return (font, attributeColour, durations.ap)
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
    let (fontAttribute, colourAttribute, apDuration) = getFontAttributesDurationForIndex(index)
    if  let menuItem = currentFile.item(at: index)
    {
//      let path = filelist[index].replacingOccurrences(of: "file://", with: "")
//      let tooltip = (path.removingPercentEncoding!) + " (\(CutEntry.hhMMssFromSeconds(apDuration)))"
      let tooltip = tooltipFrom(url: filelist[index], duration: apDuration)
      
      menuItem.attributedTitle = NSAttributedString(string: menuItem.title, attributes: [NSForegroundColorAttributeName: colourAttribute, NSFontAttributeName: fontAttribute])
      menuItem.toolTip = tooltip
    }
  }
  
  /// Construct the dropdown tool tip to be full (local) path and the calculated duration
  /// of the recording
  /// - parameter url: file:// style url
  /// - parameter apDuration: the duration of the recording in seconds
  /// - returns: formatted string
  
  func tooltipFrom(url: String, duration: Double ) -> String
  {
    let durationString = " ("+CutEntry.hhMMssFromSeconds(duration) + ")"
    let path = url.replacingOccurrences(of: "file://", with: "")
    let plainPath = path.removingPercentEncoding ?? path
    let tooltip = plainPath + durationString
    return tooltip
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
  }
  
  /// callback function when detached file search process has finished
  /// creates the NSPopButton (dropdown list) of programs to be 
  /// handled
  
  func listingOfFilesFinished()
  {
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
      || menuItem.action == #selector(clearAllMarks(_:))
      )
    {
      return (filelist.count > 0 )
    }
    else if (menuItem.action == #selector(add10Bookmarks(_:))) {
      return cuttable && (filelist.count > 0 )
    }
    else if (menuItem.action == #selector(undo(_:))) {
      print("undo is \(cutsUndoRedo?.undoEmpty)")
      return cutsUndoRedo?.undoEmpty ?? false
    }
    else if ( menuItem.action == #selector(redo(_:))) {
      print("redo is \(cutsUndoRedo?.isRedoPossible)")
    return cutsUndoRedo?.isRedoPossible ?? false
    }
    else {
      return true
    }
  }
  
  @IBAction  func undo(_ sender: AnyObject) {
    cutsEditUndo()
  }
  @IBAction  func redo(_ sender: AnyObject) {
    cutsEditRedo()
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
     deleteRecordingButton.isEnabled = (filelist.count > 0)
    }
    else {
      previousButton.isEnabled = state
      nextButton.isEnabled = state
      deleteRecordingButton.isEnabled = state
    }
    enableAdHuntingButtons(state)
  }
  
  /// Reset GUI elements to blank that reflect selected movie / directory
  func resetGUI()
  {
    programTitle.stringValue = ""
    programDescription.string = ""
    epsiodeTitle.stringValue = ""
    cutsTable.reloadData()
    fileWorkingName = ""
    programDuration.stringValue = ""
    programDuration.toolTip = ""
    statusField.stringValue = ""
    actionsSetEnabled(false)
    self.cutsTable.reloadData()
    currentFile.toolTip = ""
    boundaryAdHunter?.reset()
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
  
  /// Clear the current selected movie details back to empty/nil
  func resetCurrentMovie()
  {
    wasPlaying = false
    movie = Recording()
    preferences.setMovie(movie: nil)
    cutsUndoRedo = nil
  }
  
  /// Clear all of the current model/state back to program startup condition
  func resetFullModel()
  {
    if currentFileColouringBlock != nil
    {
      currentFileColouringBlock!.cancel()
      currentFileColouringBlock!.waitUntilFinished() // block on cancel completing...
      currentFileColouringBlock = nil
    }
    resetCurrentMovie()
    filelist.removeAll()
    namelist.removeAll()
    currentFile.removeAllItems()
    currentFile.addItem(withTitle: StringsCuts.NO_DIRECTORY_SELECTED)
    currentFile.selectItem(at: 0)
    lastfileIndex = 0
    removePlayerObserversAndItem()
  }
  
  /// Reset all element for a fresh file search (note that this leaves the current cutting jobs queue intact)
  func resetSearch()
  {
    resetFullModel()
    resetGUI()
  }
  
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
  
  /// KVO responder
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
          movie.videoDurationFromPlayer = durationInSeconds
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
              print("metadata duration = \(movie.meta.duration)")
              print("eit duration = \(movie.eit.eit.Duration)")
            }
            
            let videoDuration = CMTimeGetSeconds((self.monitorView.player?.currentItem?.duration)!)
            let videoDurationString = "\nplyr: \(CutEntry.hhMMssFromSeconds(videoDuration))"
            let durationsInSecs = movie.getBestDurationAndApDurationInSeconds(playerDuration: videoDuration)
            programDurationInSecs = durationsInSecs.best
            
            self.programDuration.stringValue = CutEntry.hhMMssFromSeconds(programDurationInSecs)
            self.programDuration.toolTip = recordingDurations(movie: movie).joined(separator: "\n").appending(videoDurationString)
            let startTime = CMTimeMake(Int64(movie.firstVideoPosition().cutPts), CutsTimeConst.PTS_TIMESCALE)
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
            let videoDuration = CMTimeGetSeconds((self.monitorView.player?.currentItem?.duration)!)
            let videoDurationString = "\nplyr: \(CutEntry.hhMMssFromSeconds(videoDuration))"
            let durationsInSecs = movie.getBestDurationAndApDurationInSeconds(playerDuration: videoDuration)
            programDurationInSecs = durationsInSecs.best
           if (debug) {
              print("Player ready to play")
              print("metadata duration = \(movie.meta.duration)")
            }
            self.programDuration.stringValue = CutEntry.timeTextFromPTS(UInt64(movie.meta.duration)!).appending(videoDurationString)
            self.programDuration.toolTip = recordingDurations(movie: movie).joined(separator: "\n")
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

  /// Removew all registered observers when the observee is changed
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
      if (self.monitorView.player?.currentItem != nil) {
        self.monitorView.player?.replaceCurrentItem(with: nil)
      }
    }
    self.monitorView.player = nil
  }
  
  /// Initializ the AVPlayer for the file URL given with filename
  /// and seek to the startTime
  
  func setupAVPlayerFor(_ fileURL:String, startTime: CMTime)
  {
    if (debug) { print ("Setting up av Player with string <\(fileURL)") }

    // remove observers before instantiating new objects
    removePlayerObserversAndItem()
    
    let videoURL = URL(string: fileURL)!
    let avAsset = AVURLAsset(url: videoURL)
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
      stepSwapperButton.title = self.monitorView.showsFrameSteppingButtons ? playerStringConsts.ffButtonTitle : playerStringConsts.stepButtonTitle
      self.monitorView.player?.seek(to: startTime)
      self.addPeriodicTimeObserver()
   }
    else {
      self.statusField.stringValue = "Invalid Time duration cannot work with"
    }
  }
  
  /// Common function to write the status field GUI entry to match
  /// the current user selection
  func setStatusFieldToCurrentSelection()
  {
    let arrayIndex = currentFile.indexOfSelectedItem
    self.statusField.stringValue = "file \(arrayIndex+1) of \(filelist.count)"
  }
  
  /// Conceptual start for a logging mechanism.  Use a function
  /// as a gateway to setting the string value of the status field
  func setStatusFieldStringValue(message: String, isLoggable: Bool)
  {
    self.statusField.stringValue = message
    // and log...
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
    let now = (self.monitorView.player?.currentTime())!
    let newtime = CMTimeAdd(now, CMTime(value: pts, timescale: CutsTimeConst.PTS_TIMESCALE))
    self.monitorView.player?.seek(to: newtime, completionHandler: seekCompletedOK)
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
    let seekTolerance = boundaryHunter.seekTolerance
    self.monitorView.player?.seek(to: CMTime(value: Int64(seekBarPos.cutPts), timescale: CutsTimeConst.PTS_TIMESCALE), toleranceBefore: kCMTimeZero, toleranceAfter: seekTolerance, completionHandler: seekCompletedOK)
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
  
  let callbackTimePeriodSecs = 0.25
  // from apple code sample
  func addPeriodicTimeObserver() {
    let debug = false
    // Invoke callback every second
    let interval = CMTime(seconds: callbackTimePeriodSecs,
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
          }
          else {
            self?.highlightCutTableEntryBefore(currentTime: Double(currentTime))
          }
        }
        else {
          self?.highlightCutTableEntryBefore(currentTime: Double(currentTime))
        }
        if (debug) { print("Saw callback end for \(currentTime)") }
    }
    // end closure addition
  }
  
  func sawDidDeminiaturize(_ notification: Notification) {
    // reset periodic observer
//    print(#file+#function)
    addPeriodicTimeObserver()
  }
  
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
  
  // TODO: Create a discrete view controller and dialog to capture this information when required
  // TODO: but since is relatively rare usage case, clunky old school call and response will do for now
  
  /// Look at user preferences and  collect the
  /// required information interactively from the user
  /// - returns : array of program switch and argument strings
  func getCutsCommandLineArgs() -> [String]
  {
    // string args wrapped in " for remote usage
    // double quotes are removed for local usage
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
  
  /// Create Operation for specific movie and add to Cutting Queue to related pvr
  /// - parameter URLToMovieToCut: full path % encoded url of recording file cuts file
  func cutMovie(_ URLToMovieToCut:String)
  {
    let shortTitle = Recording.programDateTitleFrom(movieURLPath: URLToMovieToCut)
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
      if (debug) { print("\(timestamp): Added  \(shortTitle) to Queue \(cutterQ.queue.name!)") }
    }
  }
  
  /// Get the queue associated with the configuration index
  /// - parameter index: Index into the pvrSettings array to find corresponding queue
  /// - returns: a serial queue
  func queueForPVR(index: Int) -> CuttingQueue?
  {
    // bounds check
    guard (systemSetup.pvrSettings.count > 0 && index >= 0 && index < systemSetup.pvrSettings.count) else { return nil }
    let queue = preferences.cuttingQueue(withTitle: systemSetup.pvrSettings[index].title)
    return queue
  }
  
  /// Append string to cut toolTip button
  /// - parameter message: string to append to cut button tooltip
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
  /// - parameter message: string to find and remove from cut button tooltip

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
  
  /// Method used in mainQueue callback to ensure that "current" filelist index is
  /// used rather than a closure "captured" version
  /// - parameter movieURLEntry : url of movie of interest
  /// - returns : index into filelist or nil
  
  func indexOfMovie(of movieURLEntry: String) -> Int?
  {
    return filelist.index(of: movieURLEntry)
  }
  
  // MARK: - TableView delegate, datasource and table related functions
  
  /// Get the view related to selected cell and populated the data value
  /// - parameter newMessage : replacement text
  /// - returns : populated view for tableView to use
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
  
  /// Return number of rows required
  /// - returns : count of cuts collection
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    return self.movie.cuts.count
  }
  
  /// Respond to change of row selection (both user and programatic will call this)
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
      cuttable = movie.isCuttable
    }
  }
  
  /// register swipe actions for table
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
  
  /// Called when user clicks in column
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
  
  /// General 'update the table' function
  /// - parameter cutEntry: entry to be selected or nil
  func updateTableGUIEntry(_ cutEntry: CutEntry?)
  {
    self.cutsTable.reloadData()
    selectCutTableEntry(cutEntry)
  }
  
  // MARK: - Menu file handling
  
  /// Action associated with File Open ... menu item
  /// If a file is successfully selected it is added to the
  /// general filelist collection and selected for editing
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
  
  /// Build a string from player and recording that shows all possible recording durations
  /// for use as a tooltip on GUI
  
  func recordingDurations(movie: Recording) -> [String]
  {
    let (eitDuration, metaDuration, ptsDuration) = movie.getStoredDurations()
    let eitString =  "eit: " + CutEntry.hhMMssFromSeconds(eitDuration)
    let metaString = "meta: " + CutEntry.hhMMssFromSeconds(metaDuration)
    let apString = "ap: " + CutEntry.hhMMssFromSeconds(ptsDuration)
    return [eitString, metaString, apString]
  }
  
  // MARK: - cutMark management functions
  
  /// Contains all undo / redo functions and data (copies of cutslist)
  var cutsUndoRedo: CutsEditCommnands?
  
  // currently fails to create bookmarks before first in and after last out
  // when recording is cut but with ads marked out
  @IBAction func clearBookMarks(_ send: AnyObject)
  {
    clearAllOfType(.BOOKMARK)
    cutsUndoRedo?.add(state: self.movie.cuts)
  }
  
  @IBAction func clearLastPlayMark(_ send: AnyObject)
  {
    clearAllOfType(.LASTPLAY)
    cutsUndoRedo?.add(state: self.movie.cuts)
  }
  
  /// Clears the cuts object of all IN and OUT marks
  /// - parameter sender: typically menu Item or Button, not used
  @IBAction func clearCutMarks(_ sender: AnyObject)
  {
    clearCutsOfTypes([.IN, .OUT])
    cutsUndoRedo?.add(state: self.movie.cuts)
  }
  
  /// Menu item action
  
  @IBAction func add10Bookmarks(_ sender: AnyObject)
  {
    suppressPlayerUpdate = true
    if (preferences.generalPreference().markMode == MARK_MODE.FIXED_SPACING_OF_MARKS) {
      movie.cuts.addFixedTimeBookmarks(interval: preferences.generalPreference().spacingModeDurationOfMarks)
    }
    else {
      movie.cuts.addPercentageBookMarks(preferences.generalPreference().countModeNumberOfMarks)
    }
    suppressPlayerUpdate = false
    cutsTable.reloadData()
    seekPlayerToMark(movie.firstVideoPosition())
    cuttable = movie.isCuttable
    cutsUndoRedo?.add(state: self.movie.cuts)
  }
  
  /// Clear all known mark types
  @IBAction func clearAllMarks(_ sender: AnyObject)
  {
    clearCutsOfTypes([.IN, .OUT, .LASTPLAY, .BOOKMARK])
    cutsUndoRedo?.add(state: self.movie.cuts)
  }
  
  /// Remove all cuts of the single prescribed type
  /// and update table
  /// - parameter markType: type of mark
  func clearAllOfType(_ markType: MARK_TYPE)
  {
    suppressPlayerUpdate = true
    movie.cuts.removeEntriesOfType(markType)
    cuttable = movie.isCuttable
    cutsTable.reloadData()
    suppressPlayerUpdate = false
  }
  
  /// Remove all cuts of the type contained in the array
  /// and update table
  /// - parameter markArray: array of enum values from MARK_TYPE
  func clearCutsOfTypes(_ markArray: [MARK_TYPE])
  {
    suppressPlayerUpdate = true
    for mark in markArray
    {
      clearAllOfType(mark)
    }
    cuttable = movie.isCuttable
    cutsTable.reloadData()
    suppressPlayerUpdate = false
  }
  
  
  /// 10% spacing add bookmark button action
  /// parameter sender: expect NSButton, but don't care, it is unused
  @IBAction func addBookMarkSet(_ sender: AnyObject)
  {
    suppressPlayerUpdate = true
    movie.cuts.addPercentageBookMarks()
    cutsTable.reloadData()
    suppressPlayerUpdate = false
    seekPlayerToMark(movie.firstVideoPosition())
    cuttable = movie.isCuttable
    cutsUndoRedo?.add(state: self.movie.cuts)
  }
  
  /// If present, remove the matching entry from the cut list.
  /// Update GUI on success
  func removeEntry(_ cutEntry: CutEntry)  {
    if (movie.cuts.removeEntry(cutEntry) )
    {
      cutsTable.reloadData()
      cuttable = movie.isCuttable
      cutsUndoRedo?.add(state: self.movie.cuts)
    }
  }
  
  /// Add a  bookmark at the current position
  /// TODO: current unused whilst CUT button is in the same GUI location
  /// TODO: shuffle buttons and re-enable
  @IBAction func addMark(sender: NSButton) {
    let markType = marksDictionary[sender.identifier!]
    let now = self.playerPositionInPTS()
    let mark = CutEntry(cutPts: now, cutType: markType!.rawValue)
    movie.cuts.addEntry(mark)
    updateTableGUIEntry(mark)
    cutsUndoRedo?.add(state: self.movie.cuts)

    if (markType == .IN || markType == .OUT)  {
      cuttable = movie.isCuttable
    }
  }
  
  /// Undo the last change to the cuts list. Go BACKWARD in history
  func cutsEditUndo()
  {
    print(#function)
    if let lastCuts = cutsUndoRedo?.getPrevious()
     {
      self.movie.cuts = lastCuts
      cutsTable.reloadData()
      cuttable = movie.isCuttable
     }
     else  {
      NSBeep()
    }
  }
  
  /// Redo the last cuts list change to the cuts list.  Go FORWARD in history
  func cutsEditRedo () {
    print(#function)
    if let nextCuts = cutsUndoRedo?.next()
    {
      self.movie.cuts = nextCuts
      cutsTable.reloadData()
      cuttable = movie.isCuttable
    }
    else {
      NSBeep()
    }
  }
  
  // MARK: - Advertisment boundary pickers
  var boundaryAdHunter : boundaryHunter?
  let initialStep = 90.0      // TODO: add to user config panel
  let nearEnough = 1.0/50.0   // TODO: add to user config panel 1/25 th is frame level
  
  
  /// Get Nearest cutmark type PRECEEDING the current player position.
  /// Has a dummy .LASTPLAY value if there is no cutmark before the current position
  var prevCut: MARK_TYPE {  // nearest cutmark before current position
    get {
      let inOut = movie.cuts.inOutOnly
      guard (inOut.count > 0 && monitorView.player != nil) else {
        return .LASTPLAY
      }
      let now = (monitorView.player?.currentTime().seconds)!
      var index = 0
      var cutIsAfterPlayer = (inOut[index].asSeconds() > now)
      while !cutIsAfterPlayer && index+1 < (inOut.count) {
        index += 1
        cutIsAfterPlayer = inOut[index].asSeconds() > now
      }
      if (index > 0) {
        return (cutIsAfterPlayer) ? MARK_TYPE.lookupOnRawValue(inOut[index-1].cutType)! : MARK_TYPE.lookupOnRawValue(inOut[index].cutType)!
      }
      else {
        return !cutIsAfterPlayer ? MARK_TYPE.lookupOnRawValue(inOut[0].cutType)! : .LASTPLAY
      }
    }
  }
  
  @IBOutlet weak var forwardHuntButton: NSButton!
  @IBOutlet weak var backwardHuntButton: NSButton!
  @IBOutlet weak var resetHuntButton: NSButton!
  @IBOutlet weak var doneHuntButton: NSButton!
  
  /// Action to take when users says that "this is in a program".
  /// Bound to the GUI "P" Button, the "z" keyboard keydown event
  /// and the "program" speech command
  /// - parameter: GUI Button
  @IBAction func inProgram(_ sender: NSButton) {
    if (prevCut == .IN ) {
      huntForward( sender )
    }
    else if (prevCut == .OUT) {
      huntBackward(sender)
    }
    else // no earlier cuts edge conditions
    {
      // assume begining of program
      huntForward(sender)
    }
  }
  
  /// Action to take when user says "this is in an Advertisement"
  /// - parameter: GUI Button
  @IBAction func inAdvertisment(_ sender: NSButton) {
    if (prevCut == .IN ) {
      huntBackward( sender )
    }
    else if (prevCut == .OUT) {
      huntForward(sender)
    }
    else // no earlier cuts edge conditions
    {
      // assume begining of program
      huntBackward(sender)
    }
    
  }
  /// Hunt forward for advert / program boundary
  /// Change colour when close enough
  /// - parameter: GUI Button
  @IBAction func huntForward(_ sender: NSButton) {
    doBinaryJump(button: sender, direction: .forward)
  }
  
  /// Hunt backward for advert / program boundary
  /// Change colour when close enough
  /// - parameter: GUI Button
  @IBAction func huntBackward(_ sender: NSButton) {
    doBinaryJump(button: sender, direction: .backward)
  }
  
  /// User knows that they clicked wrong (ad/prog) button - reset to start state
  /// - parameter: GUI Button
  @IBAction func huntReset(_ sender: NSButton) {
    guard self.monitorView.player != nil else { return }
    guard boundaryAdHunter != nil else { return }
    boundaryAdHunter?.reset()
    setStatusFieldStringValue(message: logMessage.adHuntReset, isLoggable: false)
    huntButtonsReset()
  }
  
  /// Found boundary or completely lost, so clear the hunter and reset the buttons
  /// - parameter: GUI Button
  @IBAction func huntDone(_ sender: NSButton) {
    huntButtonsReset()
    let outCutDuration = movie.cuts.simpleOutCutDurationInSecs()
    let doneMessage = "Advert hunt done ("+CutEntry.hhMMssFromSeconds(outCutDuration)+")"
    setStatusFieldStringValue(message: doneMessage, isLoggable: false)
  }
  
  var voiceRecognition = false
  
  @IBOutlet weak var microphoneButton: NSButton!
  
  @IBAction func toggleVoiceRecognition(_ sender: NSButton) {
    if (voiceRecognition) {
      mySpeechRecogizer?.stopListening()
      mySpeechRecogizer = nil
      voiceRecognition = false
      sender.layer?.backgroundColor = NSColor.red.cgColor
    }
    else {
      mySpeechRecogizer = NSSpeechRecognizer()
      mySpeechRecogizer?.commands = [String](speechDictionary.keys)
      mySpeechRecogizer?.delegate = self
      mySpeechRecogizer?.listensInForegroundOnly = true
      mySpeechRecogizer?.blocksOtherRecognizers = true
      voiceRecognition = true
      sender.layer?.backgroundColor = NSColor.green.cgColor
      mySpeechRecogizer?.startListening()
   }
  }
  
  
  /// Delegate function
  
  func speechRecognizer(_ sender: NSSpeechRecognizer, didRecognizeCommand command: String) {
    print("saw command \(command)")
    // excute associated command function and cache for re-use
    if let voiceCommandActionAndButton = speechDictionary[command]
    {
      voiceCommandActionAndButton.action(voiceCommandActionAndButton.button)
      // now cache the last command for re-use with "repeat" command
      speechDictionary.updateValue(voiceCommandActionAndButton, forKey: "repeat")
    }
  }
  
  
  override func keyDown(with event: NSEvent) {
//    print("saw keyDown keycode value \(event.keyCode)")
    
    if (event.keyCode == UInt16(kVK_Delete)) { interpretKeyEvents([event]);return } // interpret has dealt with it
    if (event.type == NSEventType.keyUp || event.type == NSEventType.keyDown) && NSEvent.modifierFlags().isEmpty
    {
      if let keyString = event.characters {
//        print(">>\(keyString)<<")

        if (keyString == "z") { // z
          inProgram(forwardHuntButton)
          return
        }
        
        if (keyString == "/") {
          inAdvertisment(backwardHuntButton)
          return
        }
        
        if (keyString == "s") {
          seekToAction(seekButton1c)
          return
        }
        
        if (keyString == "x") {
          addMark(sender: inButton)
          huntDone(doneHuntButton)
          return
        }
        if (keyString == ".") {
          addMark(sender: outButton)
          huntDone(doneHuntButton)
          return
        }
        
        if (keyString == " ") {
          seekToAction(seekButton2c)
          return
        }
        
        if (keyString == ";" ) {
          huntReset(resetHuntButton)
          return
        }
        
        // add a mark that is the complement of previous in / out
        if (keyString == "c" || keyString == ",") {
          addMatchingCutMark(toMark: prevCut)
          return
        }
      }
    }
    super.keyDown(with: event)
  }

  /// Add mark that is complementary to the previous cut mark.
  /// Beep and ignor any mark that is not In or Out
  /// should never happen, however....if in doubt Beep
  func addMatchingCutMark(toMark: MARK_TYPE)
  {
    switch toMark {
      case .IN:
        addMark(sender: outButton)
        huntDone(doneHuntButton)
        NSBeep();NSBeep();NSBeep()
      case .OUT:
        addMark(sender: inButton)
        huntDone(doneHuntButton)
        NSBeep();NSBeep();NSBeep()
      default: NSBeep()
    }
  }
  
  /// Respond to user taping the "delete" button on the keyboard to remove IN or OUT mark
  override func deleteBackward(_ sender: Any?) {
//    print("Backward delete?")
    let selectedRow = cutsTable.selectedRow
    if (selectedRow >= 0) {
      let cutEntry = movie.cuts.entry(at: selectedRow)
      if (cutEntry?.type == MARK_TYPE.OUT || cutEntry?.type == MARK_TYPE.IN)
      {
        movie.cuts.remove(at: selectedRow)
        cutsTable.reloadData()
        cuttable = movie.isCuttable
        cutsUndoRedo?.add(state: movie.cuts)
      }
//      print ("cell is \(cutEntry?.asString())")
    }
  }
  
//  /// Insert a new element into a path string
//  func insertPathElement(newElement: String, into path: String, at index: Int) -> String
//  {
//    var elements = path.components(separatedBy: "/")
//    elements.insert(newElement, at: index)
//    return elements.joined(separator: "/")
//  }
  
//  // MARK: - Recording removal
  
//  override func mouseDown(with event: NSEvent) {
////    print ("saw mouse down")
////    let currentFileSubmenu = NSMenu()
////    let deleteMenuItem = NSMenuItem(title: "Delete", action: #selector(deleteRecording(_:)), keyEquivalent: "")
////    currentFileSubmenu.addItem(deleteMenuItem)
////    currentFile.menu?.setSubmenu(currentFileSubmenu, for: currentFile.selectedItem!)
//    if (event.type == NSEventType.rightMouseDown)
//    {
////       print("saw right click")
//    }
//    else {
//      super.mouseDown(with: event)
//    }
//  }
  
  override func rightMouseDown(with event: NSEvent) {
    print("saw "+#function)
//        let currentFileSubmenu = NSMenu()
//        let deleteMenuItem = NSMenuItem(title: "Delete", action: #selector(deleteRecording(_:)), keyEquivalent: "")
//        currentFileSubmenu.addItem(deleteMenuItem)
//        let item = currentFile.selectedItem
//        item?.view?.menu = currentFileSubmenu
  }
  
  
  @IBOutlet weak var deleteRecordingButton: NSButton!
  @IBOutlet weak var stepSwapperButton: NSButton!
  
  /// Nominal Delete of recording
  /// Really move to .Trash subdirectory
  @IBAction func deleteRecording(_ sender: NSButton)
  {
    let result = deleteRecording(recording: self.movie, with: NSDocumentController.shared())
    if result.status != true {
      setStatusFieldStringValue(message: result.message, isLoggable: true)
      NSBeep()
    }
  }
  
  /// If a floating control is present, then swap the fastforward and step frame
  /// controls.  Set the Button title to correspond to state change
  /// - parameter  action button
  
  @IBAction func swapStepControls(_ sender: NSButton)
  {
    self.monitorView.showsFrameSteppingButtons = !self.monitorView.showsFrameSteppingButtons
    stepSwapperButton.title = monitorView.showsFrameSteppingButtons ? playerStringConsts.ffButtonTitle:playerStringConsts.stepButtonTitle
  }
  
  override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    if (segue.identifier == "EITEdit") {
      print("Saw menu EITEdit segue")
      let eit = sender as! ShortEventDescriptorViewController
      eit.movie = self.movie
    }
  }
}
