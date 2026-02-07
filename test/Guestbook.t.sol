// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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

        vm.prank(bob);
        guestbook.sign("Second!");

        vm.prank(alice);
        guestbook.sign("Back again!");

        assertEq(guestbook.totalEntries(), 3);
        assertEq(guestbook.entryCount(alice), 2);
        assertEq(guestbook.entryCount(bob), 1);
    }

    function test_GetLatest() public {
        vm.prank(alice);
        guestbook.sign("Entry 1");

        vm.prank(bob);
        guestbook.sign("Entry 2");

        vm.prank(alice);
        guestbook.sign("Entry 3");

        Guestbook.Entry[] memory latest = guestbook.getLatest(2);
        assertEq(latest.length, 2);
        assertEq(latest[0].message, "Entry 3"); // Most recent first
        assertEq(latest[1].message, "Entry 2");
    }

    function test_GetLatestMoreThanExists() public {
        vm.prank(alice);
        guestbook.sign("Only one");

        Guestbook.Entry[] memory latest = guestbook.getLatest(100);
        assertEq(latest.length, 1);
    }

    function test_RevertEmptyMessage() public {
        vm.prank(alice);
        vm.expectRevert("Say something!");
        guestbook.sign("");
    }

    function test_RevertTooLong() public {
        // 281 chars
        string memory longMsg = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        vm.prank(alice);
        vm.expectRevert("Too long! 280 chars max");
        guestbook.sign(longMsg);
    }

    function test_EmitsSigned() public {
        vm.prank(alice);
        vm.expectEmit(true, false, true, true);
        emit Guestbook.Signed(alice, "Hello!", 0);
        guestbook.sign("Hello!");
    }
}
