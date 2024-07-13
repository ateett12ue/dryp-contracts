// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
import {Basic} from "./basic/Basic.sol";
import {CallLib} from "./utils/CallLib.sol";
import {IERC20, SafeERC20} from "./utils/SafeERC20.sol";
import {Errors} from "./utils/Errors.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {BaseAdapter} from "./basic/BaseAdapter.sol";

/**
 * @title TreasuryAdminstration
 * @author Ateet Tiwari
 * @notice Treasury Adminstration Contract for DRYP.
 */
contract TreasuryAdminstration is Basic, AccessControl, ReentrancyGuard {
    uint256 public storedData;
    
    constructor(uint256 admin) {
        admin = admin;
    }

    function set(uint256 _data) public {
        storedData = _data;
    }

    function get() public view returns (uint256) {
        return storedData;
    }
}
