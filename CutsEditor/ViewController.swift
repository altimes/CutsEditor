//
//  ViewController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 2/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

// icons from http://icon-icons.com/icon/scissors/50046

import Cocoa
import AVFoundation
import AVKit
import Carbon.HIToolbox

typealias FindCompletionBlock = ( _ URLArray:[String]?,  _ forSuffix: String,  _ didCompleteOK:Bool) -> ()
typealias MovieCutCompletionBlock  = (_ message: String, _ resultValue: Int, _ wasCancelled: Bool) -> ()
typealias MovieCutStartBlock  = (_ shortTitle: String) -> ()

/// player current state / commands
enum PlayerCommand {
  case play,pause
}

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
  static let indexOfSelectedFileMsg = "file %d of %d"
  static let huntDoneMsg = "Advert hunt done (%@)"
}

let nilString = "nil"

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate, NSSpeechRecognizerDelegate, KeyStrokeCatch
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
  @IBOutlet weak var currentFile: PopUpWithStatusFilter!
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
  
  @IBOutlet weak var filmStrip: FilmStrip!
  @IBOutlet weak var descriptionScrollView: NSScrollView!
  
  // control to enable or disable video part of presentation
  @IBOutlet weak var isVideoEnabled: NSButton!
  
  // MARK: model
  
  var movie = Recording()
  
  var imageGenerator : AVAssetImageGenerator?
  
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
  
  /// SeekCompleted Flag.  Used to try and handle the consequence that "skipping" brings player time into
  /// video file time scale (accounting to gaps in pts), whilst simply "playing through" gaps does not generate
  /// a jump in the player reported time.  Thus to convert from player_time to video_time we need to know if
  /// a skip has occured that will have brought to two time back into sync.  This is such that we can drive
  /// the current position in the timeline control.
  var seekCompleted = true
  
  typealias SeekParams = (toTime:CMTime, beforeTolerance:CMTime, afterTolernace: CMTime)
  /// array of seek requests that have not been processed
  /// used to store seeks that cannot be done because a current seek it still running
  /// pending seek is executed by completion handler
  var pendingSeek = [SeekParams]()
  //  var lastSkippedToTime = PtsType(0)
  
  /// Computed var checks if video was playing
  var isPlaying: Bool {
    get {
      if (self.monitorView.player != nil) {
        return (self.monitorView.player!.rate != 0.0)
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
        if movie.cuts.inOutOnly.firstIndex(of: entry) == 0 {
          pts = entry.cutPts
        }
      }
      return pts
    }
  }
  /// opaque var used by video player timed callback
  private var timeObserverToken: Any?
  
  var preferences = NSApplication.shared.delegate as! AppPreferences
  
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
  var adHunterPrefs = adHunterPreferences()
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
  var lastPeriodicClocktime = DispatchTime.now()
  
  /// ensure that user selecting a row is not overriden with timed observed updates
  var suppressTimedUpdates = false
  
  /// flag to control if out/in block skipping is honoured
  var honourOutInMarks = true
  
  /// object to perform speech processing
  var mySpeechRecogizer : NSSpeechRecognizer?
  
  /// Time line for movie, showing cut marks, bookmarks, current position and PCR resets
  /// control that allows click and drag to skip within movie and time zoom for more precise
  /// positioning
  var timelineView : TimeLineView?
  
  /// track when frame changes to control suppression of
  /// player rate changes
  var monitorFrameChangeDate: Date?
  var oldPlayerRate : Float?
  
  //  /// track advert boundary hunting state
  //  var boundaryDoubleGreen = false
  
  /// alias for typical button action from storyboard.
  /// function that has a NSButton arg and returns nothing
  typealias buttonAction = (NSButton) -> ()
  typealias FunctionAndButton = (action: buttonAction, button:NSButton)
  //  typealias buttonAction = (NSButton) -> ()
  /// Dictionary of voice commands with keys that have a one-to-one map to a GUI Button.
  /// TODO: do the I18N to make configurable.  Currrently static english
  var speechDictionary = [String: FunctionAndButton]()
  var defaultControlKeyDictionary = [String: FunctionAndButton]()
  
  /// speech creator
  let voice = NSSpeechSynthesizer()
  
  /// observer ID
  let progressBarVisibilityChange = "progressBarVisibilityChange"
  
  // TODO: create protocol to pass value into instance
  //  var filmstripFrameGap: Double = 0.2         // seconds
  var filmstripFrameGap: Double = 30.0         // seconds
  
  /// number of steps(?) to move marker on right/left arrow for fine adjustment
  /// TODO: make yet another configuration item
  var creepSteps = 2
  
  /// flag set when closing down
  var beingTerminated = false
  
  
  
  // MARK: - functions start here
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    
    previousButton.isEnabled = false
    nextButton.isEnabled = false
    cutButton.isEnabled = false
    fileWorkingName = StringsCuts.NO_FILE_CHOOSEN
    statusField.stringValue = StringsCuts.NO_DIRECTORY_SELECTED
    currentFile.removeAllItems()
    currentFile.addItem(withTitle: StringsCuts.NO_FILE_CHOOSEN)
    currentFile.selectItem(at: 0)
    //   currentFile.filter?.menu?.autoenablesItems = false
    cutsTable.dataSource = self
    cutsTable.delegate = self
    actionsSetEnabled(false)
    
    skips = preferences.skipPreference()
    sortPrefs = preferences.sortPreference()
    generalPrefs = preferences.generalPreference()
    systemSetup = generalPrefs.systemConfig
    playerPrefs = preferences.videoPlayerPreference()
    self.monitorView.postsFrameChangedNotifications = true
    //    self.monitorView.controlsStyle = AVPlayerViewControlsStyle.none
    //-----------
    let trackingAreas = self.monitorView.trackingAreas
    if (trackingAreas.count > 0) {
      if (debug) { print("track area (viewDidLoad) = \(trackingAreas)") }
      //      for area in trackingAreas {
      //        self.monitorView.removeTrackingArea(area)
      //      }
    }
    else {
      if (debug) { print("no tracking areas") }
    }
    //-----------
    
    NotificationCenter.default.addObserver(self, selector: #selector(skipsChange(_:)), name: NSNotification.Name(rawValue: skipsDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(sortChange(_:)), name: NSNotification.Name(rawValue: sortDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(adHunterChange(_:)), name: NSNotification.Name(rawValue: adHunterDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(generalChange(_:)), name: NSNotification.Name(rawValue: generalDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(playerChange(_:)), name: NSNotification.Name(rawValue: playerDidChange), object: nil )
    
    NotificationCenter.default.addObserver(self, selector: #selector(fileToOpenChange(_:)), name: NSNotification.Name(rawValue: fileOpenDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(fileSelectPopUpChange(_:)), name: NSPopUpButton.willPopUpNotification, object: nil )
    
    NotificationCenter.default.addObserver(self, selector: #selector(progressBarVisibilityChange(_:)), name: NSNotification.Name(rawValue: progressBarVisibilityChange), object: nil)
    
    NotificationCenter.default.addObserver(self, selector: #selector(sawDidDeminiaturize(_:)), name: NSWindow.didDeminiaturizeNotification, object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(sawMonitorViewFrameChange(_:)), name: NSView.frameDidChangeNotification, object: self.monitorView)
    
    NotificationCenter.default.addObserver(self, selector: #selector(applicationTerminating(_:)), name: NSNotification.Name(rawValue: applicationIsTerminating), object: nil)
    
    
    //    AVPlayerItemTimeJumped
    NotificationCenter.default.addObserver(self, selector: #selector(sawTimeJumpInPlayer(_:)), name: NSNotification.Name.AVPlayerItemTimeJumped, object: nil)
    // Movie selector has changed programmatically
    NotificationCenter.default.addObserver(self, selector: #selector(popUpWillChange(_:)), name: NSNotification.Name.PopUpWillChange, object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(popUpHasChanged(_:)), name: NSNotification.Name.PopUpHasChanged, object: nil )
    
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
    
    /// Define voice commands that are equivalent to button clicks.
    /// Dictionary key is the voice phrase required, value is a touple of the equivalent button
    /// and its associated function.
    speechDictionary =
      [voiceCommands.advert: (inAdvertisment,backwardHuntButton),
       voiceCommands.program:(inProgram,forwardHuntButton),
       voiceCommands.done:(huntDone,doneHuntButton),
       voiceCommands.reset:(huntReset,resetHuntButton),
       voiceCommands.inCut:(addMark,inButton),
       voiceCommands.outCut:(addMark,outButton),
       voiceCommands.skipForward:(seekToAction,seekButton2c),
       voiceCommands.skipBackward:(seekToAction,seekButton1c),
       voiceCommands.next:(nextButton,nextButton),
       voiceCommands.previous:(prevButton,previousButton),
       voiceCommands.repeatLast:(seekToAction,seekButton2c)  // non-destructive initial value for "repeat last voice command"
      ]
    
    /// Define keyboard commands that are equivalent to button clicks.
    /// Dictionary key is the keystroke required, value is a touple of the equivalent button
    /// and its associated function.
    defaultControlKeyDictionary =
      [keyBoardCommands.advert: (inAdvertisment,backwardHuntButton),
       keyBoardCommands.program:(inProgram,forwardHuntButton),
       //        keyBoardCommands.done:(huntDone,doneHuntButton),
       keyBoardCommands.reset:(huntReset,resetHuntButton),
       keyBoardCommands.inCut:(addMark,inButton),
       keyBoardCommands.outCut:(addMark,outButton),
       keyBoardCommands.skipForward1:(seekToAction,seekButton2c),
       keyBoardCommands.skipForward2:(seekToAction,seekButton2c),
       keyBoardCommands.skipBackward:(seekToAction,seekButton1c),
       keyBoardCommands.undo:(undoJumpAction, undoJumpButton),
      ]
    self.filmStrip.addTimeTextLabels()
    self.monitorView.addObserver(self, forKeyPath: "videoBounds", options: NSKeyValueObservingOptions.new, context: nil)
    self.monitorView.addObserver(self, forKeyPath: "isReadyForDisplay", options: NSKeyValueObservingOptions.new, context: nil)
    // testing for missing keydown events
    NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.keyDown, handler: myKeyDownEvent)
    
    // make VC visible in button
    currentFile.parentViewController = self
    
  }
  
  func myKeyDownEvent(event: NSEvent) -> NSEvent
  {
    //    let playingState = (self.monitorView.player as! ObservedAVPlayer).playingState
    //    if (debug) {
    //      print("Entered block " + #function)
    //      if let keyString = event.characters  {
    //        print("keystroke is >\(keyString)<")
    //        print("playing state is \(playingState)")
    //      }
    //      else {
    //        print("keydown without keystring ?")
    //      }
    //    }
    return event
  }
  
  override func viewDidAppear() {
    // set window delegate
    self.view.window?.delegate = self
    let origin = CGPoint(x:50,y:5)
    self.view.window?.setFrameOrigin(origin)
    self.monitorView.window!.delegate = self
    self.filmStrip.updateTimeTextLabels(timeStep: self.preferences.videoPlayerPreference().filmStripSpacing)
  }
  
  func windowShouldClose(_ sender: NSWindow) -> Bool {
    if (debug) { printLog(log:(#file+" "+#function) as AnyObject) }
    NSApplication.shared.terminate(self)
    return true
  }
  
  /// testing
  @objc func sawTimeJumpInPlayer(_ notification: Notification)
  {
    if let avItem = notification.object as? AVPlayerItem
    {
      if (debug) { print ("current time is \(avItem.currentTime().seconds)") }
    }
    else {
      if (debug) { print("que?") }
    }
  }
  
  // Popup is about to change, so flush current movie
  @objc func popUpWillChange(_ notification: Notification)
  {
    changeFile(-1)
  }
  
  // Popup has Changed update GUI
  @objc func popUpHasChanged(_ notification: Notification)
  {
    changeFile(-1)
  }
  
  
  
  /// testing
  @objc func sawRateChangeInPlayer(_ notification: Notification)
  {
    print("Caught cmclock rate Change")
    let tb = notification.object as! CMTimebase
    let rate = CMTimebaseGetRate(tb)
    print("rate is \(rate)")
  }
  
  /// Set the termination flag
  @objc func applicationTerminating(_ notification: Notification)
  {
    beingTerminated = true
  }
  
  @objc func sawMonitorViewFrameChange(_ notification: Notification)
  {
    wasPlaying = isPlaying
    if (debug) {
      printLog(log: "Saw Monitor View Frame Change \(self.monitorView.frame)" as AnyObject)
      printLog(log: "was playing \(wasPlaying)" as AnyObject)
    }
    if let currentRate = self.monitorView.player?.rate
    {
      if (debug) {print("current rate is \(currentRate)") }
    }
    if (timelineView != nil) { resetTimeLineViewFrame() }
    monitorFrameChangeDate = Date()
    if (wasPlaying) {
      if (oldPlayerRate != nil) {
        videoPlayer(.play, at: oldPlayerRate!)
      }
      else {
        videoPlayer(.play)
      }
    }
    else {
      videoPlayer(.pause)
    }
    if (debug) { printLog(log: "\(String(describing: oldPlayerRate))" as AnyObject) }
  }
  
  func videoPlayer(_ playCommand: PlayerCommand, at rate :Float = Float(1.0))
  {
    if let myPlayer = self.monitorView.player as? ObservedAVPlayer {
      myPlayer.playCommandFromUser = playCommand
    }
    switch playCommand {
    case .play:
      self.monitorView.player?.play()
      self.monitorView.player?.rate = rate
    case .pause:
      self.monitorView.player?.pause()
    }
  }
  
  // brute force shutdown app on window RED X window closure - I don't want to think about issues
  // related to multiple concurrent edits - does not have a valid use case IMHO
  func windowWillClose(_ notification: Notification) {
    //    print(#file+" "+#function)
    if let token = timeObserverToken
    {
      self.monitorView.player?.removeTimeObserver(token)
      self.timeObserverToken = nil
    }
    videoPlayer(.pause)
    NotificationCenter.default.removeObserver(self)
  }
  
  func windowWillMiniaturize(_ notification: Notification)
  {
    let undefined = 0.0
    if (debug) { print(#file+" "+#function+" \(self.monitorView.player?.rate ?? Float(undefined))") }
    if let activePlayer = self.monitorView.player
    {
      wasPlaying = (activePlayer.rate) > Float(0.0)
      videoPlayer(.pause)
    }
  }
  
  func windowDidDeminiaturize(_ notification: Notification) {
    if wasPlaying {
      self.monitorView.player?.play()
      if let myPlayer = self.monitorView.player as? ObservedAVPlayer {
        myPlayer.playCommandFromUser = .pause
      }
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
  
  /// Brute force approach (KISS) to boundary/frame changes in the super view.
  /// Simply destroy and re-create the time line view
  /// TODO: develop the code to modify the view to track with the containing view
  func resetTimeLineViewFrame()
  {
    timelineView = createTimelineOverlayView()
    updateCutsMarksGUI()
  }
  
  /// picks up when movie goes fullscreen.  Downside is that it is called multiple times
  override func viewDidLayout() {
    super.viewDidLayout()
    if (timelineView != nil) { resetTimeLineViewFrame() }
    let rate = "\(self.monitorView.player?.rate ?? -1000.0)"
    if (debug) {
      print("viewDidLayoutCalled")
      print("monitor frame size \(self.monitorView.frame)")
      print("during layout player rate is \(rate)")
    }
  }
  
  /// Observer function to handle the "seek" changes that are made
  /// during changes in the preferences dialog
  @objc func skipsChange(_ notification: Notification)
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
      if let oldIndex = itemTitles.firstIndex(of: title)
      {
        self.currentFile.item(at: newIndex)?.attributedTitle = menuItems[oldIndex].attributedTitle
        self.currentFile.item(at: newIndex)?.toolTip = menuItems[oldIndex].toolTip
      }
    }
  }
  
  /// Observer function to handle the "sort order" changes that are made
  /// during changes in the preferences dialog
  
  @objc func sortChange(_ notification: Notification)
  {
    // get the changed skip setting and update the gui to match
    self.sortPrefs = preferences.sortPreference()
    // now update the GUI
    if (filelist.count > 0) {
      // save current item
      let savedCurrentDiskURL = filelist[filelistIndex]
      let savedLastDiskURL = filelist[lastfileIndex]
      
      sortNames()
      lastfileIndex = filelist.firstIndex(of: savedLastDiskURL)!
      
      let (itemTitles, itemArray) = retainAttributedStringList(self.currentFile)
      self.currentFile.removeAllItems()
      self.currentFile.addItems(withTitles: namelist)
      restoreAttributedStringList(currentFile, itemTitles: itemTitles, menuItems: itemArray)
      
      // reselect the current program in the resorted list
      currentFile.selectItem(at: filelist.firstIndex(of: savedCurrentDiskURL)!)
      mouseDownPopUpIndex = nil
      setPrevNextButtonState(filelistIndex)
      changeFile(filelistIndex)
    }
  }
  
  /// Observer function to handle the "ad Hunter" changes that are made
  /// during changes in the preferences dialog
  
  @objc func adHunterChange(_ notification: Notification)
  {
    //    print("Saw call "+#function)
    // get the changed ad hunter parameters and update the system responses to match
    self.adHunterPrefs = preferences.adHunterPreference()
    boundaryAdHunter?.setFromPreferences(prefs: self.adHunterPrefs)
  }
  
  /// Observer function to handle the "General Preferences" changes that are made
  /// and saved during changes in the preferences dialog
  
  @objc func generalChange(_ notification: Notification)
  {
    // get the changed general settings and update the gui to match
    self.generalPrefs = preferences.generalPreference()
    self.systemSetup = self.generalPrefs.systemConfig
  }
  
  /// Observer function to handle the "Player Config Preferences" changes that are made
  /// and saved during changes in the preferences dialog
  
  @objc func playerChange(_ notification: Notification)
  {
    // get the changed general settings and update the gui to match
    self.playerPrefs = preferences.videoPlayerPreference()
    self.monitorView.controlsStyle = playerPrefs.playbackControlStyle == videoControlStyle.inLine ? AVPlayerViewControlsStyle.inline : AVPlayerViewControlsStyle.floating
    self.monitorView.showsFrameSteppingButtons = !playerPrefs.playbackShowFastForwardControls
    stepSwapperButton.title = self.monitorView.showsFrameSteppingButtons ? playerStringConsts.ffButtonTitle:playerStringConsts.stepButtonTitle
    stepSwapperButton.isEnabled =  (playerPrefs.playbackControlStyle == videoControlStyle.floating)
    self.honourOutInMarks = playerPrefs.skipCutSections
    self.filmstripFrameGap = playerPrefs.filmStripSpacing
    self.filmStrip.updateTimeTextLabels(timeStep: self.preferences.videoPlayerPreference().filmStripSpacing)
  }
  
  /// Observer function that responds to the selection of
  /// a single file (rather than a directory) to be used.
  /// Notitication has filename is the notification "object"
  @objc func fileToOpenChange(_ notification: Notification)
  {
    let filename = notification.object as! String
    let filePath = String(NSString(string: filename).deletingLastPathComponent) + "/"
    let pathComponents = filePath.components(separatedBy: "/")
    // reconstruct a "normal" mount point path
    if pathComponents.count >= 3 {
      let rootPath = "/" + pathComponents[1] + "/" + pathComponents[2] + "/"
      (isRemote, pvrIndex) = pvrLocalMount(containedIn: rootPath)
    }
    if (!appendSingleFileToListAndSelect(filename))
    {
      let message = String.localizedStringWithFormat( StringsCuts.FAILED_TRYING_TO_ACCESS, filename)
      self.statusField.stringValue = message
    }
  }
  
  /// Observer function that responds to a mouseDown event on the
  /// file select popupbutton - purpose is to pick up and retain
  /// the current selection index BEFORE it is changed
  @objc func fileSelectPopUpChange(_ notification: Notification) {
    mouseDownPopUpIndex = self.currentFile.indexOfSelectedItem
  }
  
  /// Observer function that responds change of visibility of progress bar.
  /// This function disables the "Delete Recording" button whilst the
  /// colour coding is being worked out
  /// It is a hack to prevent crashes if a file is deleted whilst
  /// scanning for colour coding is going on (array content changes)
  @objc func progressBarVisibilityChange(_ notification: Notification)
  {
    deleteRecordingButton.isEnabled = progressBar.isHidden
    if let _ = currentFile.filter {
      if (debug) { print("file index is \(currentFile.stringValue)")}
      currentFile.filter!.filterMenuEnabled = progressBar.isHidden
    }
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
    nextButton.isEnabled = (filelistIndex >= 0) && (filelistIndex < (filelist.count-1))
    if (isVideoEnabled.state == NSControl.StateValue.off) {
      deleteRecordingButton.isEnabled = (previousButton.isEnabled || nextButton.isEnabled)
    }
  }
  
  /// Flush any pending changes back to the file system if
  /// there are any at index given
  
  func flushPendingChangesFor(_ indexSelector: FileToHandle) -> Bool
  {
    let index = (indexSelector == FileToHandle.current) ? filelistIndex : lastfileIndex
    var proceedWithWrite = true
    var abandonWrite = false
    let validCutsEntries = movie.hasCutsToPerform ? movie.isCuttable : true
    
    guard cutsModified else {
      return true
    }
    
    if (!validCutsEntries)
    {
      setStatusFieldStringValue(isLoggable: true, message: movie.cuts.lastValidationMessage)
      NSSound.beep()
      let badCuts = NSAlert()
      badCuts.alertStyle = NSAlert.Style.warning
      let informativeText = movie.cuts.lastValidationMessage
      badCuts.informativeText = informativeText
      badCuts.window.title = "Cut Marks Problem"
      badCuts.messageText = "Marks unbalanced"
      badCuts.addButton(withTitle: "Abandon File Change")
      badCuts.addButton(withTitle: "Save anyway")
      badCuts.addButton(withTitle: "Abandon Save")
      let result = badCuts.runModal()
      if (result == NSApplication.ModalResponse.alertFirstButtonReturn)
      {
        return false
      }
      // do nothing, let the write process
      proceedWithWrite = result == NSApplication.ModalResponse.alertSecondButtonReturn
      // abandon write and proceed
      abandonWrite = result == NSApplication.ModalResponse.alertThirdButtonReturn
    }
    
    if (generalPrefs.autoWrite == CheckMarkState.unchecked) {
      // pop up a modal dialog to confirm overwrite of cuts file
      let overWriteDialog = NSAlert()
      overWriteDialog.alertStyle = NSAlert.Style.critical
      overWriteDialog.informativeText = "Will overwrite the \(ConstsCuts.CUTS_SUFFIX) file"
      overWriteDialog.window.title = "Save File"
      let programname = self.currentFile.item(at: index)!.title.replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
      overWriteDialog.messageText = "OK to overwrite file \n\(programname)"
      overWriteDialog.addButton(withTitle: "OK")
      overWriteDialog.addButton(withTitle: "Cancel")
      overWriteDialog.addButton(withTitle: "Don't Save")
      
      let result = overWriteDialog.runModal()
      proceedWithWrite = result == NSApplication.ModalResponse.alertFirstButtonReturn
      abandonWrite = result == NSApplication.ModalResponse.alertThirdButtonReturn
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
        setStatusFieldStringValue(isLoggable: true, message: StringsCuts.FILE_SAVE_FAILED )
        // TODO:  needs some sort of try again / give up options
        return false
      }
    }
    return abandonWrite
  }
  
  
  let overlayViewId = "1001"
  let overlayHeight = CGFloat(100.0)
  let overlayWidth = CGFloat(150.0)
  
  func createVideoOverlayView() -> NSTextView
  {
    var overlayFrame = NSRect(x: 50.0, y: 50.0, width: overlayWidth, height: overlayHeight)
    let monitorFrame = self.monitorView.frame
    let labelYpos = (monitorFrame.height - overlayHeight) / 2.0
    let labelXpos = (monitorFrame.width - overlayWidth) / 2.0
    overlayFrame = NSRect(x: labelXpos, y: labelYpos, width: overlayWidth, height: overlayHeight)
    let label = NSTextView(frame: overlayFrame)
    label.identifier = NSUserInterfaceItemIdentifier(rawValue: overlayViewId)
    label.isHorizontallyResizable = true
    label.isVerticallyResizable = false
    //        print("inset is \(label.textContainerInset)")
    //        print(label.bounds)
    self.monitorView.contentOverlayView?.addSubview(label)
    return label
    
  }
  
  func removeOverlayView() {
    if let view = videoOverlayView
    {
      view.removeFromSuperview()
    }
  }
  
  
  var videoOverlayView : NSTextView?
  {
    get {
      if let subViews = self.monitorView.contentOverlayView?.subviews {
        for view in subViews {
          if view.identifier!.rawValue == overlayViewId {
            if let textView = view as? NSTextView
            {
              return textView
            }
            else {
              return nil
            }
          }
        }
      }
      return nil
    }
  }
  
  /// find the timeline view from the view heirarchy
  func getTimeLineView() -> TimeLineView?
  {
    if let subViews = self.monitorView?.subviews {
      for view in subViews {
        if view.identifier?.rawValue == timelineViewId {
          if let timelineView = view as? TimeLineView
          {
            return timelineView
          }
          else {
            return nil
          }
        }
      }
    }
    return nil
  }
  
  /// Remove the timeline from the view heirarchy and stop it responding to actions
  func removeTimelineView()
  {
    if let view = getTimeLineView()
    {
      view.resignFirstResponder()
      view.layer?.removeFromSuperlayer()
      view.removeFromSuperview()
    }
  }
  
  
  /// creates / updates an overlay on the video plane.
  ///
  func updateVideoOverlay(updateText: String?) {
    var label: NSTextView
    guard updateText != nil else {
      removeOverlayView()
      return
    }
    
    if (debug && updateText != nil) { print("\n\n<\(updateText!)>")}
    if let newText = updateText {
      if let subView = videoOverlayView {
        label = subView
        label.string = ""
      }
      else
      {
        label = createVideoOverlayView()
      }
      
      var fontSize:CGFloat = 64
      let fudgeFactor:CGFloat = 1.0   // size is NOT returning a sizeThatFits (due to Kerning?), so fudge it
      // the frame size is being automagically increased and text is folding
      let labelText = NSMutableAttributedString(string: newText, attributes: [NSAttributedString.Key.font:NSFont(name: "Helvetica-Bold",size: fontSize)!])
      labelText.setAlignment(NSTextAlignment.center, range: NSMakeRange(0, labelText.length))
      var boundingRect = labelText.boundingRect(with: label.bounds.size, options: [])
      var stringWidth = boundingRect.width
      var stringHeight = boundingRect.height
      //      print ("testing \(stringWidth)/\(stringHeight) against \(overlayFrame.size)")
      while (stringWidth >= overlayWidth*fudgeFactor || stringHeight > overlayHeight*fudgeFactor && fontSize > CGFloat(12.0)) {
        fontSize -= 1.0
        labelText.setAttributes([NSAttributedString.Key.font: NSFont(name: "Helvetica-Bold",size: fontSize)!], range: NSMakeRange(0, labelText.length))
        boundingRect = labelText.boundingRect(with: label.bounds.size, options: NSString.DrawingOptions.truncatesLastVisibleLine)
        stringWidth = boundingRect.width
        stringHeight = boundingRect.height
        //        print ("testing \(stringWidth)/\(stringHeight) against \(overlayFrame.size)")
      }
      //      print("using font size \(fontSize)")
      label.textStorage?.append(labelText)
      label.textContainer?.widthTracksTextView = false
      label.textContainer?.containerSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
      label.textContainer?.heightTracksTextView = true
      label.sizeToFit()
      label.alphaValue = 0.3
      NSAnimationContext.runAnimationGroup({ (context) -> Void in
        context.duration = 2.0
        label.animator().alphaValue = 0.0
      }, completionHandler: {
        //        Swift.print("completed")
      })
      
    }
  }
  
  /// Create a video plane overlay which displays the marks  on a timeline that sits at bottom
  /// of the video view.
  
  let timelineViewId = "1002"
  let timelineHeight = CGFloat(25.0)
  let timeLineOrigin = CGPoint(x:50.0, y:50.0)
  
  /// We have to keep track of three possible positions
  /// 1) The current time in PTS that the player believes it is at.  This can vary from
  /// the file PTS due to advertisements being removed.
  /// 2) The "normalized" position along the timeline
  /// 3) The PTS value from the file that seekTo will work with.
  ///
  /// The current time from the Player is the problem child.  IFF the player is left to run,
  /// its final value is simply the runtime.  IFF a skip is executed the currentTime is set to the
  /// seek position PTS value
  
  /// Change the video to match the "clicked" position from the timeline Control
  @objc func timelineChanged()
  {
    let targetPosition = self.timelineView!.normalizedXPos
    //    self.timelineView?.currentPosition = [targetPosition]
    if (debug) { print("new Position = \(targetPosition)") }
    // calculate absolution seek to postion
    var newAVPositionInSeconds = targetPosition * timelineView!.timeRangeSeconds
    print("raw position from timeline = \(newAVPositionInSeconds)")
    if (movie.ap.hasGaps) {
      // need to incrementally add in the gaps to get a time that the player can
      // seek to successfully
      newAVPositionInSeconds = movie.ap.gapDuration(before: newAVPositionInSeconds)
    }
    let seekTime = CMTime(seconds: newAVPositionInSeconds, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
    //    seekCompleted = false
    //    self.monitorView.player?.currentItem?.seek(to: seekTime, completionHandler: seekCompletedOK)
    if (true) { print("seeking from timeline control to adjusted \(newAVPositionInSeconds)")}
    seekInSequence(to: seekTime)
  }
  
  /// manufacture a timeline control, with actions, allow to be first responder.
  func createTimelineOverlayView() -> TimeLineView
  {
    if (debug) { print("Creating timeline") }
    removeTimelineView()
    let timelineWidth = (self.monitorView.frame.width - 2.0*timeLineOrigin.x)
    let timeLineViewSize = CGSize(width: timelineWidth, height: timelineHeight)
    let timelineFrame = NSRect(origin: timeLineOrigin, size: timeLineViewSize)
    let timeRange = movie.getBestDurationAndApDurationInSeconds()
    // trap missing ap file gives an ap duration of 0
    let useableRange = timeRange.ap != 0 ? timeRange.ap : timeRange.best
    let thisTimeline = TimeLineView(frame: timelineFrame, seconds: useableRange)
    // hook up to gui
    thisTimeline.identifier = NSUserInterfaceItemIdentifier(rawValue: timelineViewId)
    thisTimeline.action = #selector(timelineChanged)
    thisTimeline.target = self
    
    let timelineBackground = NSColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 0.4)
    thisTimeline.bookMarkBackgroundColor = timelineBackground
    thisTimeline.keyCatchDelegate = self
    
    
    self.monitorView.addSubview(thisTimeline)
    thisTimeline.becomeFirstResponder()
    return thisTimeline
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
    self.deleteRecordingButtonTimer.invalidate()
    //    if (true) {print(#function + " invalidated delete button timer")}
    self.monitorView.player?.cancelPendingPrerolls()
    self.monitorView.player?.currentItem?.cancelPendingSeeks()
    self.pendingSeek.removeAll()
    seekCompleted = true
    resetGUI()
    resetCurrentMovie()
    setStatusFieldToCurrentSelection()
    
    currentFile.toolTip = currentFile.selectedItem?.toolTip
    let actualFileName = filelist[filelistIndex].components(separatedBy: CharacterSet(charactersIn: "/")).last
    fileWorkingName = actualFileName!.removingPercentEncoding!
    let baseNameURL = filelist[filelistIndex].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    
    updateVideoOverlay(updateText: nil)
    //    updateHintOverlay(updateText: fileWorkingName)
    
    // load up a recording
    movie = Recording(rootURLName: baseNameURL)
    preferences.setMovie(movie: movie)
    if (debug) { movie.cuts.printCutsData() }
    self.cutsTable.reloadData()
    cuttable = movie.isCuttable
    cutsUndoRedo = CutsEditCommnands(movie.cuts)
    
    // select begining of file or earliest bookmark if just a few
    if (movie.cuts.count>0 && movie.cuts.count<=3)
    {
      //      let startPTS = Int64(movie.cuts.first!.cutPts)
      startTime = CMTimeMake(value: Int64(movie.ap.firstPTS), timescale: CutsTimeConst.PTS_TIMESCALE)
      //      startTime = CMTimeMake(startPTS, CutsTimeConst.PTS_TIMESCALE)
    }
    else {
      startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
    }
    //    startTime = CMTime(seconds: 0.0, preferredTimescale: 1)
    
    // extract eit file information
    programTitle.stringValue = movie.eit.programNameText()
    programTitle.textColor = movie.ap.hasPCRReset ? NSColor.orange : NSColor.black
    epsiodeTitle.stringValue = movie.eit.episodeText
    programDescription.string = movie.eit.descriptionText()
    
    if (debug) { print(movie.meta.description()) }
    // if description is empty, replicate title in description field
    // some eit entries fail to give a title and put the description
    // in the notional episode title descriptor
    // Alternative would be to blank title field and populate description
    if programDescription.string.isEmpty
    {
      let epTitle = epsiodeTitle.stringValue
      if epTitle.count > ConstsCuts.maxTitleLength {
        // abitrarily pick out the first n words
        let titlewords = epTitle.components(separatedBy: " ")
        let title  = titlewords[0..<min(ConstsCuts.titleWordsPick,titlewords.count)].joined(separator: " ")
        epsiodeTitle.stringValue = title
      }
      programDescription.string = movie.eit.episodeText
    }
    let TSNameURL = baseNameURL+ConstsCuts.TS_SUFFIX
    if (isVideoEnabled.state == NSControl.StateValue.on) {
      setupAVPlayerFor(TSNameURL, startTime: startTime)
      
    }
    // found a loaded a file, update the recent file menu
    let cutsNameURL = baseNameURL+ConstsCuts.CUTS_SUFFIX
    let fileURL = URL(string: cutsNameURL)!
    if  let doc = try? TxDocument(contentsOf: fileURL, ofType: ConstsCuts.CUTS_SUFFIX)
    {
      NSDocumentController.shared.noteNewRecentDocument(doc)
    }
    if (voiceWasOn) { toggleVoiceRecognition(microphoneButton)}
    //    print(mySpeechRecogizer?.commands)
    //    print("Have I started?")
    NotificationCenter.default.post(name: Notification.Name(rawValue: movieDidChange), object: nil)
    cuttable = movie.isCuttable
  }
  
  // MARK: - button responders
  
  /// Direction choice used for stepping through a list of programs
  
  enum ProgramChoiceStepDirection {
    case next, previous
  }
  
  /// Common code function for choosing the next or previous
  /// program in the sorted list
  /// - parameter direction : ProgramChoiceStepDirection.NEXT or ProgramChoiceStepDirection.PREVIOUS
  func previousNextButtonAction(_ direction: ProgramChoiceStepDirection)
  {
    if (self.monitorView.player != nil)
    {
      let playerState = self.monitorView.player?.status
      if (playerState != AVPlayer.Status.failed)
      {
        videoPlayer(.pause)
      }
    }
    // should not be possible to invoke when index is > count-1 or == 0
    // belt and braces approach bounds checking
    let forwardOK = (filelistIndex<(currentFile.numberOfItems-1) && direction == .next)
    let backwardOK = (direction == .previous && filelistIndex > 0)
    if ( forwardOK || backwardOK)
    {
      //      let adjustment = direction == .next ? 1 : -1
      let adjustment = stepToPopUpNotHidden(direction: direction)
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
  
  /// Find the next visible entry on the popUp in the given direction and return the index offset
  /// - parameter direction: which way to search (forward or backward through list)
  /// - returns: arithmetic step in popUp Index to next visible item
  private func stepToPopUpNotHidden(direction: ProgramChoiceStepDirection) -> Int
  {
    var step = 0
    var found = false
    if ( direction == .next) {
      var index = filelistIndex + 1
      while !found && index < currentFile.itemArray.count
      {
        found = currentFile.itemArray[index].isHidden == false
        if !found { index += 1 }
      }
      if found {
        step = index - filelistIndex
        return step
      }
    }
    else {
      var index = filelistIndex - 1
      while !found && index >= 0
      {
        found = currentFile.itemArray[index].isHidden == false
        if !found { index -= 1 }
      }
      if found {
        step = -(filelistIndex - index)
        return step
      }
    }
    return 0
  }
  
  @IBAction func prevButton(sender: NSButton) {
    previousNextButtonAction(ProgramChoiceStepDirection.previous)
  }
  
  @IBAction func nextButton(sender: NSButton) {
    previousNextButtonAction(ProgramChoiceStepDirection.next)
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
    let response: NSApplication.ModalResponse = msg.runModal()
    
    if (response == NSApplication.ModalResponse.alertFirstButtonReturn) {
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
    self.movie.removeFromCache()
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
    boundaryAdHunter?.reset()
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
        //        self.cutButton.isEnabled = self.movie.isCuttable
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
        //        print("\(remoteMountAndSource())")
        var rootPath : String
        rootPath = pickedPath + StringsCuts.DIRECTORY_SEPERATOR
        selectedDirectory = rootPath
        let foundRootPath = rootPath
        self.progressBar.isHidden = false
        NotificationCenter.default.post(name: Notification.Name(rawValue: progressBarVisibilityChange), object: nil)
        
        (isRemote, pvrIndex) = pvrLocalMount(containedIn: pickedPath)
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
  /// setting up the "Cut" task.  Uses a the unchangable local name determining if
  /// we are doing a local or remote cut.
  /// - parameter dirPath: local form representation of the path of the recording
  /// - returns: touple of local or remote cut, index into the configurations array
  func pvrLocalMount(containedIn dirPath: String) -> (isLocal: Bool, configIndex: Int)
  {
    // note index 0 is always local cutting configuration
    // so only look at remote mounts roots
    
    let remoteList = remoteMountAndSource()
    var remoteEntry: serverTuple = ("","","")
    let dirPathComponents = dirPath.components(separatedBy: "/")
    for entry in remoteList {
      var matched = true
      let entryComponents = entry.MountPath.components(separatedBy: "/")
      // do all the path elements match ? (beware Movie-1 contains Movie)
      for i in 0 ..< min(dirPathComponents.count, entryComponents.count) {
        matched = matched && dirPathComponents[i] == entryComponents[i]
      }
      if matched {
        remoteEntry = entry
        break
      }
    }
    
    for i in 1 ..< self.systemSetup.pvrSettings.count {
      let pvr = systemSetup.pvrSettings[i]
      let pvrServer = pvr.remoteMachineAndLogin.components(separatedBy: "@").last!.lowercased()
      if pvrServer == remoteEntry.MountServer {
        // use it and update configuration entry
        // TODO: not saving as side effect not good design
        self.systemSetup.pvrSettings[i].cutLocalMountRoot = remoteEntry.MountPath
        generalPrefs.systemConfig = systemSetup
        preferences.saveGeneralPreference(generalPrefs)
        let isRemote = (pvr.title != mcutConsts.fixedLocalName)
        return (isRemote, i)
      }
    }
    
    //    for i in 1 ..< self.systemSetup.pvrSettings.count {
    //      let pvr = systemSetup.pvrSettings[i]
    //      var pvrMount = pvr.cutLocalMountRoot
    //      // ensure consistent format
    //      if dirPath.last == "/" && pvrMount.last != "/" {
    //        pvrMount += "/"
    //      }
    //      if dirPath.contains(pvrMount)
    //      {
    //        let isRemote = (pvr.title != mcutConsts.fixedLocalName)
    //        return (isRemote, i)
    //      }
    //    }
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
  
  /// Sorter to sort namePairs by assoicated eit title
  /// do case insensistive sort
  /// reduce repeated spaces to single spaces to deal with curating faults
  func pairsListTitleSorter( _ s1:namePair, s2: namePair) -> Bool
  {
    var greaterThan: Bool
    
    var title1 = EITInfo.loadEpisodeTextFrom(cutsFileName: s1.diskURL).lowercased()
    title1 = title1.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    var title2 = EITInfo.loadEpisodeTextFrom(cutsFileName: s2.diskURL).lowercased()
    title2 = title2.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    
    if sortPrefs.isAscending {
      greaterThan = title1 < title2
    }
    else {
      greaterThan =  title1 > title2
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
      let pair = namePair(diskURL: filelist[namelist.firstIndex(of: name)!], programeName: name)
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
    else if (sortPrefs.sortBy == sortStringConsts.byTitle)
    {
      namePairs.sort(by: pairsListTitleSorter)
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
      currentFile.selectItem(at: filelist.firstIndex(of: filename)!)
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
    
    currentFile.selectItem(at: filelist.firstIndex(of: fileURL.absoluteString)!)
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
  
  typealias popUpAttributes = (font :NSFont, colour: NSColor, apDuration:Double, episodeText: String, backgroundColour: NSColor)
  
  /// queue to gateway race access to progressBar value
  /// between the view controller and the background process
  private var colourCodingQueue = DispatchQueue(label: "colourCodingQueue")
  private var _colouringProgress = 0.0
  var colouringProgess : Double {
    return colourCodingQueue.sync {
      return _colouringProgress
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
    colourCodingQueue.async {
      self._colouringProgress = 0.0
    }
    self.progressBar.doubleValue = colouringProgess
    
    blockOperation.addExecutionBlock (
      { [weak weakself = self] in
        var attributes = [popUpAttributes]()
        //        let trailingDurationRegexString = " ([0-9][0-9]:[0-9][0-9]:[0-9][0-9]\)$" // eg " (01:23:35)"
        // progressively construct a set of attributes for the UI
        var index = 0
        var moreToDo = (weakself != nil) ? index < weakself!.namelist.count : false
        while moreToDo
        {
          // each time through the loop check that we are still wanted
          if blockOperation.isCancelled {
            resultNotWanted = true
            break
          }
          if let (fontAttribute, colourAttribute, apDuration, episodeTitle, backgroundColour) = weakself?.getFontAttributesDurationForIndex(index) {
            attributes.append((fontAttribute, colourAttribute, apDuration, episodeTitle, backgroundColour))
            
            // update the application each time we have completed one program except the last
            if (index < (weakself?.namelist.count)!-1) {
              // block whilst we capture the index value for the GUI update
              weakself?.colourCodingQueue.sync {
                weakself?._colouringProgress = Double(index)
              }
              OperationQueue.main.addOperation (
                {
                  weakself?.progressBar.doubleValue = (weakself?.colouringProgess)!
                  weakself?.statusField.stringValue = "Working out title colour coding in background"
                })
            }
          }
          // increment loop and update control flag
          index += 1
          moreToDo = (weakself != nil) ? index < weakself!.namelist.count : false
        }
        
        if (resultNotWanted) {
          OperationQueue.main.addOperation (
            {
              weakself?.statusField.stringValue = StringsCuts.COLOUR_CODING_CANCELLED
              weakself?.progressBar.isHidden = true
              NotificationCenter.default.post(name: Notification.Name(rawValue: (weakself?.progressBarVisibilityChange)!), object: nil)
            }
          )
        }
        else {        // completed normally
          OperationQueue.main.addOperation (
            {
              if let listCount = weakself?.namelist.count
              {
                for index in 0 ..< listCount
                {
                  let colourAttribute = attributes[index].colour
                  let backgroundColour = attributes[index].backgroundColour
                  let fontAttribute = attributes[index].font
                  let apDuration = attributes[index].apDuration
                  let episodeText = attributes[index].episodeText
                  let title = (weakself?.currentFile.item(at: index)?.title)!
                  weakself?.currentFile.item(at: index)?.attributedTitle = NSAttributedString(string: title, attributes:[
                    NSAttributedString.Key.foregroundColor: colourAttribute,
                    NSAttributedString.Key.backgroundColor: backgroundColour,
                    NSAttributedString.Key.font:fontAttribute
                  ])
                  if let pathURL = weakself?.filelist[index],
                     let tooltip = weakself?.tooltipFrom(url: pathURL, duration: apDuration, episodeTitle: episodeText)
                  {
                    weakself?.currentFile.item(at: index)?.toolTip = tooltip
                  }
                  // else: no path == no tooltip (duh)
                }
                // now as we have been scribbling in the status field, we ensure that is brought
                // back into sync with the current user selection
                weakself?.setStatusFieldToCurrentSelection()
                weakself?.progressBar.isHidden = true
                NotificationCenter.default.post(name: Notification.Name(rawValue: (weakself?.progressBarVisibilityChange)!), object: nil)
              }
            }
          )
        }
      }
    )
    
    queue.addOperation(blockOperation)
    return blockOperation
  }
  
  func getAttributesForIndex(_ index:Int) -> (font :NSFont, colour: NSColor, apDuration:Double, episodeTitle: String, backgroundColour: NSColor)
  {
    return getFontAttributesDurationForIndex(index)
  }
  
  /// Determine the colour and font for an attributed string for the program at the given Index
  /// - parameter index: index into filelist array
  /// - returns: tuple of NSColor and NSFont
  
  // FIXME: fails if file is deleted during operation
  
  func getFontAttributesDurationForIndex( _ index : Int) -> (font :NSFont, colour: NSColor, apDuration:Double, episodeTitle: String, backgroundColour: NSColor)
  {
    // set defaults
    var attributeColour = NSColor.black
    var backgroundColour = NSColor.white
    let fontSize = NSFont.systemFontSize
    var font = NSFont.systemFont(ofSize: fontSize)
    var thisProgramDuration = 0.0
    var thisMovie: Recording
    var thisEpisodeTitle: String
    
    // work through the set of files
    // FIXME: index can be -1 if "duplicates" find no matches and drop down is blank (fix duplicate ??)
    let baseName = filelist[index].replacingOccurrences(of: ConstsCuts.CUTS_SUFFIX, with: "")
    thisMovie = Recording(rootURLName: baseName)
    
    backgroundColour = thisMovie.ap.hasPCRReset ? NSColor.orange.withAlphaComponent(0.2) : backgroundColour
    let durations = thisMovie.getBestDurationAndApDurationInSeconds()
    thisProgramDuration = durations.best
    thisEpisodeTitle = thisMovie.eit.episodeText
    
    var colourState: FileColourStates = FileColourStates.noBookmarksColour
    if (thisMovie.cuts.count != 0) {
      colourState = (thisMovie.cuts.count > fileColourParameters.BOOKMARK_THRESHOLD_COUNT) ? .allDoneColour : .noBookmarksColour
      
      // override if we have in/out pairs
      if ( thisMovie.cuts.containsINorOUT()) {
        font = NSFont.boldSystemFont(ofSize: fontSize)
        // set unbalanced if there are not pairs of in/out - typically flagging MacOS player has trouble with ts file
        // get one in, but cannot seek to set the other
        let unbalanced = (thisMovie.cuts.inOutOnly.count % 2 == 1)
        colourState = (unbalanced) ? .partiallyReadyToCutColour : .readyToCutColour
      }
      
      // override if it is a short
      if (colourState == .noBookmarksColour  &&
            (thisProgramDuration > 0.0 && thisProgramDuration < fileColourParameters.PROGRAM_LENGTH_THRESHOLD)) {
        colourState = .allDoneColour
      }
    }
    else { // no cuts data implies unprocessed (not guaranteed since a cut program, may simply have no bookmarks but....)
      if (thisProgramDuration > 0.0 && thisProgramDuration < fileColourParameters.PROGRAM_LENGTH_THRESHOLD
            || thisMovie.cuts.bookMarks.count > 3) {
        colourState = .allDoneColour
      }
      else {
        colourState = .noBookmarksColour
      }
    }
    attributeColour = colourLookup[colourState] ?? attributeColour
    return (font, attributeColour, durations.ap, thisEpisodeTitle, backgroundColour)
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
    let (fontAttribute, colourAttribute, apDuration, episodeText, backgroundColour) = getFontAttributesDurationForIndex(index)
    if  let menuItem = currentFile.item(at: index)
    {
      //      let path = filelist[index].replacingOccurrences(of: "file://", with: "")
      //      let tooltip = (path.removingPercentEncoding!) + " (\(CutEntry.hhMMssFromSeconds(apDuration)))"
      let tooltip = tooltipFrom(url: filelist[index], duration: apDuration, episodeTitle: episodeText)
      
      menuItem.attributedTitle = NSAttributedString(string: menuItem.title, attributes: [
        NSAttributedString.Key.foregroundColor: colourAttribute,
        NSAttributedString.Key.font: fontAttribute,
        NSAttributedString.Key.backgroundColor: backgroundColour
      ])
      menuItem.toolTip = tooltip
    }
  }
  
  func determineDropDownColourForIndex(_ index:Int) -> (foregroundColour: NSColor, backgroundColour: NSColor)
  {
    //    let (fontAttribute, colourAttribute, apDuration, episodeText) = getAttributesForIndex(index)
    let (_, colourAttribute, _, _, backgroundColour) = getAttributesForIndex(index)
    return (colourAttribute,backgroundColour)
  }
  
  /// Construct the dropdown tool tip to be full (local) path and the calculated duration
  /// of the recording
  /// - parameter url: file:// style url
  /// - parameter duration: the duration of the recording in seconds
  /// - returns: formatted string
  
  func tooltipFrom(url: String, duration: Double, episodeTitle:String ) -> String
  {
    let durationString = " (\(Seconds(duration).hhMMss))"
    let path = url.replacingOccurrences(of: "file://", with: "")
    let plainPath = path.removingPercentEncoding ?? path
    let tooltip = plainPath + durationString + " " + episodeTitle
    return tooltip
  }
  
  /// Routine that examines the cuts data associated with each program and
  /// set the colour of the NSPopUpButton based on a guess that the cuts file
  /// has already been processed
  
  func setCurrentFileListColors()
  {
    self.progressBar.isHidden = false
    NotificationCenter.default.post(name: Notification.Name(rawValue: progressBarVisibilityChange), object: nil)
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
  // Determine if menu item should be enabled or not
  @objc func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    //    print("called with item = \(menuItem.title)")
    if (menuItem.action == #selector(clearBookMarks(_:))
          || menuItem.action == #selector(clearCutMarks(_:))
          || menuItem.action == #selector(clearLastPlayMark(_:))
          || menuItem.action == #selector(clearAllMarks(_:))
    )
    {
      return (filelist.count > 0 )
    }
    else if (menuItem.action == #selector(add10Bookmarks(_:))) {
      return (filelist.count > 0 )
    }
    else if (menuItem.action == #selector(undo(_:))) {
      //      print("undo is \(cutsUndoRedo?.undoEmpty ?? false)")
      return cutsUndoRedo?.undoEmpty ?? false
    }
    else if ( menuItem.action == #selector(redo(_:))) {
      //      print("redo is \(cutsUndoRedo?.isRedoPossible ?? false)")
      return cutsUndoRedo?.isRedoPossible ?? false
    }
    else if menuItem.action == #selector(cleanMarkAndCut(_:)) {
      return movie.isCuttable
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
    //    cutButton.isEnabled = state
    tenMarkButton.isEnabled = state
    inButton.isEnabled = state
    outButton.isEnabled = state
    currentFile.isEnabled = state
    if (state)
    {
      setPrevNextButtonState(filelistIndex)
      deleteRecordingButton.isEnabled = (filelist.count > 0) && progressBar.isHidden
    }
    else {
      previousButton.isEnabled = state
      nextButton.isEnabled = state
      deleteRecordingButton.isEnabled = state && progressBar.isHidden
    }
    enableAdHuntingButtons(state)
    // kill the timer if the button is enabled
    if (deleteRecordingButton.isEnabled) {deleteRecordingButtonTimer.invalidate()}
  }
  
  /// Reset GUI elements to blank that reflect selected movie / directory
  func resetGUI()
  {
    programTitle.stringValue = ""
    programTitle.textColor = NSColor.black
    programDescription.string = ""
    epsiodeTitle.stringValue = ""
    cutsTable.reloadData()
    fileWorkingName = ""
    programDuration.stringValue = ""
    programDuration.toolTip = ""
    statusField.stringValue = ""
    actionsSetEnabled(false)
    currentFile.isEnabled = true
    self.cutsTable.reloadData()
    currentFile.toolTip = ""
    boundaryAdHunter?.reset()
    lastHuntButton = nil
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
    removeTimelineView()
    monitorFrameChangeDate = Date()
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
    Recording.cache.removeAll()
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
    if ( openDlg.runModal() == NSApplication.ModalResponse.OK )
    {
      // Get an array containing the full filenames of all
      // files and directories selected.
      let files = openDlg.urls
      
      directory = (files.count>0) ? files[0]  : nil;
    }
    if (self.debug) {
      print("Selected "+((directory != nil) ? "\(String(describing: directory))" : "nothing picked"))
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
    if (debug) { print ("keypath <\(keyPath ?? "missing keypath")> for  \((object as AnyObject).className!)") }
    if (keyPath == "tracks") {
      if let tracks = change?[NSKeyValueChangeKey.newKey] as? [AVPlayerItemTrack] {
        for track in tracks
        {
          if (debug) {
            print("videoFieldMode: \(track.videoFieldMode ?? "No videoFieldMode")")
            if let thisTrack = track.assetTrack {
              print("assetTrack.trackID: \(thisTrack.trackID)")
              print("track.assetTrack.mediaType: \(thisTrack.mediaType)")
              print("track.assetTrack.playable: \(thisTrack.isPlayable)")
            }
            else {
              print("track.assetTrack is NIL")
            }
          }
          let duration = track.assetTrack?.asset?.duration
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
        if let status = AVPlayer.Status(rawValue: Int(newStatus as! Int))
        {
          if (debug) { print("status Enum = \(status)") }
          switch status {
          case .failed:
            if (debug) { print("failed state") }
          case .readyToPlay:
            if (debug) {
              print("ready to play")
              let debugDuration = (movie.meta.duration.count > 0) ? movie.meta.duration : "0"
              print("metadata duration = \(movie.meta.duration)/\(PtsType(debugDuration)!.asSeconds)")
              print("eit duration = \(movie.eit.eit.Duration)")
              //              if let asset = self.monitorView.player?.currentItem?.asset
              //              {
              //                for characteristic in asset.availableMediaCharacteristicsWithMediaSelectionOptions {
              //
              //                  print("\(characteristic)")
              //
              //                  // Retrieve the AVMediaSelectionGroup for the specified characteristic.
              //                  if let group = asset.mediaSelectionGroup(forMediaCharacteristic: characteristic) {
              //                    // Print its options.
              //                    for option in group.options {
              //                      print("  Option: \(option.displayName)")
              //                    }
              //                  }
              //                }
              //              }
            }
            
            let videoDuration = CMTimeGetSeconds((self.monitorView.player?.currentItem?.duration)!)
            movie.videoDurationFromPlayer = videoDuration
            let videoDurationString = "\nplyr: \(CutEntry.hhMMssFromSeconds(videoDuration))"
            let durationsInSecs = movie.getBestDurationAndApDurationInSeconds(playerDuration: videoDuration)
            programDurationInSecs = durationsInSecs.best
            
            self.programDuration.stringValue = CutEntry.hhMMssFromSeconds(programDurationInSecs)
            self.programDuration.toolTip = movie.durationStrings.joined(separator: "\n").appending(videoDurationString)
            //            let startTime = CMTimeMake(Int64(movie.firstVideoPosition().cutPts), CutsTimeConst.PTS_TIMESCALE)
            let startTime = CMTimeMake(value: Int64(0), timescale: CutsTimeConst.PTS_TIMESCALE)
            
            if (self.monitorView.player?.status == .readyToPlay)
            {
              //              seekCompleted = false
              //              self.monitorView.player?.seek(to: startTime, completionHandler: seekCompletedOK)
              seekInSequence(to: startTime)
              updateCutsMarksGUI()
              // report seekable ranges
              if (debug) {
                if let availableRanges = self.monitorView.player?.currentItem?.seekableTimeRanges
                {
                  for range in availableRanges
                  {
                    if let timeRange = range as? CMTimeRange
                    {
                      print("range of \(timeRange.start.seconds)  duration: \(timeRange.duration.seconds)")
                    }
                  }
                }
              }
            }
            self.actionsSetEnabled(true)
          case .unknown:
            if (debug) { print("Unknown") }
          @unknown default:
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
        if let status = AVPlayer.Status(rawValue: Int(newStatus as! Int))
        {
          if (debug) { print("status Enum = \(status)") }
          var videoDuration = Float64(0.0)
          var videoDurationString = "\nplyr: \(CutEntry.hhMMssFromSeconds(videoDuration))"
          switch status {
          case .failed:
            if (debug) { print("failed state") }
          case .readyToPlay:
            // trap is that the player status can change BEFORE the item status (go figure....)
            if self.monitorView.player?.currentItem?.status == .readyToPlay {
              let itemDuration = self.monitorView.player?.currentItem?.duration
              if itemDuration != CMTime.indefinite {
                videoDuration = CMTimeGetSeconds(itemDuration!)
                videoDurationString = "\nplyr: \(CutEntry.hhMMssFromSeconds(videoDuration))"
              }
              let durationsInSecs = movie.getBestDurationAndApDurationInSeconds(playerDuration: videoDuration)
              programDurationInSecs = durationsInSecs.best
              if (debug) {
                print("Player ready to play")
                print("metadata duration = \(movie.meta.duration)/\(PtsType(movie.meta.duration)!.asSeconds)")
              }
              if let metaDuration = PtsType(movie.meta.duration) {
                self.programDuration.stringValue = metaDuration.hhMMss.appending(videoDurationString)
              }
              else {
                self.programDuration.stringValue = "Metadata absent".appending(videoDurationString)
              }
              self.programDuration.toolTip = movie.durationStrings.joined(separator: "\n")
              let startTime = (movie.cuts.count>=1) ? movie.cuts.firstMarkTime : CMTime(seconds: 0, preferredTimescale: 1)
              if (self.monitorView.player?.status == .readyToPlay)
              {
                seekInSequence(to: startTime)
              }
              self.actionsSetEnabled(true)
              
            }
          case .unknown:
            if (debug) { print("Unknown") }
          @unknown default:
            if (debug) { print("Unknown unexpected/new enum case") }
          }
        }
        if (debug) { print ("new value of player status = \(newStatus)") }
      }
    }
    else if (keyPath == "rate" && object is AVPlayer)
    {
      if (debug)  { print("change dict \(keyPath!) = \(String(describing: change))") }
      if let newRate = change?[NSKeyValueChangeKey.newKey] as? Double
      {
        if (debug) {print("new rate is ...  \(newRate)")}
        //        wasPlaying = newRate != 0.0
        let avItem = self.monitorView.player?.currentItem
        let avRate = CMTimebaseGetRate(avItem!.timebase!).description
        if (debug) { print("item rate = \(avRate)") }
        let timeControlString = self.monitorView.player?.timeControlStatus == AVPlayer.TimeControlStatus.paused ? "paused" : ( (self.monitorView.player?.timeControlStatus == AVPlayer.TimeControlStatus.waitingToPlayAtSpecifiedRate) ? "waiting" : "playing")
        if (timeControlString == "waiting") {
          if (debug) { print ("waiting ??") }
        }
        if (debug) { print("time control = \(timeControlString)") }
        if let errorState = self.monitorView.player?.error
        {
          print("Error state= \(errorState)")
        }
        
        if let timeDelta = monitorFrameChangeDate?.timeIntervalSinceNow {
          if (debug) { print("diff to frame change = \(timeDelta)") }
          if timeDelta < -0.1
          {
            
            oldPlayerRate = self.monitorView.player?.rate
          }
          else {
            oldPlayerRate = nil
          }
        }
        if (debug) { printLog(log: "new value of player rate = \(newRate)" as AnyObject) }
        if (newRate == 0.0  && imageGenerator != nil)
        {
          if (debug) { print("Saw rate Change") }
          //          updateFilmStripSynchronous(time: (monitorView.player?.currentTime())!, secondsApart: frameGap, imageGenerator: imageGenerator!)
          self.filmStrip.updateFor(time: (monitorView.player?.currentTime())!, secondsApart: filmstripFrameGap, imageGenerator: imageGenerator!)
        }
      }
    }
    // catch zoom in/out of screen (fullscreen mode)
    else if (keyPath == "videoBounds" && object is AVPlayerView)
    {
      if (timelineView != nil) { resetTimeLineViewFrame() }
      if (true) {
        if let rect = change?[.newKey] as? CGRect
        {
          if let newrect = rect as CGRect?
          {
            if !newrect.equalTo(CGRect.zero) {
              if (self.debug) { print("newrect \(newrect)") }
              if let myPlayer = self.monitorView.player as? ObservedAVPlayer
              {
                let oldRate = self.monitorView.player?.rate
                // dispatch a delayed reset to false but only do it once
                if (!myPlayer.fullScreenTransition) {
                  DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak weakSelf = self] in
                    myPlayer.fullScreenTransition = false
                    weakSelf?.monitorView.player?.rate = oldRate!
                    if (weakSelf?.debug)! { print("transition done - set rate at \(oldRate!)") }
                  }
                }
                if (self.debug) { print("transition of videoBounds saving rate of \(oldRate!)") }
                myPlayer.fullScreenTransition = true
              }
              if (self.debug) { print("newRect is \(newrect.size)") }
              if newrect.size.width < 1280.0
              {
                if (self.debug) { print("normal screen") }
              }
              else
              {
                if (self.debug) {print("full screen")}
              }
            }
          }
        }
      }
    }
    else {
      super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
    }
  }
  
  // from https://stackoverflow.com/questions/33364491/why-print-in-swift-does-not-log-the-time-stamp-as-nslog-in-objective-c
  func printLog(log: AnyObject?) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS "
    print(formatter.string(from: Date()), terminator: "")
    if log == nil {
      print("nil")
    }
    else {
      print(log!)
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
        NotificationCenter.default.removeObserver(self, name: (kCMTimebaseNotification_EffectiveRateChanged as NSNotification.Name), object: self.monitorView.player?.currentItem?.timebase)
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
  
  ///
  var deleteRecordingButtonTimer = Timer()
  
  
  func createAVAssetFromURL(_ url: URL) -> (AVAsset,Bool) {
    let tsAsset = AVURLAsset(url: url)
    if (debug) { print("available formats:  \(tsAsset.availableMetadataFormats)") ; print(" media chars = \(tsAsset.availableMediaCharacteristicsWithMediaSelectionOptions)")}
    
    // ensure all track durations are valid - don't known enough video to
    // TODO: write bad video recovery functions
    var durationIsValid = true
    if (debug) {
      print("Track Count:\(tsAsset.tracks.count)")
      print("Audio Support: \(String(describing: AVURLAsset.audiovisualMIMETypes))")
    }
    for trackAsset in tsAsset.tracks {
      if (debug) {
        print("Asset description:\(trackAsset.description)")
        print("Asset sample Cursor:\(trackAsset.canProvideSampleCursors)")
        print("Asset formatDescriptions:\(trackAsset.formatDescriptions)")
        print("Asset mediaType:\(trackAsset.mediaType)")
        print(">>> \(trackAsset.mediaFormat) <<<")
        
      }
      let frameRate = Double(trackAsset.nominalFrameRate)
      if (debug) { print ("Found frame rate of \(frameRate) for mediaType = \(trackAsset.mediaType)") }
      //      if (false)
      if (trackAsset.mediaType == AVMediaType.video)
      {
        imageGenerator = AVAssetImageGenerator(asset: tsAsset)
        let frameTolerance = 1.0/(frameRate/2.0) // twice the frame rate to give some slack and allow picking I frame
        imageGenerator!.requestedTimeToleranceBefore = CMTime(seconds: frameTolerance, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
        imageGenerator!.requestedTimeToleranceAfter = CMTime(seconds: frameTolerance, preferredTimescale: CutsTimeConst.PTS_TIMESCALE)
        //        imageGenerator?.requestedTimeToleranceAfter = kCMTimeZero
        //        imageGenerator?.requestedTimeToleranceBefore = kCMTimeZero
        let imageSize = CGSize(width:self.filmStrip.frame.height*(16.0/9.0), height:self.filmStrip.frame.height)
        if (debug) { print(#function+" target Image Size\(imageSize)") }
        imageGenerator?.maximumSize = imageSize
        imageGenerator?.appliesPreferredTrackTransform = true
        imageGenerator?.apertureMode = AVAssetImageGenerator.ApertureMode.productionAperture
        //        updateFilmStripSynchronous(time: CMTime(seconds:300.0, preferredTimescale: CutsTimeConst.PTS_TIMESCALE), secondsApart: frameGap, imageGenerator: imageGenerator!)
        self.filmStrip.updateFor(time: CMTime(seconds:10.0+3.0*filmstripFrameGap, preferredTimescale: CutsTimeConst.PTS_TIMESCALE), secondsApart: filmstripFrameGap, imageGenerator: imageGenerator!)
      }
      if (trackAsset.mediaType == AVMediaType.closedCaption || trackAsset.mediaType == AVMediaType.subtitle)
      {
        print("Found closed caption")
      }
      let track = trackAsset.asset!
      let duration = track.duration
      durationIsValid = durationIsValid && !duration.isIndefinite && duration.isValid && !duration.isNegativeInfinity && !duration.isPositiveInfinity
    }
    
    return (tsAsset,durationIsValid)
  }
  
  /// Look at first video track is check that duration data is being decoded for this
  /// application to use
  func durationIsUsableForAsset(_ asset: AVAsset) -> Bool
  {
    var durationIsUsable = false
    let videoAssets = asset.tracks(withMediaType: AVMediaType.video)
    durationIsUsable = videoAssets.count >= 1
    // assuming the first and only video track for a ts stream
    let track = videoAssets[0].asset!
    let durationIsValid = !track.duration.isIndefinite && track.duration.isValid && !track.duration.isNegativeInfinity && !track.duration.isPositiveInfinity
    
    durationIsUsable = durationIsUsable && durationIsValid
    return durationIsUsable
  }
  /// Initialize the AVPlayer for the file URL given with filename
  /// and seek to the startTime
  
  func setupAVPlayerFor(_ fileURL:String, startTime: CMTime)
  {
    if (debug) { print ("Setting up av Player with string <\(fileURL)") }
    
    let videoURL = URL(string: fileURL)!
    let (tsAsset,durationIsValid) = createAVAssetFromURL(videoURL)
    
    // remove observers before instantiating new objects
    removePlayerObserversAndItem()
    
    if (durationIsValid)
    {
      let avItem = AVPlayerItem(asset: tsAsset)
      //      print("canPlayReverse -> \(avItem.canPlayReverse)")
      //      print("canStepForward -> \(avItem.canStepForward)")
      //      print("canStepBackward -> \(avItem.canStepBackward)")
      //      print("canPlayFastForward -> \(avItem.canPlayFastForward)")
      //      print("canPlayFastReverse -> \(avItem.canPlayFastReverse)")
      //      print("canPlaySlowForward -> \(avItem.canPlaySlowForward)")
      //      print("canPlaySlowReverse -> \(avItem.canPlaySlowReverse)")
      
      avItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.tracks), options: [.new], context: nil)
      avItem.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.new], context: nil)
      let samplePlayer = AVPlayer(playerItem: avItem)
      samplePlayer.addObserver(self, forKeyPath: #keyPath(AVPlayer.rate), options: [.new], context: nil)
      samplePlayer.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.new], context: nil)
      //      samplePlayer.isClosedCaptionDisplayEnabled = true
      samplePlayer.appliesMediaSelectionCriteriaAutomatically = true
      
      self.monitorView.controlsStyle = playerPrefs.playbackControlStyle == videoControlStyle.floating ? .floating : .inline
      //      self.monitorView.controlsStyle = AVPlayerViewControlsStyle.none
      self.monitorView.player = samplePlayer
      self.monitorView.showsFullScreenToggleButton = true
      self.monitorView.showsFrameSteppingButtons = !playerPrefs.playbackShowFastForwardControls
      stepSwapperButton.title = self.monitorView.showsFrameSteppingButtons ? playerStringConsts.ffButtonTitle : playerStringConsts.stepButtonTitle
      // guard against apple avplayer wanting to read entire file across network due to
      // detection that last pts is earlier than first (generates a block on the main thread!!)
      
      // TODO: probably OK to seek, if first bookmark is BEFORE PCR reset
      if (!movie.ap.hasPCRReset) {
        //        seekInSequence(to: startTime)
        print ("SKIPPING INITIAL SEEK AS TEST")
      }
      self.addPeriodicTimeObserver()
      // change of rate ?
      NotificationCenter.default.addObserver(self, selector: #selector(sawRateChangeInPlayer(_:)), name: kCMTimebaseNotification_EffectiveRateChanged as NSNotification.Name, object: self.monitorView.player?.currentItem?.timebase)
      deleteRecordingButtonTimer = addPlayerNeverComesReadyTimer()
      
    }
    else {
      self.statusField.stringValue = "Invalid Time duration cannot work with"
    }
    let trackingAreas = self.monitorView.trackingAreas
    if (trackingAreas.count > 0) {
      if (debug) { print("track area (setupAV) = \(trackingAreas)") }
      //      for area in trackingAreas {
      //        self.monitorView.removeTrackingArea(area)
      //      }
    }
    else {
      if (debug) { print("no tracking areas") }
    }
    timelineView = createTimelineOverlayView()
    if (debug) {
      printResponderChain(responder: timelineView)
      print("++")
      updateCutsMarksGUI()
      printResponderChain(responder: self)
      print("--")
    }
  }
  
  // Curtesy of stackoverflow
  func printResponderChain( responder: NSResponder?)
  {
    guard let thisResponder = responder else {
      return
    }
    printLog(log: thisResponder)
    printResponderChain(responder: thisResponder.nextResponder)
  }
  
  /// Create text label
  
  let textFontName = "Helvetica-Bold"
  
  func timeDeltaTextLabel(deltaValue : String, in frame:NSRect, withId: Int) -> NSTextField
  {
    // 10 % inset from image
    let insetWidth = 0.1 * frame.width
    let insetHeight = 0.1 * frame.height
    let textframe = frame.insetBy(dx: insetWidth, dy: insetHeight)
    let label = NSTextField(frame: textframe)
    label.stringValue = deltaValue
    //    label.sizeToFit()
    let textBackgroundColour = NSColor.yellow.withAlphaComponent(0.01)
    label.backgroundColor = textBackgroundColour
    label.identifier = NSUserInterfaceItemIdentifier(rawValue: "timetextLabel" + "\(withId)")
    label.alphaValue = 0.4
    label.font = NSFont(name: textFontName, size: 20.0)
    label.alignment = NSTextAlignment.justified
    return label
  }
  
  /// Update the timeline view
  func updateCutsMarksGUI()
  {
    if (self.monitorView.player?.currentItem?.status == AVPlayerItem.Status.readyToPlay)
    {
      timelineView?.setBookmarkPositions(normalizedPositions: movie.cuts.normalizedBookmarks)
      timelineView?.setInPositions(normalizedPositions: movie.cuts.normalizedInMarks)
      timelineView?.setOutPositions(normalizedPositions: movie.cuts.normalizedOutMarks)
      let cutBoxPositions = movie.cuts.wellOrdered().normalizedInOutMarks
      timelineView?.setCutBoxPositions(normalizedPositions: cutBoxPositions)
      timelineView?.setGapPositions(normalizedPositions: movie.ap.normalizedGaps)
      timelineView?.setPCRPositions(normalizedPositions: movie.ap.normalizedPCRs)
      timelineView?.setNeedsDisplay((timelineView?.bounds)!)
    }
  }
  
  /// Common function to write the status field GUI entry to match
  /// the current user selection
  func setStatusFieldToCurrentSelection()
  {
    let arrayIndex = currentFile.indexOfSelectedItem
    //    let message = String(format:logMessage.indexOfSelectedFileMsg, arrayIndex+1, filelist.count)
    setStatusFieldFormat(isLoggable: true, format:logMessage.indexOfSelectedFileMsg, arrayIndex+1, filelist.count)
  }
  
  /// Conceptual start for a logging mechanism.  Use a function
  /// as a gateway to setting the string value of the status field
  func setStatusFieldStringValue(isLoggable: Bool, message: String )
  {
    self.statusField.stringValue = message
    // TODO: and log...
  }
  
  /// Wrapper function to save needing discrete message formatting
  //  func setStatusFieldFormat(isLoggable loggable: Bool, format withFormat:String, args:CVarArg)
  func setStatusFieldFormat(isLoggable loggable: Bool, format withFormat:String, _ valist:Any...)
  {
    if let args = valist as? [CVarArg] {
      let message = String(format:withFormat, arguments: args)
      setStatusFieldStringValue(isLoggable: loggable, message: message)
    }
    else {
      NSSound.beep()
    }
  }
  
  // MARK: - Player related functions
  
  /// wrapper functions to seek or queue seek if a seek is pending
  func seekInSequence(to time: CMTime)
  {
    seekInSequence(to: time, toleranceBefore: CMTime.positiveInfinity, toleranceAfter: CMTime.positiveInfinity)
  }
  
  func seekInSequence(to time:CMTime, toleranceBefore beforeValue: CMTime, toleranceAfter afterValue: CMTime)
  {
    if seekCompleted {
      if (debug) { print("ok to seek \(time.seconds)") }
      seekCompleted = false
      monitorView.player?.seek(to: time, toleranceBefore: beforeValue, toleranceAfter: afterValue, completionHandler: seekCompletedOK)
    }
    else {
      if (debug) { print("\(pendingSeek.count): seek pending \(time.seconds)") }
      // if there are "a lot" tm of pending seeks, then throw away a few
      // before adding this one
      let threshold = 5
      if (pendingSeek.count > threshold) {
        let tmp:[SeekParams] = pendingSeek.indices.compactMap
        {
          if ($0 > threshold / 2) { return pendingSeek[$0] }
          else { return nil}
        }
        pendingSeek = tmp
        if (debug)  { print ("thinned pendingSeeks count = \(pendingSeek.count)")}
      }
      pendingSeek.append(SeekParams(time, beforeValue, afterValue))
    }
    lastSeekTime = time
  }
  
  func seekHandler(_ time:CMTime, _ beforeTolerance:CMTime, _ afterTolerance: CMTime)
  {
    seekInSequence(to: time, toleranceBefore: beforeTolerance, toleranceAfter: afterTolerance)
  }
  
  
  func seekCompletedOK(_ isFinished:Bool)
  {
    guard (!beingTerminated) else { return }
    if (debug) { print("entered "+#function) }
    if (!isFinished ) {
      if (debug) { print("Seek Cancelled") }
    }
    else {
      if (debug) { print("Seek completed") }
      if let centreTime = monitorView.player?.currentTime()
      {
        if (debug) {print("\(centreTime)")}
        //        updateTimeLineGUI(currentCMTime: centreTime)
        if (self.monitorView.player?.rate == 0.0 && imageGenerator != nil )
        {
          self.filmStrip.updateFor(time: centreTime, secondsApart: filmstripFrameGap, imageGenerator: imageGenerator!)
        }
      }
      if (wasPlaying) {
        monitorView.player?.play()
        if let myPlayer = self.monitorView.player as? ObservedAVPlayer {
          myPlayer.playCommandFromUser = .play
        }
      }
      suppressTimedUpdates = false
      //      let lastSkippedToCMTime = monitorView.player!.currentTime().convertScale(CutsTimeConst.PTS_TIMESCALE, method: CMTimeRoundingMethod.default)
      //      lastSkippedToTime = PtsType(lastSkippedToCMTime.value)
      //      if (debug) { print("lastSkippedToTime \(lastSkippedToTime.asSeconds)") }
    }
    if pendingSeek.count > 0
    {
      if (debug) { print("outstanding Seeks \(pendingSeek.count)")}
      // thin the seeks if a large number are outstanding
      if (pendingSeek.count > 30 )
      {
        // remove every third
        var index = 0
        while index < pendingSeek.count
        {
          pendingSeek.remove(at: index)
          index += 3
        }
      }
      if let nextSeek = pendingSeek.first
      {
        pendingSeek.removeFirst()
        seekCompleted = false
        if (debug) { print("seeking to pending time \(nextSeek.toTime.seconds)")}
        self.monitorView.player?.seek(to: nextSeek.toTime, toleranceBefore: nextSeek.beforeTolerance, toleranceAfter: nextSeek.afterTolernace, completionHandler: seekCompletedOK)
      }
    }
    
    // update timeline view
    seekCompleted = (pendingSeek.count == 0)
    if let nowTime = self.monitorView.player?.currentTime() {
      updateTimeLineGUI(currentCMTime: nowTime)
    }
  }
  
  /// Seek player by delta value in seconds.  Retains
  /// current paused or playing state
  
  // eugh! global time reference for nonPlaying seeks
  // updated / set in seekInSequence
  var lastSeekTime = CMTime()
  func seekToSkip(_ skipDurationSeconds:Double)
  {
    let pts=Int64(skipDurationSeconds*Double(CutsTimeConst.PTS_TIMESCALE))
    wasPlaying = isPlaying
    var now = CMTime()
    if wasPlaying  {
      now = (self.monitorView.player?.currentTime())!
    }
    else {
      now = lastSeekTime
    }
    let newtime = CMTimeAdd(now, CMTime(value: pts, timescale: CutsTimeConst.PTS_TIMESCALE))
    seekInSequence(to: newtime)
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
      videoPlayer(.pause)
    }
    let seekTolerance = BoundaryHunter.seekTolerance
    //    seekCompleted = false
    //    self.monitorView.player?.seek(to: CMTime(value: Int64(seekBarPos.cutPts), timescale: CutsTimeConst.PTS_TIMESCALE), toleranceBefore: kCMTimeZero, toleranceAfter: seekTolerance, completionHandler: seekCompletedOK)
    //    seekInSequence(to: CMTime(value: Int64(seekBarPos.cutPts), timescale: CutsTimeConst.PTS_TIMESCALE), toleranceBefore: CMTime.zero, toleranceAfter: seekTolerance)
    seekInSequence(to: CMTime(value: Int64(seekBarPos.cutPts), timescale: CutsTimeConst.PTS_TIMESCALE), toleranceBefore:
                    seekTolerance, toleranceAfter: seekTolerance)
  }
  
  /// Get the video players current position as a PTS value
  /// - returns: Player position current time converted into an Enigma2 scaled PTS value.
  /// the value does not relate to the file PTS values unless the initial PTS value is
  /// zero.  That is, to determine a file related position, combine the returned value with
  /// first PTS value from the file.
  func playerPositionInPTS() -> UInt64
  {
    let itemStatus = self.monitorView.player?.currentItem?.status
    if (debug) { print("status at call to current time\(itemStatus.debugDescription)") }
    var playPosition:Int64
    //    if self.monitorView.player?.currentItem?.duration.timescale != CutsTimeConst.PTS_TIMESCALE
    //    {
    playPosition = (self.monitorView.player?.currentTime().convertScale(CutsTimeConst.PTS_TIMESCALE, method: CMTimeRoundingMethod.default).value)!
    //    }
    //    else {
    //      playPosition = (self.monitorView.player?.currentTime().value)!
    //    }
    return playPosition>0 ? UInt64(playPosition) : UInt64(0)
  }
  
  func clockSeconds() -> String
  {
    // get the current date and time
    let currentDateTime = Date()
    
    // get the user's calendar
    let userCalendar = Calendar.current
    
    // choose which date and time components are needed
    let requestedComponents: Set<Calendar.Component> = [
      .year,
      .month,
      .day,
      .hour,
      .minute,
      .second
    ]
    
    // get the components
    let dateTimeComponents = userCalendar.dateComponents(requestedComponents, from: currentDateTime)
    
    // now the components are available
    //    dateTimeComponents.year   // 2016
    //    dateTimeComponents.month  // 10
    //    dateTimeComponents.day    // 8
    //    dateTimeComponents.hour   // 22
    //    dateTimeComponents.minute // 42
    var retStr = "??"
    if let secondsString = dateTimeComponents.second {
      retStr = "\(secondsString)"
    }
    return retStr
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
  
  let callbackTimePeriodSecs = 1.0
  
  // playback rate must be one of [-60, -30, -10, -5, -2, -1, 0 , 1, 2, 5, 10, 30, 60]
  // so find and return the "nearest"
  func getPlaybackRate( calculatedRate: Double) -> Int
  {
    let rates:[Double] = [-60.0, -30.0, -10.0, -5.0, -2.0, -1.0, 0.0 , 1.0, 2.0, 5.0, 10.0, 30.0, 60.0]
    guard calculatedRate > rates.first! else {
      return Int(rates.first!)
    }
    guard calculatedRate < rates.last! else {
      return Int(rates.last!)
    }
    var returnRate: Int?
    var i = 0
    while i < rates.count-1 && returnRate == nil {
      if calculatedRate >= rates[i] && calculatedRate <= rates[i+1]
      {
        let midpoint = (rates[i+1] + rates[i]) / 2
        if (rates[i] < 0.0) {
          returnRate = Int((calculatedRate > midpoint) ? rates[i+1] : rates[i])
        }
        else {
          returnRate = Int((calculatedRate < midpoint) ? rates[i] : rates[i+1])
        }
      }
      if (returnRate != nil && debug) {
        print("returning \(returnRate!) from \(calculatedRate) at index \(i)")
      }
      i += 1
    }
    return returnRate!
  }
  
  /// Calculate new timeline position from nominal player position
  func updateTimeLineGUI(currentCMTime: CMTime)
  {
    if (debug) { print(#function + "> currentTime = \(currentCMTime.convertScale(1000_000_000, method: CMTimeRoundingMethod.default))")}
    // update timeline gui
    if (currentCMTime.seconds) >= 0.0
    {
      if let secondsDuration = self.timelineView?.timeRangeSeconds
      {
        var secondsElapsed = Double(currentCMTime.convertScale(1, method: CMTimeRoundingMethod.default).value)
        let currentVideoScale = currentCMTime.convertScale(CutsTimeConst.PTS_TIMESCALE, method: CMTimeRoundingMethod.default)
        let currentVideoPTS = PtsType(currentVideoScale.value)
        let seekDone = self.seekCompleted
        if seekDone
        {
          // allow for any gaps "played" through
          //          let gapAdjustment = (self.movie.ap.gapsBetweenTimes(start: (self.lastSkippedToTime), end: currentVideoPTS))
          let gapAdjustment = movie.ap.gapsBeforeInSeconds(currentVideoPTS)
          if (debug) { print("seconds Elapsed \(secondsElapsed)") }
          secondsElapsed -= gapAdjustment
          if (debug) {
            print ("adjusting elapsed time by \(gapAdjustment)")
            print ("adjusted Elapse = \(secondsElapsed)")
          }
          //          let currentAVAsset = self.monitorView.player?.currentItem?.asset
          //          print("\(AVURLAsset.audiovisualMIMETypes())")
        }
        let normalizedCurrentPosition = secondsElapsed/secondsDuration
        self.timelineView?.updateBoundary(newCurrentPosition: normalizedCurrentPosition)
        self.timelineView?.currentPosition =  [normalizedCurrentPosition]
      }
    }
  }
  
  /// Function to enable the delete movie button even if the file is stuffed
  /// If the recording is stuffed, the player never goes into the readyToPlay state
  /// So we give it a few seconds to achieve that, if is too corrupt for the "everything
  /// must be perfect, or I won't play" Apple code, then we enable the delete button anyway.
  /// Since if it is badly corrupt, we want to be able to delete it.
  func addPlayerNeverComesReadyTimer() -> Timer
  {
    let shouldBeReadyByTime: TimeInterval = 3.0
    //    if (true) { print(#function + " timer added")}
    let statusTimer = Timer.scheduledTimer(withTimeInterval: shouldBeReadyByTime, repeats: true) {
      statusTimer in
      //      if (true) { print(#function + " timer fired")}
      // even if playerStatus is not ready, enable the delete button if
      // all other conditions are OK (ie listing and coloring has finished
      if self.deleteRecordingButton.isEnabled == false {
        self.deleteRecordingButton.isEnabled = (self.filelist.count > 0) && self.progressBar.isHidden
        //        if (true) { print(#function + " timer is trying to change button state")}
      }
      if self.deleteRecordingButton.isEnabled {
        //        if (true) { print(#function + " timer invalidated")}
        statusTimer.invalidate()
      }
    }
    return statusTimer
  }
  
  // from apple code sample
  func addPeriodicTimeObserver()
  {
    // Invoke callback every second
    let interval = CMTime(seconds: callbackTimePeriodSecs,
                          preferredTimescale: CMTimeScale(NSEC_PER_SEC))
    // Queue on which to invoke the callback
    let mainQueue = DispatchQueue.main
    // Add time observer - note that this may get multiple invocations for the SAME time
    timeObserverToken =
      self.monitorView.player?.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue) {
        [weak self] time in
        let closureDebug = false
        //        print("Trying to reshow cursor")
        //        var list = [CGDirectDisplayID](repeating:0,count:1000)
        //        var foundSize:UInt32 = 0
        //        let activeResult = CGGetActiveDisplayList(1000, &list, &foundSize)
        //        print("main display is \(CGMainDisplayID())")
        //        let message = activeResult.rawValue
        //        print("\(activeResult), found = \(foundSize)")
        //        for i in 0..<Int(foundSize) {
        //          print("display index \(i) value \(list[i])")
        //        }
        //        let result = CGDisplayShowCursor(CGMainDisplayID())
        ////        print("result = \(result.rawValue)")
        //        if (result != CGError.success) {
        //          print("mouse show failed \(result.rawValue)")
        //        }
        //        else {
        //          print("mouse show supposedly succeeded")
        //        }
        guard (self?.seekCompleted)! else {return}
        
        // protect against condition of closure call occuring duing file change
        guard (self?.monitorView.player?.currentItem != nil) else { return }
        //        print("Called back at \(self?.clockSeconds() ?? "??")")
        // update player transport UI
        // check cut markers and skips over OUT -> IN sections
        let avItem = self?.monitorView.player?.currentItem
        // FIXME: Can get called when avItem is nil - UI change before async update completed ?
        let avRate = CMTimebaseGetRate(avItem!.timebase!).description
        if (closureDebug) { print("item rate = \(avRate)") }
        if let currentCMTime =  self?.monitorView.player?.currentTime() {
          let currentClock = DispatchTime.now()
          //        print ("currenCMtime is valid = \(currentCMTime?.isValid ?? false)")
          if (closureDebug) { print("CT -> \(currentCMTime.seconds)") }
          
          let currentTime = Float(CMTimeGetSeconds((self?.monitorView.player?.currentTime())!))
          if (closureDebug)  { print("Saw callback start at \(currentTime)") }
          guard (self?.lastPeriodicCallBackTime != currentTime && self?.suppressTimedUpdates == false ) else {
            // do nothing
            if (closureDebug) { print("skipping callback at \(currentTime)") }
            if (self?.lastPeriodicCallBackTime == currentTime && closureDebug ) {print("duplicate time")}
            if (self?.suppressTimedUpdates == true && closureDebug ) {print("timed updates suppressed")}
            return
          }
          let deltaRealWorld = currentClock.uptimeNanoseconds - (self?.lastPeriodicClocktime.uptimeNanoseconds)!
          let deltaVideoTime = currentTime - (self?.lastPeriodicCallBackTime)!
          if (closureDebug) { print("callback at video time/elapsed \(currentTime)") }
          if (deltaRealWorld > 1000000000) // once per second in the real world
          {
            let deltaRate = Double(deltaVideoTime)/(Double(deltaRealWorld) * 1.0e-9)
            let derivedRate = self?.getPlaybackRate(calculatedRate: deltaRate)
            if (closureDebug) {
              print("calculated rate =            ---------------------------->>>>>>    \(derivedRate!)")
              print("calculated deltaTime= \(deltaVideoTime)")
              print("calculated elapse time = \(deltaRealWorld)")
            }
            self?.lastPeriodicClocktime = currentClock
            self?.lastPeriodicCallBackTime = currentTime
          }
          let hmsString = CutEntry.hhMMssFromSeconds(Double(currentTime))
          self?.programDuration.stringValue = hmsString + "/" + CutEntry.hhMMssFromSeconds((self?.programDurationInSecs)!)
          if (self?.honourOutInMarks)! {
            if let afterAdTime = self?.movie.cuts.programTimeAfter(currentCMTime)
            {
              // ensure we seek AFTER the current time, ie don't seek backwards!!
              if (afterAdTime.seconds > currentCMTime.seconds)
              {
                //                self?.seekCompleted = false
                //                self?.monitorView.player?.seek(to: afterAdTime, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimePositiveInfinity, completionHandler: (self?.seekCompletedOK)!)
                self?.seekInSequence(to: afterAdTime, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.positiveInfinity)
              }
              if (closureDebug) { print("Will Skip to time \(afterAdTime.seconds)") }
              self?.highlightCutTableEntryBefore(currentTime: Double(afterAdTime.seconds))
            }
            else {
              self?.highlightCutTableEntryBefore(currentTime: Double(currentTime))
            }
          }
          else {
            self?.highlightCutTableEntryBefore(currentTime: Double(currentTime))
          }
          // update timeline gui
          if (currentCMTime.seconds) >= 0.0
          {
            self?.updateTimeLineGUI(currentCMTime: currentCMTime)
            self?.updateCutsMarksGUI()
            let playerTimeInVideoTime = currentCMTime.convertScale(CutsTimeConst.PTS_TIMESCALE, method: CMTimeRoundingMethod.default)
            let position = PtsType(playerTimeInVideoTime.value)
            let playerPTSInVideoUnits = PtsType(playerTimeInVideoTime.value)
            if (self?.debug)! {
              print("position \(position.hhMMss)")
              print("playerPTSInVideoUnits \(playerPTSInVideoUnits.hhMMss)")
            }
          }
          else {
            print("Argh! negative currentTime \(currentCMTime)")
          }
          if (closureDebug) { print("Saw callback end for \(currentTime)") }
        }
      }
    // end closure addition
  }
  
  @objc func sawDidDeminiaturize(_ notification: Notification) {
    // reset periodic observer
    //    print(#file+#function)
    addPeriodicTimeObserver()
  }
  
  // MARK: - Movie Cutting functions
  
  /// Callback function for movie cutting Operations
  
  func movieCuttingFinished(_ resultMessage: String, movieAtPath: String)
  {
    if let movieIndex = self.filelist.firstIndex(of: movieAtPath) {
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
        //        self.cutButton.isEnabled = true
        if (wasCancelled) {
          cutterQ.jobCancelled(moviePath: URLToMovieToCut, result: statusValue, resultMessage: resultMessage)
        }
        else {
          cutterQ.jobCompleted(moviePath: URLToMovieToCut, result: statusValue, resultMessage: resultMessage)
          if (statusValue == 0)  {
            // inject an artificial delay to allow remote system to flush to disk
            // it *appears* to say that job is done before all files are completed.
            // since this is only updating the colouring of the drop down list a delay is not significant
            // IF this is executed on as a detached process  NOT ON THE MAIN QUEUE
            //            let gotColorCompletionBlock = newColour, listIndex in {
            //              self.currentF
            //            }
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
    return filelist.firstIndex(of: movieURLEntry)
  }
  
  // MARK: - TableView delegate, datasource and table related functions
  
  /// Get the view related to selected cell and populated the data value
  /// - parameter newMessage : replacement text
  /// - returns : populated view for tableView to use
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    var cellContent : String
    let cutEntry = movie.cuts.entry(at: row)
    if (tableColumn?.identifier)!.rawValue == StringsCuts.TABLE_TIME_COLUMN
    {
      if (self.movie.cuts.count>0)
      {
        cellContent = (cutEntry?.cutPts.hhMMss ?? "??:??:??")
      }
      else {
        cellContent = "?"
      }
    }
    else if (tableColumn?.identifier)!.rawValue == StringsCuts.TABLE_TYPE_COLUMN
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
    let result  = tableView.makeView(withIdentifier: (tableColumn?.identifier)!, owner: self) as? NSTableCellView
    //    let rowColour = colourForCutEntry(cutEntry!)
    //    result?.backgroundColor = rowColour
    //    print("setting content of \(cellContent) for column id of \(tableColumn!.identifier.rawValue)")
    result?.textField?.stringValue = cellContent
    return result
  }
  
  
  //  func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
  //  {
  //    let rowView = tableView.rowView(atRow: row, makeIfNecessary: true)
  //    if let theRow = rowView
  //    {
  //      let cutEntry = movie.cuts.entry(at: row)
  //      let rowColour = colourForCutEntry(cutEntry!)
  //      theRow.backgroundColor = rowColour
  //    }
  //    return rowView
  //  }
  
  /// Return number of rows required
  /// - returns : count of cuts collection
  @objc func numberOfRows(in tableView: NSTableView) -> Int
  {
    return self.movie.cuts.count
  }
  
  /// Respond to change of row selection (both user and programatic will call this)
  @objc func tableViewSelectionDidChange(_ notification: Notification)
  {
    let selectedRow = cutsTable.selectedRow
    // seek to associated cutEntry
    if (debug) { print("entered "+#function+" for row \(selectedRow)") }
    guard (selectedRow>=0 && selectedRow<movie.cuts.count) else
    {
      // out of bounds, silently ignor
      self.suppressTimedUpdates = false
      return
    }
    if let entry = movie.cuts.entry(at: selectedRow) {
      if (debug) { print("Seeking to \(entry.asSeconds()) with playerUpdateSuppressed = \(suppressPlayerUpdate)") }
      if (!suppressPlayerUpdate) {
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
      updateCutsMarksGUI()
      cuttable = movie.isCuttable
    }
  }
  
  enum CutsRowSelection {
    case previous, current, next
  }
  
  /// Delete a row from the cuts table when user presses "Delete" key on
  /// keyboard
  func deleteRowByKeyPress(thenSelect selectRow: CutsRowSelection)
  {
    let selectedRow = cutsTable.selectedRow
    if (selectedRow >= 0) {
      movie.cuts.remove(at: selectedRow)
      cutsTable.reloadData()
      updateCutsMarksGUI()
      //      print("Current row =\(selectedRow)")
      // reselect the previous row if possible, if not, then the top row if any
      
      if (movie.cuts.count>0)
      {
        var rowIndexToSelect: Int
        switch selectRow {
        case .previous:
          rowIndexToSelect = selectedRow - 1
        case .current:
          rowIndexToSelect = selectedRow
        case .next:
          rowIndexToSelect = selectedRow + 1
        }
        // bounds constrain for edge conditions
        rowIndexToSelect = min(rowIndexToSelect, movie.cuts.count - 1)
        rowIndexToSelect = max(0, rowIndexToSelect)
        //        let newRow = selectedRow - (((selectedRow-1 < movie.cuts.count) && selectedRow-1 >= 0) ? 1 : 0)
        //        print("New row =\(newRow)")
        //        cutsTable.selectRowIndexes(IndexSet(integer:newRow), byExtendingSelection: false)
        cutsTable.selectRowIndexes(IndexSet(integer:rowIndexToSelect), byExtendingSelection: false)
      }
      cuttable = movie.isCuttable
      cutsUndoRedo?.add(state: movie.cuts)
      //      print ("cell is \(cutEntry?.asString())")
    }
    
  }
  /// register swipe actions for table
  func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableView.RowActionEdge) -> [NSTableViewRowAction] {
    if edge == NSTableView.RowActionEdge.trailing {
      let delete = NSTableViewRowAction(style: NSTableViewRowAction.Style.destructive, title: "Delete", handler: rowDelete)
      return [delete]
    }
    return [NSTableViewRowAction]()
  }
  
  // Delegate function on row addition.
  // This delegate changes the background colour based on the mark type
  func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int)
  {
    //  print ("def row color \(rowView.backgroundColor ?? NSColor.black)")
    // try to change the color of the rowView
    var colour = NSColor.green
    // bounds checking
    guard row >= 0 && row < self.movie.cuts.count  else { return }
    if let cutEntry = movie.cuts.entry(at: row)
    {
      colour = colourForCutEntry(cutEntry)
    }
    rowView.backgroundColor = colour.withAlphaComponent(0.75)
    //    print ("set row color \(rowView.backgroundColor!)")
  }
  
  // beware only called on mouse clicks not keyboard
  @objc func tableViewSelectionIsChanging(_ notification: Notification) {
    self.suppressTimedUpdates = true
    if (debug) { print("Saw "+#function+" change") }
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
  
  /// get a UI colour for the mark type
  /// - parameter cut: the cut entry touple
  /// - returns: colour to use
  func colourForCutEntry(_ cut: CutEntry) -> NSColor
  {
    var colour: NSColor = NSColor.green
    if let markType = MARK_TYPE(rawValue: cut.cutType)
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
    return colour
  }
  
  /// General 'update the table' function
  /// - parameter cutEntry: entry to be selected or nil
  func updateTableGUIEntry(_ cutEntry: CutEntry?)
  {
    self.cutsTable.reloadData()
    updateCutsMarksGUI()
    selectCutTableEntry(cutEntry)
    updateCutsMarksGUI()
  }
  
  
  // MARK: - mark adjustment
  
  /// Utility to function to assist moving OUT cut mark a fraction backwards
  /// when the "binary hunt" decide we a close enough when at the start of
  /// an advertisement
  func moveMarkBySteps(_ step:Int)
  {
    var statusMessageChanged = false
    if (false) { // examining track character
      let tracks = self.monitorView.player?.currentItem?.tracks ?? []
      for track in tracks {
        print ("track type = \((track.assetTrack != nil) ? track.assetTrack!.description : "No track Asset")")
        if let astrck = track.assetTrack {
          print ("astrck trackID = \(astrck.trackID)")
          print ("astrck media type = \(astrck.mediaType)")
          print ("astrck nominal frame rate = \(astrck.nominalFrameRate)")
          print ("astrck naturalSize = \(astrck.naturalSize)")
          print ("astrck estimatedDataRate = \(astrck.estimatedDataRate)")
          print ("astrck metadata = \(astrck.metadata)")
          print ("astrck minFrameDuration = \(astrck.minFrameDuration)")
        }
        
        print ("track frame rate = \(track.currentVideoFrameRate)")
        print ("track enabled = \(track.isEnabled)")
        print ("track field mode = \(String(describing: track.videoFieldMode))")
      }
    }
    guard step != 0 else { return }
    var steps = step
    let leftMove = steps < 0
    let originalNumberOfRows = self.cutsTable.numberOfRows
    let currentRow = self.cutsTable.selectedRow
    if (debug) {
      let entry = self.movie.cuts.entry(at: currentRow)
      if (debug) { print("moving entry - \(entry!)") }
    }
    let waitTime:UInt32 = 125 // micro secs
    if let currentMark = self.movie.cuts.entry(at: currentRow) {
      if (currentMark.type == MARK_TYPE.OUT || currentMark.type == MARK_TYPE.IN)
      {
        var failed = true
        var loopCount = 0
        //        let timeBefore = self.monitorView.player?.currentItem?.currentTime()
        self.monitorView.player?.currentItem?.step(byCount: steps)
        //        let timeAfter = self.monitorView.player?.currentItem?.currentTime()
        //        print ("before \(timeBefore?.seconds)")
        //        print ("time after \(timeAfter?.seconds)")
        
        usleep(waitTime)  // time to let the detached seek happen or we are trying to add a coincident bookmark
        let success = addCutsMark(sender: (currentMark.type == MARK_TYPE.OUT ? outButton : inButton))
        if (success) {
          let entry = self.movie.cuts.entry(at: self.cutsTable.selectedRow)
          if (debug) { print("created entry - \(entry!)") }
          
        }
        else {
          if (debug) { print("entry creation failed ......") }
          
        }
        if (debug) { self.movie.cuts.printCutsData()}
        let currentSuppressPlayerUpdate = suppressPlayerUpdate
        while failed && loopCount < 3
        {
          failed = cutsTable.numberOfRows == originalNumberOfRows && !success
          if failed
          {
            // addMark failed due to seek failure
            setStatusFieldStringValue(isLoggable: false, message: "Failed Moving mark,... trying again in \(Double(waitTime)/1000.0) secs")
            statusMessageChanged = true
            // if seek has completed, then double the step
            if (self.monitorView.player?.status == .readyToPlay) {
              steps *= 2
              if (debug) {print("extending creeping to \(steps)")}
              self.monitorView.player?.currentItem?.step(byCount: steps)
              usleep(waitTime)  // time to let the detached seek happen or we are trying to add a coincident bookmark
              let _ = addCutsMark(sender: (currentMark.type == MARK_TYPE.OUT ? outButton : inButton))
            }
            NSSound.beep()
            usleep(waitTime)
            loopCount += 1
          }
          else {
            suppressPlayerUpdate = true
            let previousMarkRow = currentRow + (leftMove ? +1 : 0)
            self.cutsTable.selectRowIndexes(IndexSet(integer: previousMarkRow), byExtendingSelection: false)
            deleteRowByKeyPress(thenSelect: (leftMove ? .previous : .current))
            self.cutsTable.selectRowIndexes(IndexSet(integer: currentRow), byExtendingSelection: false)
            if (self.monitorView.player?.rate == 0.0)
            {
              filmStrip.updateFor(time: (monitorView.player?.currentTime())!, secondsApart: filmstripFrameGap, imageGenerator: imageGenerator!)
            }
            suppressPlayerUpdate = currentSuppressPlayerUpdate
          }
        }
        if (failed) {
          setStatusFieldStringValue(isLoggable: false, message: "Failed Moving mark,... Gave up after \(loopCount-1) attempts")
          statusMessageChanged = true
          NSSound.beep()
        }
        else {
          if (statusMessageChanged)  // clear warning messages when eventual success was achieved
          {
            setStatusFieldStringValue(isLoggable: false, message: "")
          }
        }
      }
    }
  }
  
  func moveMarkLeftBySteps(_ steps: Int)
  {
    moveMarkBySteps(-steps)
  }
  
  func moveMarkRightBySteps(_ steps: Int)
  {
    moveMarkBySteps(steps)
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
  
  // MARK: - cutMark management functions
  
  /// Contains all undo / redo functions and data (copies of cutslist)
  var cutsUndoRedo: CutsEditCommnands?
  
  // currently fails to create bookmarks before first in and after last out
  // when recording is cut but with ads marked out
  @IBAction func clearBookMarks(_ sender: AnyObject)
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
    updateCutsMarksGUI()
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
    updateCutsMarksGUI()
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
    updateCutsMarksGUI()
    suppressPlayerUpdate = false
  }
  
  
  /// 10% spacing add bookmark button action
  /// parameter sender: expect NSButton, but don't care, it is unused
  @IBAction func addBookMarkSet(_ sender: AnyObject)
  {
    suppressPlayerUpdate = true
    movie.cuts.addPercentageBookMarks()
    cutsTable.reloadData()
    updateCutsMarksGUI()
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
      updateCutsMarksGUI()
      cuttable = movie.isCuttable
      cutsUndoRedo?.add(state: self.movie.cuts)
    }
  }
  
  /// Wrapper function of addMark for programmatic usage
  func addCutsMark(sender: NSButton) -> Bool
  {
    var goodResult :Bool
    let markType = marksDictionary[(sender.identifier!).rawValue]
    let now = self.playerPositionInPTS()
    let mark = CutEntry(cutPts: now, cutType: markType!.rawValue)
    goodResult = movie.cuts.addEntry(mark)
    if goodResult {
      updateTableGUIEntry(mark)
      cutsUndoRedo?.add(state: self.movie.cuts)
      
      if (markType == .IN || markType == .OUT)  {
        cuttable = movie.isCuttable
        updateVideoOverlay(updateText: nil)
      }
    }
    return goodResult
  }
  
  /// Add a  mark at the current position
  /// TODO: current unused whilst CUT button is in the same GUI location
  /// TODO: shuffle buttons and re-enable
  @IBAction func addMark(sender: NSButton) {
    _ = addCutsMark(sender: sender)
    //    let markType = marksDictionary[(sender.identifier!).rawValue]
    //    let now = self.playerPositionInPTS()
    //    let mark = CutEntry(cutPts: now, cutType: markType!.rawValue)
    //    movie.cuts.addEntry(mark)
    //    updateTableGUIEntry(mark)
    //    cutsUndoRedo?.add(state: self.movie.cuts)
    //
    //    if (markType == .IN || markType == .OUT)  {
    //      cuttable = movie.isCuttable
    //      updateVideoOverlay(updateText: nil)
    //    }
  }
  
  /// Undo the last change to the cuts list. Go BACKWARD in history
  func cutsEditUndo()
  {
    if (debug) { print(#function) }
    if let lastCuts = cutsUndoRedo?.getPrevious()
    {
      self.movie.cuts = lastCuts
      cutsTable.reloadData()
      updateCutsMarksGUI()
      cuttable = movie.isCuttable
    }
    else  {
      NSSound.beep()
    }
  }
  
  /// Redo the last cuts list change to the cuts list.  Go FORWARD in history
  func cutsEditRedo () {
    if (debug) { print(#function) }
    if let nextCuts = cutsUndoRedo?.next()
    {
      self.movie.cuts = nextCuts
      cutsTable.reloadData()
      updateCutsMarksGUI()
      cuttable = movie.isCuttable
    }
    else {
      NSSound.beep()
    }
  }
  
  @IBAction func cleanMarkAndCut(_ sender: AnyObject)
  {
    if (debug) { print(#function) }
    guard (movie.isCuttable) else { return }
    
    clearBookMarks(sender)
    add10Bookmarks(sender)
    cutButton(cutButton)
    
  }
  // MARK: - Advertisment boundary pickers
  var boundaryAdHunter : BoundaryHunter?
  var initialStep = 90.0      // TODO: add to user config panel - 0.75 times middle skip
  let nearEnough = 1.0/25.0   // TODO: add to user config panel 1/25 th is frame level
  
  
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
  //  @IBOutlet weak var undoJumpButton: NSButton!
  let undoJumpButton = NSButton()
  @IBOutlet weak var doneHuntButton: NSButton!
  
  /// Action to take when users says that "this is in a program".
  /// Bound to the GUI "P" Button, the "z" keyboard keydown event
  /// and the "program" speech command
  /// - parameter: GUI Button
  @IBAction func inProgram(_ sender: NSButton) {
    //    lastHuntButton = sender
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
  
  /// Global egh! to retain last user state of pressed button"
  var lastHuntButton: NSButton? {
    willSet {
      if (newValue == nil) {
        let idString = (lastHuntButton == nil) ? "clearing" : lastHuntButton!.title
        if (debug) { print("who nils me - was " + idString ) }
      }
      else {
        if (debug) { print(" will be \(newValue!.title)") }
      }
    }
  }
  
  /// Action to take when user says "this is in an Advertisement"
  /// - parameter: GUI Button
  @IBAction func inAdvertisment(_ sender: NSButton) {
    //    lastHuntButton = sender
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
  
  /// Unwind the last (one only to start with), ad/program jump
  /// provided to handle those "ah poop" moments when you click the
  /// wrong button before your brain registers what you "should" do
  @IBAction func undoJumpAction(_ sender: NSButton) {
    guard (boundaryAdHunter != nil && lastHuntButton != nil) else { return }
    guard (boundaryAdHunter!.huntHistory.count >= 2) else { return }
    guard (!replayIsRunning) else { return }
    if let jumpHistory = boundaryAdHunter?.huntHistory
    {
      huntReset(resetHuntButton)
      let huntCommand = jumpHistory.first!
      doBinaryJump(button: huntCommand.button, direction: huntCommand.command)
      var replayHistory = jumpHistory
      replayHistory.removeFirst()
      if replayHistory.count > 0 { replayHistory.removeLast()}
      if replayHistory.count > 0 {
        self.replayJumps(history: replayHistory) 
      }
    }
    //    setHunterBackgroundColourByStep(lastHuntButton!, step: boundaryAdHunter?.jumpDistance)
  }
  /// User knows that they clicked wrong (ad/prog) button - reset to start state
  /// - parameter: GUI Button
  @IBAction func huntReset(_ sender: NSButton) {
    guard self.monitorView.player != nil else { return }
    guard boundaryAdHunter != nil else { return }
    boundaryAdHunter!.reset()
    setStatusFieldStringValue(isLoggable: false, message: logMessage.adHuntReset)
    huntButtonsReset()
  }
  
  /// Found boundary or completely lost, so clear the hunter and reset the buttons
  /// - parameter: GUI Button
  @IBAction func huntDone(_ sender: NSButton) {
    huntButtonsReset()
    let outCutDuration = movie.cuts.simpleOutCutDurationInSecs()
    //    let doneMessage = "Advert hunt done ("+CutEntry.hhMMssFromSeconds(outCutDuration)+")"
    //    setStatusFieldStringValue(isLoggable: false, message: doneMessage)
    setStatusFieldStringValue(isLoggable: false, message: String(format: logMessage.huntDoneMsg, CutEntry.hhMMssFromSeconds(outCutDuration)))
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
  
  //  let defaultControlKeyDictionary : [String:FunctionAndButton] = [
  //    keyBoardCommands.advert: (inAdvertisment,backwardHuntButton),
  //    keyBoardCommands.program:(inProgram,forwardHuntButton),
  //    keyBoardCommands.done:(huntDone,doneHuntButton),
  //    keyBoardCommands.reset:(huntReset,resetHuntButton),
  //    keyBoardCommands.inCut:(addMark,inButton),
  //    keyBoardCommands.out:(addMark,outButton),
  //    keyBoardCommands.skipTwoForward:(seekToAction,seekButton2c),
  //    keyBoardCommands.skipTwoBackward:(seekToAction,seekButton1c),
  //  ]
  
  override func keyDown(with event: NSEvent) {
    if (debug) { print("saw keyDown keycode value \(event.keyCode)") }
    
    //    if (event.keyCode == UInt16(kVK_Delete)) { interpretKeyEvents([event]);return } // interpret has dealt with it
    // with thanks based on: http://stackoverflow.com/questions/35539256/detect-when-delete-key-pressed-on-control
    let controlKeyDictionary = defaultControlKeyDictionary
    if let uniCodeDelete = UnicodeScalar(NSEvent.SpecialKey.delete.rawValue)
    {
      if event.charactersIgnoringModifiers == String(Character(uniCodeDelete))
      {
        // check that the viewController window has focus
        if (event.window == self.view.window)
        {
          deleteRowByKeyPress(thenSelect: .previous)
          //          print("Saw delete keypress")
          return
        }
      }
    }
    if let uniCodeLeftArrow = UnicodeScalar(NSEvent.SpecialKey.leftArrow.rawValue)
    {
      if event.charactersIgnoringModifiers == String(Character(uniCodeLeftArrow))
      {
        // check that the viewController window has focus
        if (event.window == self.view.window)
        {
          moveMarkLeftBySteps(creepSteps)
          if (debug) { print("Saw leftArrow keypress") }
          return
        }
      }
    }
    if let uniCodeRightArrow = UnicodeScalar(NSEvent.SpecialKey.rightArrow.rawValue)
    {
      if event.charactersIgnoringModifiers == String(Character(uniCodeRightArrow))
      {
        // check that the viewController window has focus
        if (event.window == self.view.window)
        {
          moveMarkRightBySteps(creepSteps)
          if (debug)  { print("Saw rightArrow keypress") }
          return
        }
      }
    }
    if (event.type == NSEvent.EventType.keyUp || event.type == NSEvent.EventType.keyDown) && NSEvent.modifierFlags.isEmpty
    {
      if let keyString = event.characters {
        if (debug) { print(">>\(keyString)<<") }
        
        if let keyStrokeCommand = controlKeyDictionary[keyString]
        {
          keyStrokeCommand.action(keyStrokeCommand.button)
          if keyString == keyBoardCommands.inCut || keyString == keyBoardCommands.outCut
          {
            huntDone(doneHuntButton)
          }
          return
        }
        // add a mark that is the complement of previous in / out
        if (keyString == keyBoardCommands.lhAddMatching || keyString == keyBoardCommands.rhAddMatching) {
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
      NSSound.beep();NSSound.beep();NSSound.beep()
    case .OUT:
      addMark(sender: inButton)
      huntDone(doneHuntButton)
      NSSound.beep();NSSound.beep();NSSound.beep()
    default: NSSound.beep()
    }
    // and skip forward
    seekToAction(seekButton2c)
  }
  /// Delegate function
  /// Respond to user taping the "delete" button on the keyboard to remove mark
  override func deleteBackward(_ sender: Any?) {
    //    print("Backward delete?")
    let selectedRow = cutsTable.selectedRow
    if (selectedRow >= 0) {
      //      let cutEntry = movie.cuts.entry(at: selectedRow)
      //      if (cutEntry?.type == MARK_TYPE.OUT || cutEntry?.type == MARK_TYPE.IN)
      //      {
      movie.cuts.remove(at: selectedRow)
      cutsTable.reloadData()
      updateCutsMarksGUI()
      cuttable = movie.isCuttable
      cutsUndoRedo?.add(state: movie.cuts)
      //      }
      //      print ("cell is \(cutEntry?.asString())")
    }
  }
  // MARK: adHunter replay support
  var replayTimer : Timer!
  var timerDelayInSeconds = 0.01
  var replayIsRunning = false
  var replayTimerDone = false
  {
    didSet {
      replayTimer.invalidate()
      replayIsRunning = false
    }
  }
  
  /// replay the jump history.  This routine emulates a keyboard operation.
  /// As such, it needs a delay to enable the "seek(to:)" to happen.
  /// This is achieved by wrapping the action call in a repeating timer
  /// block that checks the the seek has completed before processing
  /// the next item in the jump history array.
  /// - parameter history: array of jump history commands created
  ///                      by the advert hunter.
  
  func replayJumps(history: [BoundaryHunter.huntCommand])
  {
    guard history.count > 0 else { return }
    replayIsRunning = true
    if (debug) { print("unjump-ing");print("\(self.boundaryAdHunter?.descriptionOfHistory(jumpHistory: history) ?? "no hunter")")}
    var replayIndex = 0
    replayTimer = Timer.scheduledTimer(withTimeInterval: timerDelayInSeconds, repeats: true) {
      [weak self] (replayTimer) in
      guard  let weakSelf = self else { return }
      
      if (weakSelf.debug) { print("TimerFired seekCompleted is \(weakSelf.seekCompleted) for index \(replayIndex)") }
      if (weakSelf.seekCompleted)
      {
        let entry = history[replayIndex]
        weakSelf.doBinaryJump(button: entry.button, direction: entry.command)
        replayIndex += 1
      }
      if replayIndex >= history.count // all done
      {
        weakSelf.replayTimerDone = true
      }
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
    let result = deleteRecording(recording: self.movie, with: NSDocumentController.shared)
    if result.status != true {
      setStatusFieldStringValue(isLoggable: true, message: result.message)
      NSSound.beep()
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
    if ((segue.identifier) == "EITEdit") {
      print("Saw menu EITEdit segue")
      let eit = sender as! ShortEventDescriptorViewController
      eit.movie = self.movie
    }
  }
  
  // MARK: KeyStrokeCatch protocol
  func didPressLeftArrow() {
    Swift.print("Saw left arrow keystroke")
  }
  func didPressRightArrow() {
    Swift.print("Saw right arrow keystroke")
  }
  
  
  typealias serverTuple = (MountURL:String, MountServer:String, MountPath:String)
  
  /// Look at Mounted Volumes and return a the origin URL and local mounted path
  /// This is to assist in discriminating which system is the source of the recording to determine
  /// the structure of the "remote cut" command when appropriate.  Most BeyonWiz recorders
  /// share "Movie" as the SMB share for recordings.  MacOS deals with multiple mounts of the
  /// same name by appending hypen-digit (-1, -2,...) to the second and subsequent mounts of the same
  /// name (/Volumes/Movie, /Volumes/Movie-1, etc)
  /// - returns: tuple of URL from mount and local mounted location
  
  func remoteMountAndSource() -> [serverTuple]
  {
    var mountDetailsOfInterest = Array<serverTuple>()
    let keys: [URLResourceKey] = [.volumeNameKey,
                                  .volumeIsRemovableKey,
                                  .volumeIsEjectableKey,
                                  .volumeIsBrowsableKey,
                                  .volumeURLKey,
                                  .pathKey]
    let paths = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [])
    if let urls = paths {
      for url in urls {
        let components = url.pathComponents
        if components.count > 1 && components[1] == "Volumes"
        {
          do
              {
                let details = try  url.resourceValues(forKeys: [.volumeURLForRemountingKey,
                                                                .pathKey])
                if let mountURL = details.volumeURLForRemounting?.absoluteString,
                   let mountPath = details.path
                {
                  let DNSPath = MACOS_SMBPath(pathAndShare: mountURL)
                  mountDetailsOfInterest.append((DNSPath.normalized() ,DNSPath.serverName(), mountPath))
                }
              }
          catch {
            print("Failed get resource value for \(url)")
          }
        }
      }
    }
    return mountDetailsOfInterest
  }
}

struct MACOS_SMBPath {
  private let atSign = "@"
  private let MACOS_MountTypeMarker = "._smb._tcp."
  
  var pathAndShare: String
  
  func normalized() -> String {
    // common format is smb://GUEST:@BEYONWIZU4._smb._tcp.local/Movie
    // from which what is wanted is "beyonwizu4.local/Movie/"
    let urlParts = pathAndShare.components(separatedBy: atSign)
    var DNSPath = pathAndShare
    if urlParts.count >= 1 {
      DNSPath = urlParts[1].replacingOccurrences(of: MACOS_MountTypeMarker, with: ".")
      var DNSParts = DNSPath.components(separatedBy: StringsCuts.DIRECTORY_SEPERATOR)
      DNSParts[0] = DNSParts[0].lowercased()
      DNSPath = DNSParts.joined(separator: StringsCuts.DIRECTORY_SEPERATOR)
    }
    return DNSPath
  }
  
  func shareName() -> String {
    let parts = self.pathAndShare.components(separatedBy: StringsCuts.DIRECTORY_SEPERATOR)
    return parts.last!
  }
  
  func serverName() -> String {
    let name = self.normalized().components(separatedBy: StringsCuts.DIRECTORY_SEPERATOR)[0]
    return name
  }
}

extension AVAssetTrack {
  var mediaFormat: String {
    var format = ""
    let descriptions = self.formatDescriptions as! [CMFormatDescription]
    for (index, formatDesc) in descriptions.enumerated() {
      // Get String representation of media type (vide, soun, sbtl, etc.)
      let type =
        CMFormatDescriptionGetMediaType(formatDesc).toString()
      // Get String representation media subtype (avc1, aac, tx3g, etc.)
      let subType =
        CMFormatDescriptionGetMediaSubType(formatDesc).toString()
      // Format string as type/subType
      format += "\(type)/\(subType)"
      // Comma separate if more than one format description
      if index < descriptions.count - 1 {
        format += ","
      }
    }
    return format
  }
}

extension FourCharCode {
  // Create a String representation of a FourCC
  func toString() -> String {
    let bytes: [CChar] = [
      CChar((self >> 24) & 0xff),
      CChar((self >> 16) & 0xff),
      CChar((self >> 8) & 0xff),
      CChar(self & 0xff),
      0
    ]
    let result = String(cString: bytes)
    let characterSet = CharacterSet.whitespaces
    return result.trimmingCharacters(in: characterSet)
  }
}
