//
//  LibXMLParser.swift
//  XMLPerformance
//
//  Copyright (c) 2015 FTS InfoTech, LLC.
//
//  Abstract:
//  Subclass of iTunesRSSParser that uses libxml2 for parsing the XML data.
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

class LibXMLParser : iTunesRSSParser {
    
    // Reference to the libxml parser context
    var context: xmlParserCtxtPtr?
    // Overall state of the parser, used to exit the run loop.
    var done = false
    // State variable used to determine whether or not to ignore a given XML element
    var parsingASong = false

    // The following state variables deal with getting character data from XML elements. This is a potentially expensive
    // operation. The character data in a given element may be delivered over the course of multiple callbacks, so that
    // data must be appended to a buffer. The optimal way of doing this is to use a C string buffer that grows exponentially.
    // When all the characters have been delivered, an String is constructed and the buffer is reset.
    var storingCharacters = false
    var characterBuffer = Data()
    // A reference to the current song the parser is working with.
    var currentSong: Song?
    
    var parseFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = DateFormatter.Style.none
        
        // necessary because iTunes RSS feed is not localized, so if the device region has been set to other than US
        // the date formatter must be set to US locale in order to parse the dates
        formatter.locale = Locale(identifier: "US")
        return formatter
    }
    
    fileprivate var currentString : String {
        // Create a string with the character data using UTF-8 encoding. UTF-8 is the default XML data encoding.
        let currentString = String(data: characterBuffer, encoding: String.Encoding.utf8)!
        characterBuffer.count = 0
        return currentString
    }

    override class func parserName() -> String {
        return "libxml2"
    }
    
    override class var parserType: XMLParserType {
        return .libXMLParser
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
                
                let start = Date.timeIntervalSinceReferenceDate
                // Process the downloaded chunk of data.
                xmlData!.withUnsafeBytes { (bytes: UnsafePointer<CChar>) -> Void in
                    xmlParseChunk(self.context, bytes, CInt(xmlData!.count), 0)
                }
                // Signal the context that parsing is complete by passing "1" as the last parameter.
                xmlParseChunk(self.context, nil, 0, 1)
                let duration = Date.timeIntervalSinceReferenceDate - start
                
                DispatchQueue.main.async {
                    self.addToParseDuration(duration)
                    self.parseEnded()
                }
            }
        })
        
        // start loading the data
        downloadStarted()
        
        sessionTask.resume()
    }
    

    /*
    This method is called on a secondary thread by the superclass. We have asynchronous work to do here with downloading and parsing data, so we will need a run loop to prevent the thread from exiting before we are finished.
    */
    override func downloadAndParse(_ url: URL) {
        done = false
        
        URLCache.shared.removeAllCachedResponses()
        
        // This creates a context for "push" parsing in which chunks of data that are not "well balanced" can be passed
        // to the context for streaming parsing. The handler structure defined above will be used for all the parsing.
        // The second argument, self, will be passed as user data to each of the SAX handlers. The last three arguments
        // are left blank to avoid creating a tree in memory.
        // Reference: http://stackoverflow.com/questions/30786883/swift-2-unsafemutablepointervoid-to-object
        context = xmlCreatePushParserCtxt(&simpleSAXHandlerStruct, Unmanaged.passUnretained(self).toOpaque()
            , nil, 0, nil)

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

    /*
    Character data is appended to a buffer until the current element ends.
    */
    func appendCharacters(_ charactersFound: UnsafePointer<xmlChar>, count:Int32) {
        characterBuffer.append(charactersFound, count: Int(count))
    }
    
    func finishedCurrentSong() {
        
        // dispatch_async will not retain the self.currentSong so we add a reference to it with if let
        if let currentSong = self.currentSong {
            DispatchQueue.main.async {
                self.parsedSong(currentSong)
            }
        }
        self.currentSong = nil
    }
    
    // Override to free xmlParserCtxtPtr after parse is complete
    override func parseEnded() {
        if context != nil {
            xmlFreeParserCtxt(context!)
            context = nil
        }
        
        super.parseEnded()
    }
}


// The following constants are the XML element names.
private let itemName = "item"
private let titleName = "title"
private let categoryName = "category"
private let itmsName = "itms"
private let artistName = "artist"
private let albumName = "album"
private let releaseDateName = "releasedate"

