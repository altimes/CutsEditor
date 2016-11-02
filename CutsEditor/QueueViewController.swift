//
//  QueueViewController.swift
//  CutsEditor
//
//  Created by Alan Franklin on 24/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Cocoa

 struct queueTableStringConsts {
  static let queueColumnIdentifier :String = "queuename"
  static let timestampColumnIdentifier = "timestamp"
  static let movienameColumnIdentifier = "moviename"
  static let statusColumnIdentifier = "status"
  static let resultColumnIdnetifier = "resultValue"
  static let messageColumnIdnetifier = "resultMessage"
}

typealias compositeLog = (queue: String, entry: CuttingEntry)

class QueueViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

  @IBOutlet weak var queuesTable: NSTableView!
  @IBOutlet weak var cancelJobButton: NSButton!
  @IBOutlet weak var queueJobCount: NSTextField!
  
  var debug = true
  var queues = [CuttingQueue]()
  var preferences = NSApplication.shared().delegate as! AppPreferences
  var jobsListing = [compositeLog]()
  
  var tablelength: Int {
    get {
      let entrylist = queues.flatMap {$0.cuttingList}
      return entrylist.count
    }
  }
  
  override func viewDidLoad() {
      super.viewDidLoad()
      // Do view setup here.
    queuesTable.delegate = self
    queuesTable.dataSource = self
    NotificationCenter.default.addObserver(self, selector: #selector(queuesContentChanged(_:)), name: NSNotification.Name(rawValue: jobQueueDidChange), object: nil )
    NotificationCenter.default.addObserver(self, selector: #selector(queuesConfigChanged(_:)), name: NSNotification.Name(rawValue: generalDidChange), object: nil )
    queuesTable.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    queuesTable.sizeLastColumnToFit()
    refreshTable()
  }
  
  func setup() {
    // get a reference to the cutting queues
    queues = preferences.cuttingQueueTable()
    jobsListing = combineQueues()
  }
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setup()
  }
  
  override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
    super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    setup()
  }
  
  // MARK: - TableView delegate, datasource and table related functions
  
  // Get the view related to selected cell and populated the data value
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
  {
    var cellContent : String = "???"
    let logEntry = cutEntryFor(tableRow: row)
    if let columnId = tableColumn?.identifier
    {
      switch columnId {
      case queueTableStringConsts.queueColumnIdentifier:
        cellContent = logEntry.queue
      case queueTableStringConsts.movienameColumnIdentifier:
        cellContent = ViewController.programDateTitleFrom(movieURLPath:  logEntry.entry.moviePathURL)
      case queueTableStringConsts.timestampColumnIdentifier:
        cellContent = logEntry.entry.timeStamp
      case queueTableStringConsts.statusColumnIdentifier:
        cellContent = logEntry.entry.currentState.stringValue
      case queueTableStringConsts.messageColumnIdnetifier:
        cellContent = logEntry.entry.resultMessage
      case queueTableStringConsts.resultColumnIdnetifier:
        if (logEntry.entry.resultValue != -1) {
          cellContent = "\(logEntry.entry.resultValue)"
        }
        else {
          cellContent = ""
        }
      default:
        cellContent = "???"
      }
    }
    let result : NSTableCellView  = tableView.make(withIdentifier: tableColumn!.identifier, owner: self)
      as! NSTableCellView
    result.textField?.stringValue = cellContent
    return result
  }
  
  func numberOfRows(in tableView: NSTableView) -> Int
  {
    var rowCount = 0
    for entry in queues {
      rowCount += entry.cuttingList.count
    }
    return rowCount
  }
  
