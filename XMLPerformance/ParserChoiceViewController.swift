//
//  ParserChoiceViewController.swift
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

class ParserChoiceViewController: UITableViewController {
    
    var parserSelection: NSIndexPath = NSIndexPath(forRow: 0, inSection: 0)

    // When the parsing is finished, the user can return to the ParserChoiceViewController by
    // touching the Done button which will trigger the exit segue associated with this action.
    @IBAction func doneWithSongs(segue: UIStoryboardSegue) {
        
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowSongs" {
            let navController = segue.destinationViewController as! UINavigationController
            let songsViewController = navController.topViewController as! SongsViewController
            songsViewController.parserType = XMLParserType(rawValue: self.parserSelection.row)
        }
    }

    // MARK: - Table View
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath) 
        
        switch indexPath.row {
        case 0:
            cell.textLabel!.text = CocoaXMLParser.parserName()
        case 1:
            cell.textLabel!.text = LibXMLParser.parserName()
        default:
            break
        }
        
        cell.accessoryType = indexPath.isEqual(parserSelection) ? UITableViewCellAccessoryType.Checkmark : UITableViewCellAccessoryType.None
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        self.parserSelection = indexPath;
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        tableView.reloadData()
    }
    
}
