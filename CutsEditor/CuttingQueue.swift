//
//  CuttingQueue.swift
//  CutsEditor
//
//  Created by Alan Franklin on 22/10/2016.
//  Copyright © 2016 Alan Franklin. All rights reserved.
//

import Foundation


enum CuttingState: String {
//  case holding = "Holding"
  case onqueue = "Waiting"
  case running = "Executing"
  case completed = "Completed"
  case cancelled = "Cancelled"
  case unknown = "Unknown"
}

class CuttingStateString {
  var state : CuttingState = .unknown
  var stringValue: String  {
    get {
      return state.rawValue
    }
    set {
      if let possible = CuttingState(rawValue: newValue)
      {
        state = possible
      }
    }
  }
  init(state: CuttingState) {
    stringValue = state.rawValue
  }
}

/// Single item ready for cutting
class CuttingEntry : NSObject {
  var moviePathURL: String = ""
  var currentState: CuttingStateString
  var resultMessage: String = ""
  var resultValue : Int = -1
  var timeStamp: String = ""
 
  init(moviePathURL: String) {
    self.moviePathURL = moviePathURL
    currentState = CuttingStateString(state: .unknown)
    resultValue = -1
    resultMessage = ""
    timeStamp = ""
  }
  
  func contents() -> String
  {
    let movieIDString = ViewController.programDateTitleFrom(movieURLPath: moviePathURL)
    let results = (resultValue == -1 ) ? "" : " \(resultValue)" + " " + resultMessage
    return timeStamp + " " + movieIDString + " " + currentState.stringValue + results
  }
}

/// Model of queue of jobs in a queue for submission
/// to the cutting process or that have been cut
class CuttingQueue : Equatable
{
  var cuttingList = [CuttingEntry]()
  var queue: OperationQueue
  var debug = false
  
  init(_ cuttingQueue: OperationQueue)
  {
    queue = cuttingQueue
  }
  
  static func serialOpQueue(withName queueName: String) -> OperationQueue
  {
    let queue = OperationQueue()
    queue.name = queueName
    queue.maxConcurrentOperationCount = 1
    return queue
  }
  
  static func localQueue() -> CuttingQueue {
    return CuttingQueue(CuttingQueue.serialOpQueue(withName: mcutConsts.fixedLocalName))
  }
  
  func logQueueEvent(moviePath: String, state newState: CuttingState)
  {
    logQueueEvent(moviePath: moviePath, state: newState, resultValue: -1, resultString: "")
  }
  
  func logQueueEvent(moviePath: String, state newState: CuttingState, resultValue result: Int,  resultString message: String)
  {
    let logEntry = CuttingEntry(moviePathURL: moviePath)
    logEntry.currentState = CuttingStateString(state: newState)
    logEntry.timeStamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
    logEntry.resultMessage = message
    logEntry.resultValue = result
    cuttingList.append(logEntry)
    NotificationCenter.default.post(name: Notification.Name(rawValue: jobQueueDidChange), object: nil)
  }
  
  func jobAdd(op movieCutterJob: MovieCuttingOperation) {
    queue.addOperation(movieCutterJob)
    logQueueEvent(moviePath: movieCutterJob.moviePath, state: .onqueue)
    if(debug) { print(#function+"\n"+description()) }
  }
  
  func jobCancelled(moviePath: String, result: Int, resultMessage: String) {
    logQueueEvent(moviePath: moviePath, state: .cancelled, resultValue: result, resultString: resultMessage)
    if(debug) { print(#function+"\n"+description()) }
  }
  
  func jobStarted(moviePath: String) {
    logQueueEvent(moviePath: moviePath, state: .running)
    if(debug) { print(#function+"\n"+description()) }
  }
  
  func jobCompleted(moviePath: String, result: Int, resultMessage: String) {
    logQueueEvent(moviePath: moviePath, state: .completed, resultValue: result, resultString: resultMessage)
    if(debug) { print(#function+"\n"+description()) }
  }
  
  /// generate a full list of all jobs and current state
  func description() -> String
  {
    var jobQueueContents = ""
    for job in cuttingList {
      jobQueueContents += "\n"+job.contents()
    }
    return jobQueueContents
  }
}

func == (left: CuttingQueue, right: CuttingQueue) -> Bool {
  return left.cuttingList == right.cuttingList && left.queue == right.queue
}
