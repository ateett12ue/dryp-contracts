// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FeeOracle {
    address public feeContract;
    uint256 public feeAmount;

    constructor(address _feeContract, uint256 _feeAmount) {
        feeContract = _feeContract;
        feeAmount = _feeAmount;
    }

    function updateFeeAmount(uint256 _newFeeAmount) external {
        require(msg.sender == feeContract, "Fee Cannot Be Updated");
        feeAmount = _newFeeAmount;
    }

    function getFeeAmount() external view returns (uint256) {
        return feeAmount;
    }
}