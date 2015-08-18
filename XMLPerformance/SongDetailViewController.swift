//
//  SongDetailViewController.swift
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

class SongDetailViewController: UITableViewController {
    
    var song: Song? {
        didSet {
            // When the song changes, update the navigation item title
            title = song?.title
        }
    }
    
    
    var dateFormatter: NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .NoStyle
        return formatter
    }
    
    
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 4
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SongDetailCell", forIndexPath: indexPath)
        switch indexPath.row {
        case 0:
            cell.textLabel!.text = NSLocalizedString("album", comment: "album label")
            cell.detailTextLabel!.text = song?.album
        case 1:
            cell.textLabel!.text = NSLocalizedString("artist", comment: "artist label")
            cell.detailTextLabel!.text = song?.artist
        case 2:
            cell.textLabel!.text = NSLocalizedString("category", comment: "category label")
            cell.detailTextLabel!.text = song?.category
        case 3:
            cell.textLabel!.text = NSLocalizedString("released", comment: "released label")
            cell.detailTextLabel!.text = ""
            if let date = song?.releaseDate {
                cell.detailTextLabel!.text = dateFormatter.stringFromDate(date)
            }
        default:
            break
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return NSLocalizedString("Song details:", comment: "Song details label")
    }
}
