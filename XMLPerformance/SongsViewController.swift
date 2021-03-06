//
//  SongsViewController.swift
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

class SongsViewController: UITableViewController, iTunesRSSParserDelegate {

    var songs = [Song]()
    
    fileprivate var parser: iTunesRSSParser?
    
    var parserType: XMLParserType? {
        didSet {
            self.title = NSLocalizedString("Getting Top Songs...", comment: "Waiting for first results label")
            
            if let parserType = self.parserType {
                switch parserType {
                case .xmlParser:
                    parser = CocoaXMLParser()
                case .libXMLParser:
                    parser = LibXMLParser()
                default:
                    break
                }
                
                parser?.delegate = self
                parser?.start()
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let selectedIndexPath = tableView.indexPathForSelectedRow
        if let indexPath = selectedIndexPath {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowSongDetail" {
            let songDetailViewController = segue.destination as! SongDetailViewController
            if let indexPath = tableView.indexPathForSelectedRow {
                songDetailViewController.song = songs[indexPath.row]
            }
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath as IndexPath) 
        
        let song = songs[indexPath.row]
        cell.textLabel!.text = song.title
        return cell
    }
    
    func parserDidEndParsingData(_ parser: iTunesRSSParser) {
        title = String(format: NSLocalizedString("Top %d Songs", comment: "Top Songs format"), songs.count)
        tableView.reloadData()
        navigationItem.rightBarButtonItem?.isEnabled = true
        self.parser = nil
    }
    
    func parser(_ parser: iTunesRSSParser, didParseSongs parsedSongs: [AnyObject]!) {
        songs += parsedSongs as! [Song]
        
        // Three scroll view properties are checked to keep the user interface smooth during parse. When new objects are delivered by the parser, the table view is reloaded to display them. If the table is reloaded while the user is scrolling, this can result in eratic behavior. dragging, tracking, and decelerating can be checked for this purpose. When the parser finishes, reloadData will be called in parserDidEndParsingData:, guaranteeing that all data will ultimately be displayed even if reloadData is not called in this method because of user interaction.
        if !tableView.isDragging && !tableView.isTracking && !tableView.isDecelerating {
            title = String(format: NSLocalizedString("Top %d Songs", comment: "Top Songs format"), songs.count)
            tableView.reloadData()
        }
    }
    
    func parser(_ parser: iTunesRSSParser, didFailWithError: NSError) {
        // handle errors as appropriate to your application...
    }    
}
