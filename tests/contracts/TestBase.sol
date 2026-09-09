// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface Vm {
    function skip(bool) external;
    function deal(address, uint256) external;
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function warp(uint256) external;
    function expectRevert() external;
    function expectRevert(bytes4) external;
    function expectRevert(bytes calldata) external;
    function createSelectFork(string calldata) external returns (uint256);
    function envOr(string calldata, string calldata) external returns (string memory);
    function envOr(string calldata, uint256) external returns (uint256);
    function envAddress(string calldata) external returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

abstract contract TestBase {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "ASSERT_UINT_EQ");
    }

    function assertEq(address a, address b) internal pure {
        require(a == b, "ASSERT_ADDRESS_EQ");
    }

    function assertTrue(bool a) internal pure {
        require(a, "ASSERT_TRUE");
    }

    function assertLe(uint256 a, uint256 b) internal pure {
        require(a <= b, "ASSERT_LE");
    }

    function assertGe(uint256 a, uint256 b) internal pure {
        require(a >= b, "ASSERT_GE");
    }

    function assertApprox(uint256 a, uint256 b, uint256 tolerance) internal pure {
        require(a > b ? a - b <= tolerance : b - a <= tolerance, "ASSERT_APPROX");
    }
    receive() external payable {}
}
