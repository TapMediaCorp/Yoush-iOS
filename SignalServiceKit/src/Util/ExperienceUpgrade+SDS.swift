//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

import Foundation
import GRDB
import SignalCoreKit

// NOTE: This file is generated by /Scripts/sds_codegen/sds_generate.py.
// Do not manually edit it, instead run `sds_codegen.sh`.

// MARK: - Record

public struct ExperienceUpgradeRecord: SDSRecord {
    public weak var delegate: SDSRecordDelegate?

    public var tableMetadata: SDSTableMetadata {
        return ExperienceUpgradeSerializer.table
    }

    public static let databaseTableName: String = ExperienceUpgradeSerializer.table.tableName

    public var id: Int64?

    // This defines all of the columns used in the table
    // where this model (and any subclasses) are persisted.
    public let recordType: SDSRecordType
    public let uniqueId: String

    // Properties
    public let firstViewedTimestamp: Double
    public let lastSnoozedTimestamp: Double
    public let isComplete: Bool

    public enum CodingKeys: String, CodingKey, ColumnExpression, CaseIterable {
        case id
        case recordType
        case uniqueId
        case firstViewedTimestamp
        case lastSnoozedTimestamp
        case isComplete
    }

    public static func columnName(_ column: ExperienceUpgradeRecord.CodingKeys, fullyQualified: Bool = false) -> String {
        return fullyQualified ? "\(databaseTableName).\(column.rawValue)" : column.rawValue
    }

    public func didInsert(with rowID: Int64, for column: String?) {
        guard let delegate = delegate else {
            owsFailDebug("Missing delegate.")
            return
        }
        delegate.updateRowId(rowID)
    }
}

// MARK: - Row Initializer

public extension ExperienceUpgradeRecord {
    static var databaseSelection: [SQLSelectable] {
        return CodingKeys.allCases
    }

    init(row: Row) {
        id = row[0]
        recordType = row[1]
        uniqueId = row[2]
        firstViewedTimestamp = row[3]
        lastSnoozedTimestamp = row[4]
        isComplete = row[5]
    }
}

// MARK: - StringInterpolation

public extension String.StringInterpolation {
    mutating func appendInterpolation(experienceUpgradeColumn column: ExperienceUpgradeRecord.CodingKeys) {
        appendLiteral(ExperienceUpgradeRecord.columnName(column))
    }
    mutating func appendInterpolation(experienceUpgradeColumnFullyQualified column: ExperienceUpgradeRecord.CodingKeys) {
        appendLiteral(ExperienceUpgradeRecord.columnName(column, fullyQualified: true))
    }
}

// MARK: - Deserialization

// TODO: Rework metadata to not include, for example, columns, column indices.
extension ExperienceUpgrade {
    // This method defines how to deserialize a model, given a
    // database row.  The recordType column is used to determine
    // the corresponding model class.
    class func fromRecord(_ record: ExperienceUpgradeRecord) throws -> ExperienceUpgrade {

        guard let recordId = record.id else {
            throw SDSError.invalidValue
        }

        switch record.recordType {
        case .experienceUpgrade:

            let uniqueId: String = record.uniqueId
            let firstViewedTimestamp: Double = record.firstViewedTimestamp
            let isComplete: Bool = record.isComplete
            let lastSnoozedTimestamp: Double = record.lastSnoozedTimestamp

            return ExperienceUpgrade(grdbId: recordId,
                                     uniqueId: uniqueId,
                                     firstViewedTimestamp: firstViewedTimestamp,
                                     isComplete: isComplete,
                                     lastSnoozedTimestamp: lastSnoozedTimestamp)

        default:
            owsFailDebug("Unexpected record type: \(record.recordType)")
            throw SDSError.invalidValue
        }
    }
}

// MARK: - SDSModel

extension ExperienceUpgrade: SDSModel {
    public var serializer: SDSSerializer {
        // Any subclass can be cast to it's superclass,
        // so the order of this switch statement matters.
        // We need to do a "depth first" search by type.
        switch self {
        default:
            return ExperienceUpgradeSerializer(model: self)
        }
    }

    public func asRecord() throws -> SDSRecord {
        return try serializer.asRecord()
    }

    public var sdsTableName: String {
        return ExperienceUpgradeRecord.databaseTableName
    }

    public static var table: SDSTableMetadata {
        return ExperienceUpgradeSerializer.table
    }
}

// MARK: - DeepCopyable

extension ExperienceUpgrade: DeepCopyable {