//  func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
//    // don't care about the column trigger a reload
//    jobsListing = combineQueues()
//    queuesTable.reloadData()
//  }
  
  func tableViewSelectionDidChange(_ notification: Notification) {
    let selectedRow = queuesTable.selectedRow
//    let rowSet = IndexSet(integer: selectedRow)
//    queuesTable.selectRowIndexes(rowSet, byExtendingSelection: false)
    guard (selectedRow>=0 && selectedRow<tablelength) else
    {
      // out of bounds, silently ignor
      return
    }
    let thisQueue = jobsListing[selectedRow].queue
    let thisMovieName = jobsListing[selectedRow].entry.moviePathURL
    // check that there is no related cancelled, completed or executing
    let relatedEntries = jobsListing.filter { ($0.queue == thisQueue) && ($0.entry.currentState.state == CuttingState.completed || $0.entry.currentState.state == CuttingState.running || $0.entry.currentState.state == CuttingState.completed || $0.entry.currentState.state == CuttingState.cancelled) && ($0.entry.moviePathURL == thisMovieName) }
    cancelJobButton.isEnabled = (relatedEntries.count == 0)
  }
  
// make the row height vary according to the message field (may be multiline)
  func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat
  {
    let rowEntry = cutEntryFor(tableRow: row)
    let message = rowEntry.entry.resultMessage
    let messageColumn = tableView.column(withIdentifier: queueTableStringConsts.messageColumnIdnetifier)
    let cell = tableView.tableColumns[messageColumn].dataCell(forRow: row) as! NSTextFieldCell
    cell.stringValue = message
    let size = cell.cellSize
    return size.height
  }
  
  /// "swipe" action function to delete rows from table.
  /// Updates model and GUI
  func jobCancel(_ action:NSTableViewRowAction, indexPath:Int)
  {
    doCancel()
  }
  
  /// register swipe actions
  
  func tableView(_ tableView: NSTableView, rowActionsForRow row: Int, edge: NSTableRowActionEdge) -> [NSTableViewRowAction] {
    if edge == NSTableRowActionEdge.trailing {
      let cancelAction = NSTableViewRowAction(style: NSTableViewRowActionStyle.destructive, title: "Cancel", handler: jobCancel)
      return [cancelAction]
    }
    return [NSTableViewRowAction]()
  }
 
  // Delegate function on row addition.
  // This delegate changes the background colour of the result cell based on the result value
  
  func tableView(_ tableView: NSTableView, didAdd rowView: NSTableRowView, forRow row: Int) {
    // try to change the color of the rowView
    var colour = NSColor.white
    // bounds checking
    guard row >= 0 && row < tablelength  else { return }
    let resultForRow = jobsListing[row].entry.resultValue
    if (resultForRow == 0)     { colour = NSColor.green }
    else if (resultForRow > 0) { colour = NSColor.red }
    else                       { colour = NSColor.blue }
    let resultColumnIndex = tableView.column(withIdentifier: queueTableStringConsts.resultColumnIdnetifier)
    let resultCell = rowView.view(atColumn: resultColumnIndex) as! NSTableCellView
    resultCell.textField?.drawsBackground = true
    resultCell.textField?.backgroundColor = colour.withAlphaComponent(0.45)
  }
  
