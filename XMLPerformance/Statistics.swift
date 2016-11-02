//
//  Statistics.swift
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

import Foundation

private var database: COpaquePointer = nil
private var insert_statement: COpaquePointer = nil
private var count_statement: COpaquePointer = nil
private var mean_download_time_statement: COpaquePointer = nil
private var mean_parse_time_statement: COpaquePointer = nil
private var mean_download_and_parse_time_statement: COpaquePointer = nil
private var reset_statement: COpaquePointer = nil

// Returns a reference to the database, creating and opening if necessary.
func Database() -> COpaquePointer {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    if database == nil {
        // First, test for existence.
        let fileManager = NSFileManager.defaultManager()
        let paths = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.DocumentDirectory, NSSearchPathDomainMask.UserDomainMask, true)
        let documentsDirectory = paths[0] as NSString
        let writableDBPath = documentsDirectory.stringByAppendingPathComponent("stats.sqlite")
        if !fileManager.fileExistsAtPath(writableDBPath) {
            let defaultDBPath = NSBundle.mainBundle().pathForResource("stats", ofType:"sqlite")
            do {
                try fileManager.copyItemAtPath(defaultDBPath!, toPath: writableDBPath)
            }
            catch let error as NSError {
                assertionFailure("Failed to create writable database file with message \(error.localizedDescription)")
            }
        }
        
        // Open the database. The database was prepared outside the application.
        if sqlite3_open(writableDBPath, &database) != SQLITE_OK {
            sqlite3_close(database)
            database = nil
            assertionFailure("Failed to open database with message '\(sqlite3_errmsg(database))'.")
            // Additional error handling, as appropriate...
        }
    }
    return database
}


// Close the database. This should be called when the application terminates.
func CloseStatisticsDatabase() {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")

    // Finalize (delete) all of the SQLite compiled queries.
    if insert_statement != nil {
        sqlite3_finalize(insert_statement)
        // reassign the pointer to NULL so that it will be correctly reinitialized if needed later. This pattern repeats for the rest of the statements below.
        insert_statement = nil
    }
    
    if count_statement != nil {
        sqlite3_finalize(count_statement)
        count_statement = nil
    }
    
    if mean_download_time_statement != nil {
        sqlite3_finalize(mean_download_time_statement)
        mean_download_time_statement = nil
    }
    
    if mean_parse_time_statement != nil {
        sqlite3_finalize(mean_parse_time_statement)
        mean_parse_time_statement = nil
    }
    
    if mean_download_and_parse_time_statement != nil {
        sqlite3_finalize(mean_download_and_parse_time_statement)
        mean_download_and_parse_time_statement = nil
    }
    
    if reset_statement != nil {
        sqlite3_finalize(reset_statement)
        reset_statement = nil
    }
    
    if database != nil {
        // Close the database.
        if (sqlite3_close(database) != SQLITE_OK) {
            assertionFailure("Error: failed to close database with message '\(sqlite3_errmsg(database))'.")
        }
        database = nil
    }
}


// Retrieve the number of measurements available for a parser of a given type.
func NumberOfRunsForParserType(parserType: XMLParserType) -> UInt {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    let db = Database()
    if count_statement == nil {
        // Prepare (compile) the SQL statement.
        let sql = "SELECT COUNT(*) FROM statistic WHERE parser_type = ?"
        if sqlite3_prepare_v2(db, sql, -1, &count_statement, nil) != SQLITE_OK {
            assertionFailure("Error: failed to prepare statement with message '\(sqlite3_errmsg(db))'.")
        }
    }
    // Bind the parser type to the statement.
    if (sqlite3_bind_int(count_statement, 1, Int32(parserType.rawValue)) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }

    var numberOfRuns: UInt = 0
    
    // Execute the query.
    let success = sqlite3_step(count_statement)
    if success == SQLITE_ROW {
        // Store the value of the first and only column for return.
        numberOfRuns = UInt(sqlite3_column_int(count_statement, 0))
    } else {
        assertionFailure("Error: failed to execute query with message '\(sqlite3_errmsg(db))'.")
    }
    
    // Reset the query for the next use.
    sqlite3_reset(count_statement)
    return numberOfRuns
}


