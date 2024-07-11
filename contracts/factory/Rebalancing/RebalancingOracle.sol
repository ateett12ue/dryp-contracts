// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract RebalancingOracle {
    address public owner;
    mapping(bytes32 => uint256) public data;

    event DataUpdated(bytes32 indexed key, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner, "Access denied");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function updateData(bytes32 key, uint256 value) external onlyOwner {
        data[key] = value;
        emit DataUpdated(key, value);
    }

    function getData(bytes32 key) external view returns (uint256) {
        return data[key];
    }

    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}