    public func deepCopy() throws -> AnyObject {
        // Any subclass can be cast to it's superclass,
        // so the order of this switch statement matters.
        // We need to do a "depth first" search by type.
        guard let id = self.grdbId?.int64Value else {
            throw OWSAssertionError("Model missing grdbId.")
        }

        do {
            let modelToCopy = self
            assert(type(of: modelToCopy) == ExperienceUpgrade.self)
            let uniqueId: String = modelToCopy.uniqueId
            let firstViewedTimestamp: Double = modelToCopy.firstViewedTimestamp
            let isComplete: Bool = modelToCopy.isComplete
            let lastSnoozedTimestamp: Double = modelToCopy.lastSnoozedTimestamp

            return ExperienceUpgrade(grdbId: id,
                                     uniqueId: uniqueId,
                                     firstViewedTimestamp: firstViewedTimestamp,
                                     isComplete: isComplete,
                                     lastSnoozedTimestamp: lastSnoozedTimestamp)
        }

    }
}

// MARK: - Table Metadata

extension ExperienceUpgradeSerializer {

    // This defines all of the columns used in the table
    // where this model (and any subclasses) are persisted.
    static let idColumn = SDSColumnMetadata(columnName: "id", columnType: .primaryKey)
    static let recordTypeColumn = SDSColumnMetadata(columnName: "recordType", columnType: .int64)
    static let uniqueIdColumn = SDSColumnMetadata(columnName: "uniqueId", columnType: .unicodeString, isUnique: true)
    // Properties
    static let firstViewedTimestampColumn = SDSColumnMetadata(columnName: "firstViewedTimestamp", columnType: .double)
    static let lastSnoozedTimestampColumn = SDSColumnMetadata(columnName: "lastSnoozedTimestamp", columnType: .double)
    static let isCompleteColumn = SDSColumnMetadata(columnName: "isComplete", columnType: .int)

    // TODO: We should decide on a naming convention for
    //       tables that store models.
    public static let table = SDSTableMetadata(collection: ExperienceUpgrade.collection(),
                                               tableName: "model_ExperienceUpgrade",
                                               columns: [
        idColumn,
        recordTypeColumn,
        uniqueIdColumn,
        firstViewedTimestampColumn,
        lastSnoozedTimestampColumn,
        isCompleteColumn,
        ])
}

// MARK: - Save/Remove/Update

@objc
public extension ExperienceUpgrade {
    func anyInsert(transaction: SDSAnyWriteTransaction) {
        sdsSave(saveMode: .insert, transaction: transaction)
    }

    // Avoid this method whenever feasible.
    //
    // If the record has previously been saved, this method does an overwriting
    // update of the corresponding row, otherwise if it's a new record, this
    // method inserts a new row.
    //
    // For performance, when possible, you should explicitly specify whether
    // you are inserting or updating rather than calling this method.
    func anyUpsert(transaction: SDSAnyWriteTransaction) {
        let isInserting: Bool
        if ExperienceUpgrade.anyFetch(uniqueId: uniqueId, transaction: transaction) != nil {
            isInserting = false
        } else {
            isInserting = true
        }
        sdsSave(saveMode: isInserting ? .insert : .update, transaction: transaction)
    }

    // This method is used by "updateWith..." methods.
    //
    // This model may be updated from many threads. We don't want to save
    // our local copy (this instance) since it may be out of date.  We also
    // want to avoid re-saving a model that has been deleted.  Therefore, we
    // use "updateWith..." methods to:
    //
    // a) Update a property of this instance.
    // b) If a copy of this model exists in the database, load an up-to-date copy,
    //    and update and save that copy.
    // b) If a copy of this model _DOES NOT_ exist in the database, do _NOT_ save
    //    this local instance.
    //
    // After "updateWith...":
    //
    // a) Any copy of this model in the database will have been updated.
    // b) The local property on this instance will always have been updated.
    // c) Other properties on this instance may be out of date.
    //
    // All mutable properties of this class have been made read-only to
    // prevent accidentally modifying them directly.
    //
    // This isn't a perfect arrangement, but in practice this will prevent
    // data loss and will resolve all known issues.
    func anyUpdate(transaction: SDSAnyWriteTransaction, block: (ExperienceUpgrade) -> Void) {

        block(self)

        guard let dbCopy = type(of: self).anyFetch(uniqueId: uniqueId,
                                                   transaction: transaction) else {
            return
        }

        // Don't apply the block twice to the same instance.
        // It's at least unnecessary and actually wrong for some blocks.
        // e.g. `block: { $0 in $0.someField++ }`
        if dbCopy !== self {
            block(dbCopy)
        }

        dbCopy.sdsSave(saveMode: .update, transaction: transaction)
    }