// Retrieve the average number of seconds from starting the download to finishing the download for a parser of a given type.
func MeanDownloadTimeForParserType(parserType: XMLParserType) -> Double {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    let db = Database()
    if mean_download_time_statement == nil {
        let sql = "SELECT AVG(download_duration) FROM statistic WHERE parser_type = ?"
        if (sqlite3_prepare_v2(db, sql, -1, &mean_download_time_statement, nil) != SQLITE_OK) {
            assertionFailure("Error: failed to prepare statement with message '\(sqlite3_errmsg(db))'.")
        }
    }
    if (sqlite3_bind_int(mean_download_time_statement, 1, Int32(parserType.rawValue)) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    
    let success = sqlite3_step(mean_download_time_statement)
    var meanValue = 0.0
    if (success == SQLITE_ROW) {
        meanValue = Double(sqlite3_column_double(mean_download_time_statement, 0))
    } else {
        assertionFailure("Error: failed to execute query with message '\(sqlite3_errmsg(db))'.")
    }
    
    // Reset the query for the next use.
    sqlite3_reset(mean_download_time_statement)
    return meanValue
}


// Retrieve the average number of seconds from starting the download to finishing the parse for a parser of a given type. This is the total amount of time the parser needs to do all of its work.
func MeanParseTimeForParserType(parserType: XMLParserType) -> Double {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    let db = Database()
    if mean_parse_time_statement == nil {
        let sql = "SELECT AVG(parse_duration) FROM statistic WHERE parser_type = ?"
        if (sqlite3_prepare_v2(db, sql, -1, &mean_parse_time_statement, nil) != SQLITE_OK) {
            assertionFailure("Error: failed to prepare statement with message '\(sqlite3_errmsg(db))'.")
        }
    }
    if (sqlite3_bind_int(mean_parse_time_statement, 1, Int32(parserType.rawValue)) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    
    let success = sqlite3_step(mean_parse_time_statement)
    var meanValue = 0.0
    if (success == SQLITE_ROW) {
        meanValue = sqlite3_column_double(mean_parse_time_statement, 0)
    } else {
        assertionFailure("Error: failed to execute query with message '\(sqlite3_errmsg(db))'.")
    }
    
    // Reset the query for the next use.
    sqlite3_reset(mean_parse_time_statement)
    return meanValue
}


// Retrieve the average number of seconds from starting the download to finishing the parse for a parser of a given type. This is the total amount of time the parser needs to do all of its work.
func MeanTotalTimeForParserType(parserType: XMLParserType) -> Double {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    let db = Database()
    if mean_download_and_parse_time_statement == nil {
        let sql = "SELECT AVG(total_duration) FROM statistic WHERE parser_type = ?"
        if (sqlite3_prepare_v2(db, sql, -1, &mean_download_and_parse_time_statement, nil) != SQLITE_OK) {
            assertionFailure("Error: failed to prepare statement with message '\(sqlite3_errmsg(db))'.")
        }
    }
    if (sqlite3_bind_int(mean_download_and_parse_time_statement, 1, Int32(parserType.rawValue)) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    
    let success = sqlite3_step(mean_download_and_parse_time_statement)
    var meanValue = 0.0
    if (success == SQLITE_ROW) {
        meanValue = sqlite3_column_double(mean_download_and_parse_time_statement, 0)
    } else {
        assertionFailure("Error: failed to execute query with message '\(sqlite3_errmsg(db))'.")
    }
    
    // Reset the query for the next use.
    sqlite3_reset(mean_download_and_parse_time_statement)
    return meanValue
}


// Delete all stored measurements. You may want to do this after running the application using performance tools, which add considerable overhead and will distort the measurements. This is also the case if you were using the debugger, particularly if you were pausing execution.
func ResetStatisticsDatabase() {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    let db = Database()
    if reset_statement == nil {
        let sql = "DELETE FROM statistic"
        if (sqlite3_prepare_v2(db, sql, -1, &reset_statement, nil) != SQLITE_OK) {
            assertionFailure("Error: failed to prepare statement with message '\(sqlite3_errmsg(db))'.")
        }
    }
    
    let success = sqlite3_step(reset_statement)
    if success == SQLITE_ERROR {
        assertionFailure("Error: failed to execute query with message '\(sqlite3_errmsg(db))'.")
    }
    
    // Reset the query for the next use.
    sqlite3_reset(reset_statement)
}


// Store a measurement to the database.
func WriteStatisticToDatabase(parserType: XMLParserType, _ downloadDuration: Double, _ parseDuration: Double, _ totalDuration: Double)  {
    assert(NSThread.isMainThread(), "\(#function) at line \(#line) called on secondary thread")
    let db = Database()
    if insert_statement == nil {
        let sql = "INSERT INTO statistic (parser_type, download_duration, parse_duration, total_duration) VALUES(?, ?, ?, ?)"
        if (sqlite3_prepare_v2(db, sql, -1, &insert_statement, nil) != SQLITE_OK) {
            assertionFailure("Error: failed to prepare statement with message '\(sqlite3_errmsg(db))'.")
        }
    }
    
    if (sqlite3_bind_int(insert_statement, 1, CInt(parserType.rawValue)) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    if (sqlite3_bind_double(insert_statement, 2, downloadDuration) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    if (sqlite3_bind_double(insert_statement, 3, parseDuration) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    if (sqlite3_bind_double(insert_statement, 4, totalDuration) != SQLITE_OK) {
        assertionFailure("Error: failed to bind variable with message '\(sqlite3_errmsg(db))'.")
    }
    
    let success = sqlite3_step(insert_statement)
    if success == SQLITE_ERROR {
        assertionFailure("Error: failed to execute query with message '\(sqlite3_errmsg(db))'.")
    }
    
    // Reset the query for the next use.
    sqlite3_reset(insert_statement)
}