/*
This callback is invoked when the parser finds the beginning of a node in the XML. For this application,
out parsing needs are relatively modest - we need only match the node name. An "item" node is a record of
data about a song. In that case we create a new Song object. The other nodes of interest are several of the
child nodes of the Song currently being parsed. For those nodes we want to accumulate the character data
in a buffer. Some of the child nodes use a namespace prefix.
*/
// Reference: http://stackoverflow.com/questions/31311166/swift-unsafemutablepointer-unsafemutablepointerunsafepointersometype
private func startElementSAX(_ ctx: UnsafeMutableRawPointer?, name: UnsafePointer<xmlChar>?, prefix: UnsafePointer<xmlChar>?, URI: UnsafePointer<xmlChar>?, nb_namespaces: CInt, namespaces: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?, nb_attributes: CInt, nb_defaulted: CInt, attributes: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?) {
        
        let parser = Unmanaged<LibXMLParser>.fromOpaque(ctx!).takeUnretainedValue()
    
        // Convert the name param to a Swift String 'localName'
        let localName = String(cString: name!)
    
        if prefix == nil && localName == itemName {
            let newSong = Song()
            parser.currentSong = newSong
            parser.parsingASong = true
        } else if parser.parsingASong {
            if prefix == nil {
                if localName == titleName || localName == categoryName {
                    parser.storingCharacters = true
                }
            } else {
                let localPrefix = String(cString: prefix!)
                if localPrefix == itmsName {
                    if localName == artistName || localName == albumName || localName == releaseDateName {
                        parser.storingCharacters = true
                    }
                }
                
            }
        }
}


/*
This callback is invoked when the parse reaches the end of a node. At that point we finish processing that node,
if it is of interest to us. For "item" nodes, that means we have completed parsing a Song object. We pass the song
to a method in the superclass which will eventually deliver it to the delegate. For the other nodes we
care about, this means we have all the character data. The next step is to create an String using the buffer
contents and store that with the current Song object.
*/
private func endElementSAX(_ ctx: UnsafeMutableRawPointer?,
    name: UnsafePointer<xmlChar>?,
    prefix: UnsafePointer<xmlChar>?,
    URI: UnsafePointer<xmlChar>?) {
        
        let parser = Unmanaged<LibXMLParser>.fromOpaque(ctx!).takeUnretainedValue()
        guard parser.parsingASong else {
            return
        }
        
        let localName = String(cString: name!)

        if prefix == nil {
            if localName == itemName {
                parser.finishedCurrentSong()
                parser.parsingASong = false
            } else if localName == titleName {
                parser.currentSong?.title = parser.currentString
            } else if localName == categoryName {
                parser.currentSong?.category = parser.currentString
            }
        } else {
            let localPrefix = String(cString: prefix!)
            if localPrefix == itmsName {
                if localName == artistName {
                    parser.currentSong?.artist = parser.currentString
                } else if localName == albumName {
                    parser.currentSong?.album = parser.currentString
                } else if localName == releaseDateName {
                    let dateString = parser.currentString
                    parser.currentSong?.releaseDate = parser.parseFormatter.date(from: dateString)
                }
            }
        }
        parser.storingCharacters = false
}


/*
This callback is invoked when the parser encounters character data inside a node. The parser class determines how to use the character data.
*/
private func charactersFoundSAX(_ ctx: UnsafeMutableRawPointer?, ch: UnsafePointer<xmlChar>?, len: CInt) {
    
    // Cast the ctx back to a LibXMLParser
    let parser = Unmanaged<LibXMLParser>.fromOpaque(ctx!).takeUnretainedValue()

    // A state variable, "storingCharacters", is set when nodes of interest begin and end.
    // This determines whether character data is handled or ignored.
    guard parser.storingCharacters else {
        return
    }
    parser.appendCharacters(ch!, count: len)
}


/*
A production application should include robust error handling as part of its parsing implementation.
The specifics of how errors are handled depends on the application.
*/
private func errorEncounteredSAX(_ ctx: UnsafeMutableRawPointer, msg: UnsafePointer<CChar>...) {
    // Handle errors as appropriate for your application.
    assertionFailure("Unhandled error encountered during SAX parse.")
}


// The handler struct has positions for a large number of callback functions. If NULL is supplied at a given position,
// that callback functionality won't be used. Refer to libxml documentation at http://www.xmlsoft.org for more information
// about the SAX callbacks.
var simpleSAXHandlerStruct : xmlSAXHandler = {
    
    // It appears struct is initialized to zeros by default, so no need to set each unused member to nil
    var handler = xmlSAXHandler()

    handler.characters = charactersFoundSAX
    // TBD, TODO - How to deal with variadic parameters in C?
//    handler.error = errorEncounteredSAX
    handler.initialized = XML_SAX2_MAGIC
    handler.startElementNs = startElementSAX
    handler.endElementNs = endElementSAX
    
    return handler
}()


