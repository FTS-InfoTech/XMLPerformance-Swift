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
    case abstract      = -1
    case xmlParser
    case libXMLParser
}

// Protocol for the parser to communicate with its delegate.
@objc protocol iTunesRSSParserDelegate: NSObjectProtocol {
    
    // Called by the parser when parsing is finished.
    @objc optional func parserDidEndParsingData(_ parser: iTunesRSSParser)

    // Called by the parser in the case of an error.
    @objc optional func parser(_ parser: iTunesRSSParser, didFailWithError: NSError)
    
    // Called by the parser when one or more songs have been parsed. This method may be called multiple times.
    @objc optional func parser(_ parser: iTunesRSSParser, didParseSongs parsedSongs: [AnyObject]!)
}


class iTunesRSSParser: NSObject {
    fileprivate let countForNotification = 10
    
    var delegate: iTunesRSSParserDelegate?
    
    var parsedSongs = [Song]()

    // This time interval is used to measure the overall time the parser takes to download and parse XML.
    var startTimeReference: TimeInterval?
    var downloadStartTimeReference: TimeInterval?
    
    var parseDuration: TimeInterval = 0
    var downloadDuration: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    
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
    func downloadAndParse(_ url: URL) {
        preconditionFailure("Object is of abstract base class iTunesRSSParser")
    }

    
    func start() {
        startTimeReference = Date.timeIntervalSinceReferenceDate
        URLCache.shared.removeAllCachedResponses()
        parsedSongs = [Song]()
        let url = URL(string: "http://ax.phobos.apple.com.edgesuite.net/WebObjects/MZStore.woa/wpa/MRSS/newreleases/limit=300/rss.xml")
        Thread.detachNewThreadSelector(#selector(iTunesRSSParser.downloadAndParse(_:)), toTarget: self, with: url)
    }
    

    // Subclasses should invoke these methods and let the superclass manage communication with the delegate.
    // Each of these methods must be invoked on the main thread.
    func downloadStarted() {
        assert(Thread.isMainThread, "\(#function) at line \(#line) called on secondary thread")
        downloadStartTimeReference = Date.timeIntervalSinceReferenceDate
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    func downloadEnded() {
        assert(Thread.isMainThread, "\(#function) at line \(#line) called on secondary thread")
        let duration = Date.timeIntervalSinceReferenceDate - downloadStartTimeReference!
        downloadDuration += duration
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    func parseEnded() {
        assert(Thread.isMainThread, "\(#function) at line \(#line) called on secondary thread")
        
        if parsedSongs.count > 0 {
            delegate?.parser?(self, didParseSongs: parsedSongs)
        }
        
        parsedSongs.removeAll()
        
        delegate?.parserDidEndParsingData?(self)
        
        let duration = Date.timeIntervalSinceReferenceDate - startTimeReference!
        totalDuration = duration
        
        WriteStatisticToDatabase(type(of: self).parserType, downloadDuration, parseDuration, totalDuration);
    }
    
    func parsedSong(_ song: Song) {
        assert(Thread.isMainThread, "\(#function) at line \(#line) called on secondary thread")
        parsedSongs.append(song)
        if parsedSongs.count > countForNotification {
            delegate?.parser?(self, didParseSongs: parsedSongs)
            parsedSongs.removeAll()
        }
    }
    
    func parseError(_ error: NSError) {
        assert(Thread.isMainThread, "\(#function) at line \(#line) called on secondary thread")
        delegate?.parser?(self, didFailWithError:error)
    }
    
    func addToParseDuration(_ duration: TimeInterval) {
        assert(Thread.isMainThread, "\(#function) at line \(#line) called on secondary thread")
        parseDuration += duration
    }
}
