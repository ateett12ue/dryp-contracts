// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title OUSD VaultInitializer Contract
 * @notice The VaultInitializer sets up the initial contract.
 * @author Origin Protocol Inc
 */
import { TreasuryInitializer } from "./TreasuryInitializer.sol";
import { TreasuryControl } from "./TreasuryControl.sol";

contract Treasury is TreasuryInitializer, TreasuryControl {}
