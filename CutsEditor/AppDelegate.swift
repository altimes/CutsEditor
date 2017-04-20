//
//  AppDelegate.swift
//  CutsEditor
//
//  Created by Alan Franklin on 2/04/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

@NSApplicationMain



class AppDelegate: NSObject, NSApplicationDelegate, AppPreferences {
  
  var defaultSkips = skipPreferences()
  var defaultSorting = sortingPreferences()
  var defaultGeneral = generalPreferences()
  var defaultVideoPlayerPrefs = videoPlayerPreferences()
  var defaults : UserDefaults?
  var defaultAdHunter = adHunterPreferences()
  var skipDisplayArray      = [String](repeating: "", count: 10)   // display 1..10
  var skipValueArray        = [Double](repeating: 0.0, count: 10)  // values 1..10
  var fileToOpen: String?
  /// development flag, may become a "reset to default" function
  var setUserPreferencesToDefault = false
  var debug = false
  
  public var cuttingQueues = [CuttingQueue]()
  public var currentMovie : Recording?
  
  func applicationDidFinishLaunching(_ notification: Notification)
  {
    if (debug) {
      if let dict = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier!) {
        print(dict)
      }
    }
    if (setUserPreferencesToDefault) {
      UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
      UserDefaults.standard.synchronize()
    }
    // Insert code here to initialize your application
    // load up the user preferences or fabricate default settings
    defaults = UserDefaults.standard
    if defaults?.value(forKey: sortStringConsts.order) != nil
    {
      // sorting preferences
      defaultSorting.isAscending = (defaults?.bool(forKey: sortStringConsts.order))!
      defaultSorting.sortBy = (defaults?.string(forKey: sortStringConsts.sortBy))!
      NotificationCenter.default.post(name: Notification.Name(rawValue: sortDidChange), object: nil)
      
      // skip setting preferences
      let skipDisplayArray = defaults?.array(forKey: sortStringConsts.skipDisplayArray) as! [String]
      let skipValueArray = defaults?.array(forKey: sortStringConsts.skipValueArray) as! [Double]
      for i in 0 ... 4 {
        defaultSkips.lhs[i].value = skipValueArray[i]
        defaultSkips.lhs[i].display = skipDisplayArray[i]
        defaultSkips.rhs[i].value = skipValueArray[i+5]
        defaultSkips.rhs[i].display = skipDisplayArray[i+5]
      }
      NotificationCenter.default.post(name: Notification.Name(rawValue: skipsDidChange), object: nil)
      
      // video player preferences
      defaultVideoPlayerPrefs.playbackControlStyle = videoControlStyle(rawValue: (defaults?.integer(forKey: playerConfigKeys.playerControlStyle))!)!
      defaultVideoPlayerPrefs.playbackShowFastForwardControls = (defaults?.bool(forKey: playerConfigKeys.playerSecondaryButtons))!
      defaultVideoPlayerPrefs.skipCutSections = (defaults?.bool(forKey: playerConfigKeys.playerHonourCuts))!
      NotificationCenter.default.post(name: Notification.Name(rawValue: playerDidChange), object: nil)
      
      // general preferences

      if let autoWriteValue = (defaults?.integer(forKey: generalStringConsts.autoWrite))
      {
        defaultGeneral.autoWrite = CheckMarkState.lookup(autoWriteValue)
        if let enumRawValue = defaults?.integer(forKey: generalStringConsts.bookmarkMode)
        {
          if let mode = MARK_MODE(rawValue: enumRawValue)
          {
            defaultGeneral.markMode = mode
          }
          else {
            defaultGeneral.markMode = MARK_MODE.FIXED_COUNT_OF_MARKS
          }
        }
        defaultGeneral.countModeNumberOfMarks = (defaults?.integer(forKey: generalStringConsts.bookmarkCount))!
        defaultGeneral.spacingModeDurationOfMarks = (defaults?.integer(forKey: generalStringConsts.bookmarkSpacing))!
        
        if let pvrArray = defaults?.array(forKey:  generalStringConsts.pvrConfigKey)
        {
          let pvrSettings = (pvrArray as! [NSData]).map { pvrPreferences(data: $0)! }
          defaultGeneral.systemConfig.pvrSettings = pvrSettings
        }
        // create the array of queues for cutting jobs
        makeQueues()
      }
      else {
        initGeneralSettings()
        saveGeneralPreference(defaultGeneral)
      }
      NotificationCenter.default.post(name: Notification.Name(rawValue: generalDidChange), object: nil)
    }
    else {  // create initial userdefaults entry
      initSkipSettings()
      initSortPreferences()
      initGeneralSettings()
      initVideoPlayerPrefs()
      saveSkipPreference(defaultSkips)
      saveSortPreference(defaultSorting)
      saveGeneralPreference(defaultGeneral)
      saveVideoPlayerPreference(defaultVideoPlayerPrefs)
    }
    setInsertBookmarksMenuItemText()
  }
  
  
  /// fabricate the cuting queue for each pvr configuration
  func makeQueues()
  {
    // create the array of queues for cutting jobs
    for entry in defaultGeneral.systemConfig.pvrSettings
    {
      let cutterOperationsQueue = CuttingQueue.serialOpQueue(withName: entry.title)
      cuttingQueues.append(CuttingQueue(cutterOperationsQueue))
    }

  }
  
  /// Lifecycle calls
  func applicationWillTerminate(aNotification: NSNotification) {
    // Insert code here to tear down your application
    // TODO: send cancel to any jobs pending in Queues
  }
  
  /// setup entries in bookmarks menu
  func setInsertBookmarksMenuItemText()
  {
    let appMenu = NSApplication.shared().mainMenu
    let marksMenu = appMenu?.item(withTitle: "Marks")?.submenu
    let insertItem = marksMenu?.item(withTag: 100)
    let insertText = defaultGeneral.markMode == MARK_MODE.FIXED_COUNT_OF_MARKS ? "\(defaultGeneral.countModeNumberOfMarks) Bookmarks" : "\(defaultGeneral.spacingModeDurationOfMarks) sec Bookmarks"
    insertItem?.title = "Insert "+insertText
  }
  
  /// create a system default sorting preferences
  func initSortPreferences()
  {
    defaultSorting.isAscending = true
    defaultSorting.sortBy = sortStringConsts.byDate
    NotificationCenter.default.post(name: Notification.Name(rawValue: sortDidChange), object: nil)
  }
  
  /// create system default skip button settings
  func initSkipSettings()
  {
    let lh1 = skipPair(display: "-1s", value: -1.0)
    let lh2 = skipPair(display: "-15s", value: -15.0)
    let lh3 = skipPair(display: "-1m", value: -60.0)
    let lh4 = skipPair(display: "-15m", value: -15.0*60.0)
    let lh5 = skipPair(display: "-60m", value: -60.0*60.0)
    
    let rh1 = skipPair(display: "+1s", value: 1.0)
    let rh2 = skipPair(display: "+15s", value: 15.0)
    let rh3 = skipPair(display: "+1m", value: 60.0)
    let rh4 = skipPair(display: "+15m", value: 15.0*60.0)
    let rh5 = skipPair(display: "+60m", value: 60.0*60.0)
    
    defaultSkips = skipPreferences(lhs: [lh1,lh2,lh3,lh4,lh5], rhs: [rh1,rh2,rh3,rh4,rh5])
    NotificationCenter.default.post(name: Notification.Name(rawValue: skipsDidChange), object: nil)
  }
 
  /// Create a default general preferences setting with nominally sensible values
  /// May be overriden by user defaults
  func initGeneralSettings()
  {
    defaultGeneral = generalPreferences()
    makeQueues()
  }
  
  /// Create the video player preferences with system default values
  func initVideoPlayerPrefs()
  {
    defaultVideoPlayerPrefs = videoPlayerPreferences()
    NotificationCenter.default.post(name: Notification.Name(rawValue: playerDidChange), object: nil)
  }
  
  // MARK: AppPreference Protocol
  
  /// return current preferences
  func skipPreference() -> skipPreferences
  {
    return defaultSkips
  }
  
  /// return current preferences
  func sortPreference() -> sortingPreferences
  {
//    print(defaultSorting)
    return defaultSorting
  }
  
  /// return ad hunting preferences
  func adHunterPreference() -> adHunterPreferences
  {
    return defaultAdHunter
  }
 
  /// return current preferences
  func generalPreference() -> generalPreferences
  {
    return defaultGeneral
  }
  
  /// return current preferences
  internal func videoPlayerPreference() -> videoPlayerPreferences {
    return defaultVideoPlayerPrefs
  }
  
  /// commit preferences to userdefaults
  func saveSortPreference(_ sortOrder: sortingPreferences)
  {
    defaultSorting = sortOrder
    defaults?.set(sortOrder.isAscending, forKey: sortStringConsts.order)
    defaults?.set(sortOrder.sortBy, forKey: sortStringConsts.sortBy)
  }
  
  /// commit preferences to userdefaults
  func saveSkipPreference(_ newSkips: skipPreferences)
  {
    defaultSkips = newSkips
    
    // update userdefaults
    for i in 0 ... 4 {
       skipValueArray[i] = defaultSkips.lhs[i].value
       skipDisplayArray[i] = defaultSkips.lhs[i].display
       skipValueArray[i+5] = defaultSkips.rhs[i].value
       skipDisplayArray[i+5] = defaultSkips.rhs[i].display
    }
    defaults?.set(skipValueArray, forKey: sortStringConsts.skipValueArray)
    defaults?.set(skipDisplayArray, forKey: sortStringConsts.skipDisplayArray)
  }
  
  // bring the pseudo singleton of cutting queues in to sync the preference changes
  func updateCutterQueues(oldPVRArray: [pvrPreferences], newPVRArray: [pvrPreferences])
  {
    // check if the named PVR still exists
    for entry in cuttingQueues
    {
      let queueTitle = entry.queue.name!
      if (!newPVRArray.contains(where: {$0.title == queueTitle}))
      {
        // pvr removed - kill all pending jobs in queue and delete queue
        entry.queue.cancelAllOperations()
        let entryIndex = cuttingQueues.index(of: entry)
        cuttingQueues.remove(at: entryIndex!)
      }
    }
    // now the opposite, check for PVR entry that does not have a corresponding cutting Queue
    for thisPvr in newPVRArray {
      if (!cuttingQueues.contains(where: {$0.queue.name == thisPvr.title}))
      {
        // create a new queue and append it
        let queue = CuttingQueue.serialOpQueue(withName: thisPvr.title)
        cuttingQueues.append(CuttingQueue(queue))
      }
    }
  }
  
  /// Find the queue with the given title
  /// - parameters withTitle: title of the queue
  /// - returns: the queue or nil
  internal func cuttingQueue(withTitle title: String) -> CuttingQueue?
  {
    if let index = cuttingQueues.index(where: {$0.queue.name == title})
    {
      return cuttingQueues[index]
    }
    else {
      return nil
    }
  }
  
  /// Get the array of cutting queues
  func cuttingQueueTable() -> [CuttingQueue]
  {
    return self.cuttingQueues
  }
  
  /// commit preferences to userdefaults
  func saveGeneralPreference(_ general: generalPreferences)
  {
    // update cutter queues with changes to pvr list if any
    updateCutterQueues(oldPVRArray: defaultGeneral.systemConfig.pvrSettings, newPVRArray: general.systemConfig.pvrSettings)
    defaultGeneral = general
    defaults?.set(defaultGeneral.autoWrite.rawValue, forKey: generalStringConsts.autoWrite)
    defaults?.set(defaultGeneral.countModeNumberOfMarks, forKey: generalStringConsts.bookmarkCount)
    defaults?.set(defaultGeneral.spacingModeDurationOfMarks, forKey: generalStringConsts.bookmarkSpacing)
    defaults?.set(defaultGeneral.markMode.rawValue, forKey: generalStringConsts.bookmarkMode)
   
    // pvr setttings
    let encoded = defaultGeneral.systemConfig.pvrSettings.map { $0.encode() }
    defaults?.set(encoded, forKey: generalStringConsts.pvrConfigKey)
    
    // sync menu bar to match
    setInsertBookmarksMenuItemText()
  }
  
  /// commit preferences to userdefaults
  func saveVideoPlayerPreference(_ videoPlayer: videoPlayerPreferences) {
    defaultVideoPlayerPrefs = videoPlayer
    
    defaults?.set(defaultVideoPlayerPrefs.skipCutSections, forKey:playerConfigKeys.playerHonourCuts)
    defaults?.set(defaultVideoPlayerPrefs.playbackControlStyle.rawValue, forKey:playerConfigKeys.playerControlStyle)
    defaults?.set(defaultVideoPlayerPrefs.playbackShowFastForwardControls, forKey:playerConfigKeys.playerSecondaryButtons)
  }
 
  /// catch and handle menu "File Open Recent" selection
  func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    // print("saw request to open recent file with name <\(filename)")
    fileToOpen = filename
    NotificationCenter.default.post(name: Notification.Name(rawValue: fileOpenDidChange), object: fileToOpen!)
   return true
  }
  
  /// set/get "Current Movie"
  func movie() -> Recording? {
    return currentMovie
  }
  
  func setMovie(movie: Recording?) {
    self.currentMovie = movie
  }
}

