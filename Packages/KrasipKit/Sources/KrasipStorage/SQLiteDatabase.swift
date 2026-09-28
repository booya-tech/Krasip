// SQLiteDatabase.swift
// KrasipKit
// Small, thread-safe wrapper over the SQLite C API used for all local data.

import Foundation
import SQLite3

public struct SQLiteError: Error, CustomStringConvertible, Sendable {
    public let code: Int32
    public let message: String

    public var description: String { "SQLite error \(code): \(message)" }
}

/// One SQLite connection. Every call is serialized with a lock, so the object can be
/// shared between the main thread and background work.
public final class SQLiteDatabase: @unchecked Sendable {
    public enum Value: Sendable, Equatable {
        case null
        case integer(Int64)
        case real(Double)
        case text(String)
        case blob(Data)
    }

    /// A result row, valid only inside the `query` mapping closure.
    public struct Row {
        fileprivate let statement: OpaquePointer

        public func isNull(_ column: Int32) -> Bool {
            sqlite3_column_type(statement, column) == SQLITE_NULL
        }

        public func string(_ column: Int32) -> String? {
            guard !isNull(column), let text = sqlite3_column_text(statement, column) else { return nil }
            return String(cString: text)
        }

        public func int(_ column: Int32) -> Int? {
            isNull(column) ? nil : Int(sqlite3_column_int64(statement, column))
        }

        public func double(_ column: Int32) -> Double? {
            isNull(column) ? nil : sqlite3_column_double(statement, column)
        }

        public func bool(_ column: Int32) -> Bool {
            sqlite3_column_int64(statement, column) != 0
        }

        public func data(_ column: Int32) -> Data? {
            guard !isNull(column), let bytes = sqlite3_column_blob(statement, column) else { return nil }
            return Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, column)))
        }
    }

    private var handle: OpaquePointer?
    private let lock = NSRecursiveLock()
    public let url: URL?

    public init(url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        self.url = url
        try open(path: url.path)
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
    }

    /// A private database that disappears when released. Used by tests and previews.
    public init(inMemory: Void = ()) throws {
        url = nil
        try open(path: ":memory:")
        try execute("PRAGMA foreign_keys = ON;")
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    private func open(path: String) throws {
        var connection: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let code = sqlite3_open_v2(path, &connection, flags, nil)
        guard code == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "cannot open database"
            sqlite3_close_v2(connection)
            throw SQLiteError(code: code, message: message)
        }
        handle = connection
    }

    public func execute(_ sql: String) throws {
        try locked {
            var errorMessage: UnsafeMutablePointer<CChar>?
            let code = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
            if code != SQLITE_OK {
                let message = errorMessage.map { String(cString: $0) } ?? "unknown error"
                sqlite3_free(errorMessage)
                throw SQLiteError(code: code, message: message)
            }
        }
    }

    public func run(_ sql: String, _ values: [Value] = []) throws {
        _ = try query(sql, values) { _ in () }
    }

    public func query<T>(_ sql: String, _ values: [Value] = [], map: (Row) throws -> T) throws -> [T] {
        try locked {
            let statement = try prepare(sql, values)
            defer { sqlite3_finalize(statement) }
            var results: [T] = []
            var code = sqlite3_step(statement)
            while code == SQLITE_ROW {
                results.append(try map(Row(statement: statement)))
                code = sqlite3_step(statement)
            }
            guard code == SQLITE_DONE else { throw lastError(code) }
            return results
        }
    }

    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try locked {
            try execute("BEGIN IMMEDIATE;")
            do {
                let result = try body()
                try execute("COMMIT;")
                return result
            } catch {
                try? execute("ROLLBACK;")
                throw error
            }
        }
    }

    public var userVersion: Int {
        get throws {
            try query("PRAGMA user_version;") { $0.int(0) ?? 0 }.first ?? 0
        }
    }

    public func setUserVersion(_ version: Int) throws {
        try execute("PRAGMA user_version = \(version);")
    }

    /// Rows changed by the last INSERT, UPDATE, or DELETE.
    public var changes: Int {
        locked { Int(sqlite3_changes(handle)) }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func prepare(_ sql: String, _ values: [Value]) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard code == SQLITE_OK, let statement else { throw lastError(code) }
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .null:
                result = sqlite3_bind_null(statement, index)
            case .integer(let number):
                result = sqlite3_bind_int64(statement, index, number)
            case .real(let number):
                result = sqlite3_bind_double(statement, index, number)
            case .text(let text):
                result = sqlite3_bind_text(statement, index, text, -1, Self.transient)
            case .blob(let data):
                result = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), Self.transient)
                }
            }
            guard result == SQLITE_OK else {
                sqlite3_finalize(statement)
                throw lastError(result)
            }
        }
        return statement
    }

    private func lastError(_ code: Int32) -> SQLiteError {
        SQLiteError(code: code, message: String(cString: sqlite3_errmsg(handle)))
    }

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
}

extension SQLiteDatabase.Value {
    static func optionalText(_ value: String?) -> Self { value.map { .text($0) } ?? .null }
    static func optionalReal(_ value: Double?) -> Self { value.map { .real($0) } ?? .null }
    static func bool(_ value: Bool) -> Self { .integer(value ? 1 : 0) }
    static func date(_ value: Date) -> Self { .real(value.timeIntervalSince1970) }
    static func uuid(_ value: UUID) -> Self { .text(value.uuidString) }
}