    // This method is an alternative to `anyUpdate(transaction:block:)` methods.
    //
    // We should generally use `anyUpdate` to ensure we're not unintentionally
    // clobbering other columns in the database when another concurrent update
    // has occured.
    //
    // There are cases when this doesn't make sense, e.g. when  we know we've
    // just loaded the model in the same transaction. In those cases it is
    // safe and faster to do a "overwriting" update
    func anyOverwritingUpdate(transaction: SDSAnyWriteTransaction) {
        sdsSave(saveMode: .update, transaction: transaction)
    }

    func anyRemove(transaction: SDSAnyWriteTransaction) {
        sdsRemove(transaction: transaction)
    }

    func anyReload(transaction: SDSAnyReadTransaction) {
        anyReload(transaction: transaction, ignoreMissing: false)
    }

    func anyReload(transaction: SDSAnyReadTransaction, ignoreMissing: Bool) {
        guard let latestVersion = type(of: self).anyFetch(uniqueId: uniqueId, transaction: transaction) else {
            if !ignoreMissing {
                owsFailDebug("`latest` was unexpectedly nil")
            }
            return
        }

        setValuesForKeys(latestVersion.dictionaryValue)
    }
}

// MARK: - ExperienceUpgradeCursor

@objc
public class ExperienceUpgradeCursor: NSObject {
    private let transaction: GRDBReadTransaction
    private let cursor: RecordCursor<ExperienceUpgradeRecord>?

    init(transaction: GRDBReadTransaction, cursor: RecordCursor<ExperienceUpgradeRecord>?) {
        self.transaction = transaction
        self.cursor = cursor
    }

    public func next() throws -> ExperienceUpgrade? {
        guard let cursor = cursor else {
            return nil
        }
        guard let record = try cursor.next() else {
            return nil
        }
        return try ExperienceUpgrade.fromRecord(record)
    }

    public func all() throws -> [ExperienceUpgrade] {
        var result = [ExperienceUpgrade]()
        while true {
            guard let model = try next() else {
                break
            }
            result.append(model)
        }
        return result
    }
}

// MARK: - Obj-C Fetch

// TODO: We may eventually want to define some combination of:
//
// * fetchCursor, fetchOne, fetchAll, etc. (ala GRDB)
// * Optional "where clause" parameters for filtering.
// * Async flavors with completions.
//
// TODO: I've defined flavors that take a read transaction.
//       Or we might take a "connection" if we end up having that class.
@objc
public extension ExperienceUpgrade {
    class func grdbFetchCursor(transaction: GRDBReadTransaction) -> ExperienceUpgradeCursor {
        let database = transaction.database
        do {
            let cursor = try ExperienceUpgradeRecord.fetchCursor(database)
            return ExperienceUpgradeCursor(transaction: transaction, cursor: cursor)
        } catch {
            owsFailDebug("Read failed: \(error)")
            return ExperienceUpgradeCursor(transaction: transaction, cursor: nil)
        }
    }

