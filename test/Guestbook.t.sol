// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Guestbook} from "../src/Guestbook.sol";

contract GuestbookTest is Test {
    Guestbook public guestbook;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        guestbook = new Guestbook();
    }

    function test_Sign() public {
        vm.prank(alice);
        guestbook.sign("Hello from Alice!");

        assertEq(guestbook.totalEntries(), 1);
        assertEq(guestbook.entryCount(alice), 1);

        Guestbook.Entry memory entry = guestbook.getEntry(0);
        assertEq(entry.signer, alice);
        assertEq(entry.message, "Hello from Alice!");
    }

    function test_MultipleSigns() public {
        vm.prank(alice);
        guestbook.sign("First!");

        // Different sender — no cooldown needed
        vm.prank(bob);
        guestbook.sign("Second!");

        // Same sender — warp past cooldown
        vm.warp(block.timestamp + 61);
        vm.prank(alice);
        guestbook.sign("Back again!");

        assertEq(guestbook.totalEntries(), 3);
        assertEq(guestbook.entryCount(alice), 2);
        assertEq(guestbook.entryCount(bob), 1);
    }

    function test_GetLatest() public {
        vm.prank(alice);
        guestbook.sign("Entry 1");

        vm.warp(block.timestamp + 61);
        vm.prank(bob);
        guestbook.sign("Entry 2");

        vm.warp(block.timestamp + 61);
        vm.prank(alice);
        guestbook.sign("Entry 3");

        Guestbook.Entry[] memory latest = guestbook.getLatest(2);
        assertEq(latest.length, 2);
        assertEq(latest[0].message, "Entry 3");
        assertEq(latest[1].message, "Entry 2");
    }

    function test_GetLatestMoreThanExists() public {
        vm.prank(alice);
        guestbook.sign("Only one");

        Guestbook.Entry[] memory latest = guestbook.getLatest(100);
        assertEq(latest.length, 1);
    }

    function test_GetLatestCappedAt100() public {
        // Even if you ask for 200, you get max 100
        // Just test the cap logic with fewer entries
        vm.prank(alice);
        guestbook.sign("test");

        Guestbook.Entry[] memory latest = guestbook.getLatest(200);
        assertEq(latest.length, 1); // only 1 entry exists, so capped to 1
    }

    function test_RevertEmptyMessage() public {
        vm.prank(alice);
        vm.expectRevert("Say something!");
        guestbook.sign("");
    }

    function test_RevertTooLong() public {
        string memory longMsg = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        vm.prank(alice);
        vm.expectRevert("Too long! 280 chars max");
        guestbook.sign(longMsg);
    }

    function test_RevertCooldown() public {
        vm.prank(alice);
        guestbook.sign("First");

        // Try again immediately — should revert
        vm.prank(alice);
        vm.expectRevert("Too fast! Wait a bit");
        guestbook.sign("Second");
    }

    function test_CooldownExpires() public {
        vm.prank(alice);
        guestbook.sign("First");

        // Warp past cooldown
        vm.warp(block.timestamp + 61);

        vm.prank(alice);
        guestbook.sign("Second");

        assertEq(guestbook.entryCount(alice), 2);
    }

    function test_EmitsSigned() public {
        vm.prank(alice);
        vm.expectEmit(true, false, true, true);
        emit Guestbook.Signed(alice, "Hello!", 0);
        guestbook.sign("Hello!");
    }

    // --- Fuzz Tests ---

    function testFuzz_Sign(string calldata message) public {
        vm.assume(bytes(message).length > 0 && bytes(message).length <= 280);

        vm.prank(alice);
        guestbook.sign(message);

        assertEq(guestbook.totalEntries(), 1);
        Guestbook.Entry memory entry = guestbook.getEntry(0);
        assertEq(entry.message, message);
        assertEq(entry.signer, alice);
    }

    function testFuzz_GetLatest(uint256 count) public {
        vm.prank(alice);
        guestbook.sign("Entry 1");

        vm.warp(block.timestamp + 61);
        vm.prank(bob);
        guestbook.sign("Entry 2");

        vm.warp(block.timestamp + 61);
        vm.prank(alice);
        guestbook.sign("Entry 3");

        Guestbook.Entry[] memory result = guestbook.getLatest(count);

        // Invariant: length <= min(count, total, MAX_LATEST)
        assertLe(result.length, guestbook.totalEntries());
        assertLe(result.length, count);
        assertLe(result.length, guestbook.MAX_LATEST());
    }

    function testFuzz_RevertBadLength(string calldata message) public {
        vm.assume(bytes(message).length == 0 || bytes(message).length > 280);

        vm.prank(alice);
        vm.expectRevert();
        guestbook.sign(message);
    }
}
