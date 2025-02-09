import XCTest
import Cuckoo
@testable import BitcoinCore

extension XCTestCase {

    func waitForMainQueue(queue: DispatchQueue = DispatchQueue.main) {
        let e = expectation(description: "Wait for Main Queue")
        queue.async { e.fulfill() }
        waitForExpectations(timeout: 2)
    }

}

public func equalErrors(_ lhs: Error?, _ rhs: Error?) -> Bool {
    return lhs?.reflectedString == rhs?.reflectedString
}


public extension Error {
    var reflectedString: String {
        // NOTE 1: We can just use the standard reflection for our case
        return String(reflecting: self)
    }

    // Same typed Equality
    func isEqual(to: Self) -> Bool {
        return self.reflectedString == to.reflectedString
    }

}

extension Block {

    var header: BlockHeader {
        return BlockHeader(
                version: version, headerHash: headerHash, previousBlockHeaderHash: previousBlockHash, merkleRoot: merkleRoot,
                timestamp: timestamp, bits: bits, nonce: nonce
        )
    }

    func setHeaderHash(hash: Data) {
        headerHash = hash
    }

}

extension BitcoinCore.KitState: Equatable {

    public static func ==(lhs: BitcoinCore.KitState, rhs: BitcoinCore.KitState) -> Bool {
        switch (lhs, rhs) {
        case (.synced,   .synced): return true
        case let (.syncing(lProgress),   .syncing(rProgress)): return lProgress == rProgress
        case (.notSynced,   .notSynced): return true
        default:
            return false
        }
    }

}

extension BitcoinCoreErrors.UnspentOutputSelection: Equatable {

    public static func ==(lhs: BitcoinCoreErrors.UnspentOutputSelection, rhs: BitcoinCoreErrors.UnspentOutputSelection) -> Bool {
        switch (lhs, rhs) {
        case (.wrongValue, .wrongValue): return true
        case (.emptyOutputs, .emptyOutputs): return true
        case let (.notEnough(lMaxFee),   .notEnough(rMaxFee)): return lMaxFee == rMaxFee
        default:
            return false
        }
    }

}

extension BlockInfo: Equatable {

    public static func ==(lhs: BlockInfo, rhs: BlockInfo) -> Bool {
        return lhs.headerHash == rhs.headerHash && lhs.height == rhs.height && lhs.timestamp == rhs.timestamp
    }

}

extension TransactionInfo: Equatable {

    public static func ==(lhs: TransactionInfo, rhs: TransactionInfo) -> Bool {
        return lhs.transactionHash == rhs.transactionHash
    }

}

extension PeerAddress: Equatable {

    public static func ==(lhs: PeerAddress, rhs: PeerAddress) -> Bool {
        return lhs.ip == rhs.ip
    }

}

extension PublicKey: Equatable {

    public static func ==(lhs: PublicKey, rhs: PublicKey) -> Bool {
        return lhs.path == rhs.path
    }

}

extension Block: Equatable {

    public static func ==(lhs: Block, rhs: Block) -> Bool {
        return lhs.headerHash == rhs.headerHash
    }

}

extension Transaction: Equatable {

    public static func ==(lhs: Transaction, rhs: Transaction) -> Bool {
        return lhs.dataHash == rhs.dataHash
    }

}

extension Input: Equatable {

    public static func ==(lhs: Input, rhs: Input) -> Bool {
        return lhs.previousOutputIndex == rhs.previousOutputIndex && lhs.previousOutputTxHash == rhs.previousOutputTxHash
    }

}

extension Output: Equatable {

    public static func ==(lhs: Output, rhs: Output) -> Bool {
        return lhs.keyHash == rhs.keyHash && lhs.scriptType == rhs.scriptType && lhs.value == rhs.value && lhs.index == rhs.index
    }

}

extension BlockHeader: Equatable {

    public static func ==(lhs: BlockHeader, rhs: BlockHeader) -> Bool {
        return lhs.previousBlockHeaderHash == rhs.previousBlockHeaderHash && lhs.headerHash == rhs.headerHash && lhs.merkleRoot == rhs.merkleRoot
    }

}

extension FullTransaction: Equatable {

    public static func ==(lhs: FullTransaction, rhs: FullTransaction) -> Bool {
        return TransactionSerializer.serialize(transaction: lhs) == TransactionSerializer.serialize(transaction: rhs)
    }

}

extension UnspentOutput: Equatable {

    public static func ==(lhs: UnspentOutput, rhs: UnspentOutput) -> Bool {
        return lhs.output.value == rhs.output.value
    }

}

extension InputToSign: Equatable {

    public static func ==(lhs: InputToSign, rhs: InputToSign) -> Bool {
        return lhs.input == rhs.input && lhs.previousOutputPublicKey == rhs.previousOutputPublicKey
    }

}

func addressMatcher(_ address: Address) -> ParameterMatcher<Address> {
    return ParameterMatcher<Address> { address.stringValue == $0.stringValue }
}

func addressMatcher(_ address: Address?) -> ParameterMatcher<Address?> {
    return ParameterMatcher<Address?> { tested in
        if let a1 = address, let a2 = tested {
            return addressMatcher(a1).matches(a2)
        } else {
            return address == nil && tested == nil
        }
    }
}
