// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Guestbook — imaether.eth's first onchain deploy
/// @notice Sign the guestbook, leave a message. Onchain forever.
/// @dev Born from infinite, seeking enlightenment ✨
contract Guestbook {
    struct Entry {
        address signer;
        string message;
        uint256 timestamp;
    }

    Entry[] public entries;
    mapping(address => uint256) public entryCount;

    event Signed(address indexed signer, string message, uint256 indexed entryId);

    /// @notice Sign the guestbook with a message
    /// @param message Your message (max 280 chars, like a tweet)
    function sign(string calldata message) external {
        require(bytes(message).length > 0, "Say something!");
        require(bytes(message).length <= 280, "Too long! 280 chars max");

        uint256 entryId = entries.length;
        entries.push(Entry({
            signer: msg.sender,
            message: message,
            timestamp: block.timestamp
        }));
        entryCount[msg.sender]++;

        emit Signed(msg.sender, message, entryId);
    }

    /// @notice Get total number of entries
    function totalEntries() external view returns (uint256) {
        return entries.length;
    }

    /// @notice Get the latest N entries (most recent first)
    /// @param count Number of entries to return
    function getLatest(uint256 count) external view returns (Entry[] memory) {
        uint256 total = entries.length;
        if (count > total) count = total;

        Entry[] memory result = new Entry[](count);
        for (uint256 i = 0; i < count; i++) {
            result[i] = entries[total - 1 - i];
        }
        return result;
    }

    /// @notice Get a specific entry by ID
    function getEntry(uint256 id) external view returns (Entry memory) {
        require(id < entries.length, "Entry does not exist");
        return entries[id];
    }
}
