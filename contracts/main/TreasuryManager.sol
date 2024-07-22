// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

contract SimpleStorage {
    uint256 public storedData;

    constructor(uint256 _data) {
        storedData = _data;
    }

    function set(uint256 _data) public {
        storedData = _data;
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}
