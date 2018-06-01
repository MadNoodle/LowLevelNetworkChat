/**
 * Copyright (c) 2017 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

class ChatRoomViewController: UIViewController {
  
  let chatRoom = ChatRoom()
  
  let tableView = UITableView()
  let messageInputBar = MessageInputView()
  
  var messages = [Message]()
  
  var username = ""
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    chatRoom.delegate = self
    // Initialize communication
    chatRoom.setupNetworkCommunication()
    chatRoom.joinChat(username: username)
    
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    chatRoom.stopChatSession()
  }
}

//MARK - Message Input Bar
extension ChatRoomViewController: MessageInputDelegate {
  func sendWasTapped(message: String) {
    chatRoom.sendMessage(message: message)
  }
}

/// Chat Room Object
class ChatRoom: NSObject {
  
  weak var delegate: ChatRoomDelegate?
  // Define Streams
  var inputStream: InputStream!
  var outputStream: OutputStream!
  
  // property to store username
  var username = ""
  
  // Max sent data cap
  let maxReadLenght = 4096
  
  /// Configure Steams
  func setupNetworkCommunication() {
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                       "localhost" as CFString,
                                       80,
                                       &readStream,
                                       &writeStream)
    
    inputStream = readStream!.takeRetainedValue()
    outputStream = writeStream!.takeRetainedValue()
    
    inputStream.delegate = self
  
    
    inputStream.schedule(in: .main, forMode: .commonModes)
    outputStream.schedule(in: .main, forMode: .commonModes)
    
    inputStream.open()
    outputStream.open()
  }
  

  
  func joinChat(username: String) {
    let data = "iam:\(username)".data(using: .ascii)!
    self.username = username
    _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
  }
  
  func sendMessage(message: String) {
    let data = "msg: \(message)".data(using: .ascii)!
    _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count)}
  }
  
  func stopChatSession() {
    inputStream.close()
    outputStream.close()
  }
}

extension ChatRoom: StreamDelegate {
  /// Method to stream data in and out
  func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case Stream.Event.hasBytesAvailable:
      print("new message received")
      readAvailableBytes(stream: aStream as! InputStream)
    case Stream.Event.endEncountered:
print("new message received")
      stopChatSession()
    case Stream.Event.errorOccurred:
      print("error occurred")
    case Stream.Event.hasSpaceAvailable:
      print("has space available")
    default:
      print("some other event...")
      break
    }
  }
  
  private func readAvailableBytes(stream: InputStream) {
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLenght)
    
    while stream.hasBytesAvailable {
      let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLenght)
      
      if numberOfBytesRead < 0 {
        if let _ = inputStream.streamError {
          break
        }
      }
      
      if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
        delegate?.receivedMessage(message: message)
      }
    }
  }
  
  private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                      length: Int) -> Message? {
    guard let stringArray = String(bytesNoCopy: buffer,
                                   length: length,
                                   encoding: .ascii,
                                   freeWhenDone: true)?.components(separatedBy: ":"),
      let name = stringArray.first,
      let message = stringArray.last else {
        return nil
    }
    
    let messageSender:MessageSender = (name == self.username) ? .ourself : .someoneElse
    
    return Message(message: message, messageSender: messageSender, username: name)
  }
  
}

protocol ChatRoomDelegate: class {
  func receivedMessage(message: Message)
}

extension ChatRoomViewController: ChatRoomDelegate {
  func receivedMessage(message: Message) {
    insertNewMessageCell(message)
  }
}
