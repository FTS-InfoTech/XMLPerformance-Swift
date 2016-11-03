//
//  CocoaXMLParser.swift
//  XMLPerformance
//
//  Copyright (c) 2015 FTS InfoTech, LLC.
//
//  Abstract:
//  Subclass of iTunesRSSParser that uses the Foundation framework's XMLParser (formerly NSXMLParser) for parsing the XML data.
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

import Foundation
import UIKit

class CocoaXMLParser: iTunesRSSParser, XMLParserDelegate {
    // A string containing the contents of the current song data to be parsed.
    var currentString: String?
    // A reference to the current song the parser is working with.
    var currentSong: Song?
    // The following state variable deals with getting character data from XML elements.
    var storingCharacters = false
    var parseFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = DateFormatter.Style.none
        
        // necessary because iTunes RSS feed is not localized, so if the device region has been set to other than US
        // the date formatter must be set to US locale in order to parse the dates
        formatter.locale = Locale(identifier: "US")
        return formatter
    }
    
    // Overall state of the parser, used to exit the run loop.
    var done = false
    
    
    override class func parserName() -> String {
        return "XMLParser"
    }
    
    override class var parserType: XMLParserType {
        return .xmlParser
    }
    
    func startDownload(_ url: URL) {

        // create a session data task to obtain and the XML feed
        let sessionTask = URLSession.shared.dataTask(with: url, completionHandler: { (xmlData: Data?, response: URLResponse?, error: Error?)  in
            self.done = true
            if error != nil {
                OperationQueue.main.addOperation {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    if let sessionError = error as? NSError {
                        if sessionError.code == NSURLErrorAppTransportSecurityRequiresSecureConnection {
                            // if you get error NSURLErrorAppTransportSecurityRequiresSecureConnection (-1022),
                            // then your Info.plist has not been properly configured to match the target server.
                            //
                            abort()
                            
                        } else {
                            print("An error occurred in '\((#function))': error[\(sessionError.code)] \(error?.localizedDescription)")
                        }
                        
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.downloadEnded()
                }
                
                // continue our work by pasing the resulting data
                let parser = XMLParser(data: xmlData!)
                parser.delegate = self

                self.currentString = ""
                
                let start = Date.timeIntervalSinceReferenceDate
                parser.parse()
                let duration = Date.timeIntervalSinceReferenceDate - start
                
                DispatchQueue.main.async {
                    self.addToParseDuration(duration)
                    self.parseEnded()
                }
                
                self.currentString = nil
            }
        })
        
        // start loading the data
        downloadStarted()
        
        sessionTask.resume()
    }
    
    override func downloadAndParse(_ url: URL) {
        done = false
        
        URLCache.shared.removeAllCachedResponses()
        
        // call startDownload, which starts downloading the songs
        DispatchQueue.main.async {
            self .startDownload(url)
        }
        
        // this loop runs until all the data is downloaded
        // done is set to YES in the completion block once the downloading is finished
        repeat {
            RunLoop.current.run(mode: RunLoopMode.defaultRunLoopMode, before: Date.distantFuture )
        } while !done
    }
    

    // :MARK - Parsing support methods
    
    func finishedCurrentSong() {
        // dispatch_async will not retain the self.currentSong so we add a reference to it with if let
        if let currentSong = self.currentSong {
            DispatchQueue.main.async {
                self.parsedSong(currentSong)
            }
        }
        self.currentSong = nil
    }
    
    
    // :MARK - XMLParser Parsing Callbacks

    // Constants for the XML element names that will be considered during the parse.
    // Declaring these as static constants reduces the number of objects created during the run
    // and is less prone to programmer error.
    //
    fileprivate let itemName = "item"
    fileprivate let titleName = "title"
    fileprivate let categoryName = "category"
    fileprivate let artistName = "itms:artist"
    fileprivate let albumName = "itms:album"
    fileprivate let releaseDateName = "itms:releasedate"

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == itemName {
            currentSong = Song()
        } else if elementName == titleName || elementName == categoryName || elementName == artistName || elementName == albumName || elementName == releaseDateName {
            currentString = ""
            storingCharacters = true
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == itemName {
            finishedCurrentSong()
        } else if elementName == titleName {
            currentSong?.title = currentString
        } else if elementName == categoryName {
            currentSong?.category = currentString
        } else if elementName == artistName {
            currentSong?.artist = currentString
        } else if elementName == albumName {
            currentSong?.album = currentString
        } else if elementName == releaseDateName {
            currentSong?.releaseDate = parseFormatter.date(from: currentString!)
        }
        storingCharacters = false
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if storingCharacters {
            currentString = currentString! + string
        }
    }
    
    /*
    A production application should include robust error handling as part of its parsing implementation.
    The specifics of how errors are handled depends on the application.
    */
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Handle errors as appropriate for your application.
    }
    
}

