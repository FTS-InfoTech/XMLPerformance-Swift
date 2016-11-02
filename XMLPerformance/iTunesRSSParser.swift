//
//  iTunesRSSParser.swift
//  XMLPerformance
//
//  Copyright (c) 2015 FTS InfoTech, LLC.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

enum XMLParserType: Int {
    case Abstract      = -1
    case NSXMLParser
    case LibXMLParser
}

// Protocol for the parser to communicate with its delegate.
@objc protocol iTunesRSSParserDelegate: NSObjectProtocol {
    
    // Called by the parser when parsing is finished.
    optional func parserDidEndParsingData(parser: iTunesRSSParser)

    // Called by the parser in the case of an error.
    optional func parser(parser: iTunesRSSParser, didFailWithError: NSError)
    
    // Called by the parser when one or more songs have been parsed. This method may be called multiple times.
    optional func parser(parser: iTunesRSSParser, didParseSongs parsedSongs: [AnyObject]!)
}


class iTunesRSSParser: NSObject {
    private let countForNotification = 10
    
    var delegate: iTunesRSSParserDelegate?
    
    var parsedSongs = [Song]()

    // This time interval is used to measure the overall time the parser takes to download and parse XML.
    var startTimeReference: NSTimeInterval?
    var downloadStartTimeReference: NSTimeInterval?
    
    var parseDuration: NSTimeInterval = 0
    var downloadDuration: NSTimeInterval = 0
    var totalDuration: NSTimeInterval = 0
    
    // Subclasses must implement this method and return the appropriate name for their XMLParserType.
    class func parserName() -> String {
        preconditionFailure("Class method parserName not valid for abstract base class iTunesRSSParser")
    }
    
    // Subclasses must implement this method and return the appropriate XMLParserType
    class var parserType: XMLParserType {
        preconditionFailure("Class method parserType not valid for abstract base class iTunesRSSParser")
    }
    
    // Subclasses must implement this method. It will be invoked on a secondary thread to keep the application responsive.
    // Although NSURLConnection is inherently asynchronous, the parsing can be quite CPU intensive on the device, so
    // the user interface can be kept responsive by moving that work off the main thread. This does create additional
    // complexity, as any code which interacts with the UI must then do so in a thread-safe manner.
    func downloadAndParse(url: NSURL) {
        preconditionFailure("Object is of abstract base class iTunesRSSParser")
    }

    
    func start() {
        startTimeReference = NSDate.timeIntervalSinceReferenceDate()
        NSURLCache.sharedURLCache().removeAllCachedResponses()
        parsedSongs = [Song]()
        let url = NSURL(string: "http://ax.phobos.apple.com.edgesuite.net/WebObjects/MZStore.woa/wpa/MRSS/newreleases/limit=300/rss.xml")
        NSThread.detachNewThreadSelector(#selector(iTunesRSSParser.downloadAndParse(_:)), toTarget: self, withObject: url)
    }
    

    // Subclasses should invoke these methods and let the superclass manage communication with the delegate.
    // Each of these methods must be invoked on the main thread.
    func downloadStarted() {
        assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
        downloadStartTimeReference = NSDate.timeIntervalSinceReferenceDate()
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    func downloadEnded() {
        assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
        let duration = NSDate.timeIntervalSinceReferenceDate() - downloadStartTimeReference!
        downloadDuration += duration
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
    
    func parseEnded() {
        assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
        
        if parsedSongs.count > 0 {
            delegate?.parser?(self, didParseSongs: parsedSongs)
        }
        
        parsedSongs.removeAll()
        
        delegate?.parserDidEndParsingData?(self)
        
        let duration = NSDate.timeIntervalSinceReferenceDate() - startTimeReference!
        totalDuration = duration
        
        WriteStatisticToDatabase(self.dynamicType.parserType, downloadDuration, parseDuration, totalDuration);
    }
    
    func parsedSong(song: Song) {
        assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
        parsedSongs.append(song)
        if parsedSongs.count > countForNotification {
            delegate?.parser?(self, didParseSongs: parsedSongs)
            parsedSongs.removeAll()
        }
    }
    
    func parseError(error: NSError) {
        assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
        delegate?.parser?(self, didFailWithError:error)
    }
    
    func addToParseDuration(duration: NSTimeInterval) {
        assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
        parseDuration += duration
    }
}
