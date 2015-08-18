//
//  StatsViewController.swift
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

class StatsViewController: UITableViewController {
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        tableView.reloadData()
    }

    @IBAction func resetStatistics(sender: AnyObject) {
        ResetStatisticsDatabase()
        tableView.reloadData()
    }
    
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("StatsCell", forIndexPath: indexPath)

        switch (indexPath.row) {
        case 0:
            cell.textLabel!.text = NSLocalizedString("Mean Download Time", comment: "Mean Download Time format")
            cell.detailTextLabel!.text = String.localizedStringWithFormat("%.4fs", MeanDownloadTimeForParserType(XMLParserType(rawValue: indexPath.section)!))
        case 1:
            cell.textLabel!.text = NSLocalizedString("Mean Parse Time", comment: "Mean Parse Time format")
            cell.detailTextLabel!.text = String.localizedStringWithFormat("%.4fs", MeanParseTimeForParserType(XMLParserType(rawValue: indexPath.section)!))
        case 2:
            cell.textLabel!.text = NSLocalizedString("Mean Total Time", comment: "Mean Total Time format")
            cell.detailTextLabel!.text = String.localizedStringWithFormat("%.4fs", MeanTotalTimeForParserType(XMLParserType(rawValue: indexPath.section)!))
        default:
            break;
        }
        return cell
    }
    
    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let numberOfRuns = NumberOfRunsForParserType(XMLParserType(rawValue: section)!)
        let parserName = (section == 0) ? CocoaXMLParser.parserName : LibXMLParser.parserName
        var title = ""
        if numberOfRuns == 1 {
            title = String(format: NSLocalizedString("%@ (%d run):", comment: "One Run format"), parserName(), numberOfRuns)
        } else {
            title = String(format: NSLocalizedString("%@ (%d runs):", comment: "Multiple Runs format"), parserName(), numberOfRuns)
        }
        return title
    }

}