    // Fetches a single model by "unique id".
    class func anyFetch(uniqueId: String,
                        transaction: SDSAnyReadTransaction) -> ExperienceUpgrade? {
        assert(uniqueId.count > 0)

        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            return ExperienceUpgrade.ydb_fetch(uniqueId: uniqueId, transaction: ydbTransaction)
        case .grdbRead(let grdbTransaction):
            let sql = "SELECT * FROM \(ExperienceUpgradeRecord.databaseTableName) WHERE \(experienceUpgradeColumn: .uniqueId) = ?"
            return grdbFetchOne(sql: sql, arguments: [uniqueId], transaction: grdbTransaction)
        }
    }

    // Traverses all records.
    // Records are not visited in any particular order.
    class func anyEnumerate(transaction: SDSAnyReadTransaction,
                            block: @escaping (ExperienceUpgrade, UnsafeMutablePointer<ObjCBool>) -> Void) {
        anyEnumerate(transaction: transaction, batched: false, block: block)
    }

    // Traverses all records.
    // Records are not visited in any particular order.
    class func anyEnumerate(transaction: SDSAnyReadTransaction,
                            batched: Bool = false,
                            block: @escaping (ExperienceUpgrade, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let batchSize = batched ? Batching.kDefaultBatchSize : 0
        anyEnumerate(transaction: transaction, batchSize: batchSize, block: block)
    }

    // Traverses all records.
    // Records are not visited in any particular order.
    //
    // If batchSize > 0, the enumeration is performed in autoreleased batches.
    class func anyEnumerate(transaction: SDSAnyReadTransaction,
                            batchSize: UInt,
                            block: @escaping (ExperienceUpgrade, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            ExperienceUpgrade.ydb_enumerateCollectionObjects(with: ydbTransaction) { (object, stop) in
                guard let value = object as? ExperienceUpgrade else {
                    owsFailDebug("unexpected object: \(type(of: object))")
                    return
                }
                block(value, stop)
            }
        case .grdbRead(let grdbTransaction):
            do {
                let cursor = ExperienceUpgrade.grdbFetchCursor(transaction: grdbTransaction)
                try Batching.loop(batchSize: batchSize,
                                  loopBlock: { stop in
                                      guard let value = try cursor.next() else {
                                        stop.pointee = true
                                        return
                                      }
                                      block(value, stop)
                })
            } catch let error {
                owsFailDebug("Couldn't fetch models: \(error)")
            }
        }
    }

    // Traverses all records' unique ids.
    // Records are not visited in any particular order.
    class func anyEnumerateUniqueIds(transaction: SDSAnyReadTransaction,
                                     block: @escaping (String, UnsafeMutablePointer<ObjCBool>) -> Void) {
        anyEnumerateUniqueIds(transaction: transaction, batched: false, block: block)
    }

    // Traverses all records' unique ids.
    // Records are not visited in any particular order.
    class func anyEnumerateUniqueIds(transaction: SDSAnyReadTransaction,
                                     batched: Bool = false,
                                     block: @escaping (String, UnsafeMutablePointer<ObjCBool>) -> Void) {
        let batchSize = batched ? Batching.kDefaultBatchSize : 0
        anyEnumerateUniqueIds(transaction: transaction, batchSize: batchSize, block: block)
    }

    // Traverses all records' unique ids.
    // Records are not visited in any particular order.
    //
    // If batchSize > 0, the enumeration is performed in autoreleased batches.
    class func anyEnumerateUniqueIds(transaction: SDSAnyReadTransaction,
                                     batchSize: UInt,
                                     block: @escaping (String, UnsafeMutablePointer<ObjCBool>) -> Void) {
        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            ydbTransaction.enumerateKeys(inCollection: ExperienceUpgrade.collection()) { (uniqueId, stop) in
                block(uniqueId, stop)
            }
        case .grdbRead(let grdbTransaction):
            grdbEnumerateUniqueIds(transaction: grdbTransaction,
                                   sql: """
                    SELECT \(experienceUpgradeColumn: .uniqueId)
                    FROM \(ExperienceUpgradeRecord.databaseTableName)
                """,
                batchSize: batchSize,
                block: block)
        }
    }

    // Does not order the results.
    class func anyFetchAll(transaction: SDSAnyReadTransaction) -> [ExperienceUpgrade] {
        var result = [ExperienceUpgrade]()
        anyEnumerate(transaction: transaction) { (model, _) in
            result.append(model)
        }
        return result
    }

    // Does not order the results.
    class func anyAllUniqueIds(transaction: SDSAnyReadTransaction) -> [String] {
        var result = [String]()
        anyEnumerateUniqueIds(transaction: transaction) { (uniqueId, _) in
            result.append(uniqueId)
        }
        return result
    }

    class func anyCount(transaction: SDSAnyReadTransaction) -> UInt {
        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            return ydbTransaction.numberOfKeys(inCollection: ExperienceUpgrade.collection())
        case .grdbRead(let grdbTransaction):
            return ExperienceUpgradeRecord.ows_fetchCount(grdbTransaction.database)
        }
    }

    // WARNING: Do not use this method for any models which do cleanup
    //          in their anyWillRemove(), anyDidRemove() methods.
    class func anyRemoveAllWithoutInstantation(transaction: SDSAnyWriteTransaction) {
        switch transaction.writeTransaction {
        case .yapWrite(let ydbTransaction):
            ydbTransaction.removeAllObjects(inCollection: ExperienceUpgrade.collection())
        case .grdbWrite(let grdbTransaction):
            do {
                try ExperienceUpgradeRecord.deleteAll(grdbTransaction.database)
            } catch {
                owsFailDebug("deleteAll() failed: \(error)")
            }
        }

        if shouldBeIndexedForFTS {
            FullTextSearchFinder.allModelsWereRemoved(collection: collection(), transaction: transaction)
        }
    }

    class func anyRemoveAllWithInstantation(transaction: SDSAnyWriteTransaction) {
        // To avoid mutationDuringEnumerationException, we need
        // to remove the instances outside the enumeration.
        let uniqueIds = anyAllUniqueIds(transaction: transaction)

        var index: Int = 0
        do {
            try Batching.loop(batchSize: Batching.kDefaultBatchSize,
                              loopBlock: { stop in
                                  guard index < uniqueIds.count else {
                                    stop.pointee = true
                                    return
                                  }
                                  let uniqueId = uniqueIds[index]
                                  index = index + 1
                                  guard let instance = anyFetch(uniqueId: uniqueId, transaction: transaction) else {
                                      owsFailDebug("Missing instance.")
                                      return
                                  }
                                  instance.anyRemove(transaction: transaction)
            })
        } catch {
            owsFailDebug("Error: \(error)")
        }

        if shouldBeIndexedForFTS {
            FullTextSearchFinder.allModelsWereRemoved(collection: collection(), transaction: transaction)
        }
    }

    class func anyExists(uniqueId: String,
                        transaction: SDSAnyReadTransaction) -> Bool {
        assert(uniqueId.count > 0)

        switch transaction.readTransaction {
        case .yapRead(let ydbTransaction):
            return ydbTransaction.hasObject(forKey: uniqueId, inCollection: ExperienceUpgrade.collection())
        case .grdbRead(let grdbTransaction):
            let sql = "SELECT EXISTS ( SELECT 1 FROM \(ExperienceUpgradeRecord.databaseTableName) WHERE \(experienceUpgradeColumn: .uniqueId) = ? )"
            let arguments: StatementArguments = [uniqueId]
            return try! Bool.fetchOne(grdbTransaction.database, sql: sql, arguments: arguments) ?? false
        }
    }
}

