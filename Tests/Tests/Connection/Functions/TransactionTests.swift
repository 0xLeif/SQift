//
//  TransactionTests.swift
//
//  Copyright (c) 2015-present Nike, Inc. (https://www.nike.com)
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
//

import Foundation
import SQift
import XCTest

class TransactionTestCase: BaseConnectionTestCase {
    func testThatConnectionCanExecuteTransaction() {
        do {
            // Given
            try connection.execute("CREATE TABLE cars(id INTEGER PRIMARY KEY, name TEXT, price INTEGER)")

            // When
            try connection.transaction {
                try connection.prepare("INSERT INTO cars VALUES(?, ?, ?)").bind(1, "Audi", 52642).run()
                try connection.prepare("INSERT INTO cars VALUES(?, ?, ?)").bind(2, "Mercedes", 57127).run()
            }

            let rows: [[Any?]] = try connection.query("SELECT * FROM cars") { $0.values }

            // Then
            if rows.count == 2 {
                XCTAssertEqual(rows[0][0] as? Int64, 1, "rows[0][0] should be 1")
                XCTAssertEqual(rows[0][1] as? String, "Audi", "rows[0][1] should be `Audi`")
                XCTAssertEqual(rows[0][2] as? Int64, 52642, "rows[0][2] should be 52642")

                XCTAssertEqual(rows[1][0] as? Int64, 2, "rows[1][0] should be 2")
                XCTAssertEqual(rows[1][1] as? String, "Mercedes", "rows[1][1] should be `Mercedes`")
                XCTAssertEqual(rows[1][2] as? Int64, 57127, "rows[1][2] should be 57127")
            } else {
                XCTFail("rows count should be 2")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanRollbackTransactionExecutionWhenTransactionThrows() {
        do {
            // Given
            try connection.execute("CREATE TABLE cars(id INTEGER PRIMARY KEY, name TEXT, price INTEGER)")

            // When
            do {
                try connection.transaction {
                    try connection.prepare("INSERT INTO cars VALUES(?, ?, ?)").bind(1, "Audi", 52642).run()
                    try connection.prepare("INSERT IN cars VALUES(?, ?, ?)").bind(2, "Mercedes", 57127).run()
                }
            } catch {
                // No-op: this is expected due to invalid SQL in second prepare statement
            }

            let count: Int? = try connection.query("SELECT count(*) FROM cars")

            // Then
            XCTAssertEqual(count, 0)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    // MARK: - Tests - Savepoints

    func testThatConnectionCanExecuteSavepoint() {
        do {
            // Given
            try connection.execute("CREATE TABLE cars(id INTEGER PRIMARY KEY, name TEXT, price INTEGER)")

            // When
            try connection.savepoint(named: "'savepoint-1'") {
                try connection.prepare("INSERT INTO cars VALUES(?, ?, ?)").bind(1, "Audi", 52642).run()

                try connection.savepoint(named: "'savepoint    2") {
                    try connection.prepare("INSERT INTO cars VALUES(?, ?, ?)").bind(2, "Mercedes", 57127).run()
                }
            }

            // When
            let rows: [[Any?]] = try connection.query("SELECT * FROM cars") { $0.values }

            // Then
            if rows.count == 2 {
                XCTAssertEqual(rows[0][0] as? Int64, 1, "rows[0][0] should be 1")
                XCTAssertEqual(rows[0][1] as? String, "Audi", "rows[0][1] should be `Audi`")
                XCTAssertEqual(rows[0][2] as? Int64, 52642, "rows[0][2] should be 52642")

                XCTAssertEqual(rows[1][0] as? Int64, 2, "rows[1][0] should be 2")
                XCTAssertEqual(rows[1][1] as? String, "Mercedes", "rows[1][1] should be `Mercedes`")
                XCTAssertEqual(rows[1][2] as? Int64, 57127, "rows[1][2] should be 57127")
            } else {
                XCTFail("rows count should be 2")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanRollbackToSavepointWhenSavepointExecutionThrows() {
        do {
            // Given
            try connection.execute("CREATE TABLE cars(id INTEGER PRIMARY KEY, name TEXT, price INTEGER)")

            // When
            do {
                try connection.savepoint(named: "save-it-up") {
                    try connection.prepare("INSERT INTO cars VALUES(?, ?, ?)").bind(1, "Audi", 52642).run()
                    try connection.prepare("INSERT IN cars VALUES(?, ?, ?)").bind(2, "Mercedes", 57127).run()
                }
            } catch {
                // No-op: this is expected due to invalid SQL in second prepare statement
            }

            let count: Int? = try connection.query("SELECT count(*) FROM cars")

            // Then
            XCTAssertEqual(count, 0)
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }

    func testThatConnectionCanExecuteSavepointsWithCrazyCharactersInName() {
        do {
            // Given
            try connection.execute("CREATE TABLE cars(id INTEGER PRIMARY KEY, name TEXT, price INTEGER)")

            // When
            try connection.savepoint(named: "savè mę 😱 \n\r\n nõw \n plèãśę  ") {
                try connection.run("INSERT INTO cars VALUES(?, ?, ?)", 1, "Audi", 52642)

                try connection.savepoint(named: "  save with' random \" chàracters") {
                    try connection.run("INSERT INTO cars VALUES(?, ?, ?)", 2, "Mercedes", 57127)
                }
            }

            // When
            let rows: [[Any?]] = try connection.query("SELECT * FROM cars") { $0.values }

            // Then
            if rows.count == 2 {
                XCTAssertEqual(rows[0][0] as? Int64, 1, "rows[0][0] should be 1")
                XCTAssertEqual(rows[0][1] as? String, "Audi", "rows[0][1] should be `Audi`")
                XCTAssertEqual(rows[0][2] as? Int64, 52642, "rows[0][2] should be 52642")

                XCTAssertEqual(rows[1][0] as? Int64, 2, "rows[1][0] should be 2")
                XCTAssertEqual(rows[1][1] as? String, "Mercedes", "rows[1][1] should be `Mercedes`")
                XCTAssertEqual(rows[1][2] as? Int64, 57127, "rows[1][2] should be 57127")
            } else {
                XCTFail("rows count should be 2")
            }
        } catch {
            XCTFail("Test encountered unexpected error: \(error)")
        }
    }
}