//  func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
//    if (jobsListing[row].1.currentState.state == CuttingState.onqueue)
//    {
//      let thisQueue = jobsListing[row].0
//      let thisMovieName = jobsListing[row].1.moviePathURL
//      // check that there is no related cancelled, completed or executing
//      let relatedEntries = jobsListing.filter { ($0.queue == thisQueue) && ($0.entry.currentState.state == CuttingState.completed || $0.entry.currentState.state == CuttingState.running || $0.entry.currentState.state == CuttingState.completed) && ($0.entry.moviePathURL == thisMovieName) }
//        if (relatedEntries.count == 0) {
//          return true
//        } // end filter
//    }
//    return false
//  }
 
  
//  // beware only called on mouse clicks not keyboard
//  // only rows where jobs are in the waiting state are selectable
//  func tableViewSelectionIsChanging(_ notification: Notification) {
//    // enable the cancel button
//    cancelJobButton.isEnabled = true
//  }
  
  
//  func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
//    // user clicked in table, suppress timed updates
//    self.suppressTimedUpdates = true
//    if (debug) { print("Saw column did Click") }
//    
//  }

  func cutEntryFor(tableRow: Int) -> (compositeLog)
  {
    var ceiling = 0
    var result = compositeLog("undetermined",CuttingEntry(moviePathURL: "matched"))
    
    for queue in queues {
      ceiling += queue.cuttingList.count
      if tableRow < ceiling {
        // this queue
        let index = queue.cuttingList.count - (ceiling - tableRow)
        result.entry = queue.cuttingList[index]
        result.queue = queue.queue.name!
        break
      }
    }
    return result
  }

  /// Processes all queues and combines them into a singe array of queueName and cuttingList touples
  /// for each of processing
  /// returns : touple of quename as String an the the details of the job as a cuttingEntry
  func combineQueues() -> [compositeLog]
  {
    var combinedQueues = [compositeLog]()
    for eachQueue in queues
    {
      let eachJobsListing = eachQueue.cuttingList.map {compositeLog(eachQueue.queue.name!, $0)}
      combinedQueues.append(contentsOf: eachJobsListing)
    }
    return combinedQueues
  }

  func doCancel()
  {
    let row = queuesTable.selectedRow
    let queueName = jobsListing[row].queue
    let moviePathURL = jobsListing[row].entry.moviePathURL
    if let cutterQueue = preferences.cuttingQueue(withTitle: queueName) {
      let ops = cutterQueue.queue.operations
      let thisJobOp = ops.filter({$0.name == moviePathURL})
      // since name is unique should only have 1 entry ignor any extras
      if (thisJobOp.count>0) {
        thisJobOp[0].cancel()
        queuesTable.deselectRow(row)
      }
      else {
        NSBeep()
      }
    }
  }
  
  func refreshTable()
  {
    let lastSelectedRow = queuesTable.selectedRow
    let isSelected = queuesTable.isRowSelected(lastSelectedRow)
    jobsListing = combineQueues()
    queuesTable.reloadData()
    // reselect row if it was selected (reload kills selection)
    if (isSelected && lastSelectedRow != 0) { queuesTable.selectRowIndexes(IndexSet(integer: lastSelectedRow), byExtendingSelection: false) }
    var jobQueueCount=[String]()
    for entry in preferences.cuttingQueueTable()
    {
      let count = entry.queue.operationCount
      jobQueueCount.append("\(entry.queue.name!):[\(count)]")
    }
    queueJobCount.stringValue = jobQueueCount.joined(separator: "  ")
    let lastRow = jobsListing.count-1
    queuesTable.scrollRowToVisible(lastRow)
  }
  
  func queuesContentChanged(_ notification: Notification)
  {
    refreshTable()
  }
  
  func queuesConfigChanged(_ notification: Notification)
  {
    // check to see if the configuration of the queues has changed
    let newQueues = preferences.cuttingQueueTable()
    if (newQueues.count != queues.count) {
      // definite change
      queues = newQueues
    }
    else {
      // same count, but may have added and deleted
      // get a list of queue names from each, sort and then compare
      let oldQueueNameList = queues.map{$0.queue.name!}.sorted()
      let newQueueNameList = newQueues.map{$0.queue.name!}.sorted()
      if (oldQueueNameList != newQueueNameList) {
        queues = newQueues
      }
    }
    // for good measure
    refreshTable()
  }
  
  @IBAction func refresh(_ sender: NSButton) {
    refreshTable()
  }
  
  @IBAction func done(_ sender: NSButton) {
    // close the window
    self.view.window?.close()
  }
  
  /// Cancel the selected entry
  @IBAction func cancelSelectedJob(_ sender: NSButton) {
    // get the related queue entry
    let selectedIndices = queuesTable.selectedRowIndexes
    if (selectedIndices.count>=1) {
      doCancel()
    }
    else {
      NSBeep()
    }
  }
}