// MARK: - Swift Fetch

public extension ExperienceUpgrade {
    class func grdbFetchCursor(sql: String,
                               arguments: StatementArguments = StatementArguments(),
                               transaction: GRDBReadTransaction) -> ExperienceUpgradeCursor {
        do {
            let sqlRequest = SQLRequest<Void>(sql: sql, arguments: arguments, cached: true)
            let cursor = try ExperienceUpgradeRecord.fetchCursor(transaction.database, sqlRequest)
            return ExperienceUpgradeCursor(transaction: transaction, cursor: cursor)
        } catch {
            Logger.error("sql: \(sql)")
            owsFailDebug("Read failed: \(error)")
            return ExperienceUpgradeCursor(transaction: transaction, cursor: nil)
        }
    }

    class func grdbFetchOne(sql: String,
                            arguments: StatementArguments = StatementArguments(),
                            transaction: GRDBReadTransaction) -> ExperienceUpgrade? {
        assert(sql.count > 0)

        do {
            let sqlRequest = SQLRequest<Void>(sql: sql, arguments: arguments, cached: true)
            guard let record = try ExperienceUpgradeRecord.fetchOne(transaction.database, sqlRequest) else {
                return nil
            }

            return try ExperienceUpgrade.fromRecord(record)
        } catch {
            owsFailDebug("error: \(error)")
            return nil
        }
    }
}

// MARK: - SDSSerializer

// The SDSSerializer protocol specifies how to insert and update the
// row that corresponds to this model.
class ExperienceUpgradeSerializer: SDSSerializer {

    private let model: ExperienceUpgrade
    public required init(model: ExperienceUpgrade) {
        self.model = model
    }

    // MARK: - Record

    func asRecord() throws -> SDSRecord {
        let id: Int64? = model.grdbId?.int64Value

        let recordType: SDSRecordType = .experienceUpgrade
        let uniqueId: String = model.uniqueId

        // Properties
        let firstViewedTimestamp: Double = model.firstViewedTimestamp
        let lastSnoozedTimestamp: Double = model.lastSnoozedTimestamp
        let isComplete: Bool = model.isComplete

        return ExperienceUpgradeRecord(delegate: model, id: id, recordType: recordType, uniqueId: uniqueId, firstViewedTimestamp: firstViewedTimestamp, lastSnoozedTimestamp: lastSnoozedTimestamp, isComplete: isComplete)
    }
}

// MARK: - Deep Copy

#if TESTABLE_BUILD
@objc
public extension ExperienceUpgrade {
    // We're not using this method at the moment,
    // but we might use it for validation of
    // other deep copy methods.
    func deepCopyUsingRecord() throws -> ExperienceUpgrade {
        guard let record = try asRecord() as? ExperienceUpgradeRecord else {
            throw OWSAssertionError("Could not convert to record.")
        }
        return try ExperienceUpgrade.fromRecord(record)
    }
}
#endif
                                                             