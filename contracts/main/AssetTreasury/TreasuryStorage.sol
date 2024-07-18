// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Treasury Storage contract
 * @author Ateet Tiwari
 */

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";

import { IStrategy } from "../interfaces/IStrategy.sol";
import { Governable } from "../governance/Governable.sol";

import { Rebalancer } from "./Rebalancer";
import { OUSD } from "../token/OUSD.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "../utils/Helpers.sol";
import {TreasuryConstants} from "./TreasuryConstants.sol";

contract TreasuryStorage is Initializable, Admin, TreasuryConstants {
    using SafeERC20 for IERC20;

    event AssetSupported(address _asset);
    event AssetRemoved(address _asset);
    event AssetDefaultRebalancerUpdated(address _asset, address _rebalancer);
    event AssetAllocated(address _asset, address _rebalancer, uint256 _amount);

    event RebalancerApproved(address _addr);
    event RebalancerRemoved(address _addr);

    event Mint(address _addr, uint256 _value);
    event Redeem(address _addr, uint256 _value);

    event CapitalPaused();
    event CapitalUnpaused();
    event RebasePaused();
    event RebaseUnpaused();
    event RedeemBucketPaused();
    event RedeemBucketUnpaused();
    event UnredeemBucketPaused();
    event UnredeemBucketUnpaused();

    event RedeemThresholdUpdated(uint256 _redeemAllocated);
    event UnRedeemThresholdUpdated(uint256 _unredeemAllocated);

    event TreasuryTimeLockUpdated(uint256 _treasuryTimeLock);

    /// move to rebalancer contract
    event PriceProviderUpdated(address _priceProvider);


    event TreasuryMangerUpdated(address _address);
    event TreasuryAdminUpdated(address _address);
    event TreasuryTokenUpdated(address _address);
    event TreasuryTokenPoolUpdated(address _address);
    event RevenueTresuryUpdated(address _revenueAddress);
    event MaxSupplyDiffChanged(uint256 maxSupplyDiff); 
    event SwapperChanged(address _address);
    event SwapAllowedUndervalueChanged(uint256 _basis);
    event SwapSlippageChanged(address _asset, uint256 _basis);
    event Swapped(
        address indexed _fromAsset,
        address indexed _toAsset,
        uint256 _fromAssetAmount,
        uint256 _toAssetAmount
    );

    struct Token{
        bool allowed;
        address megaPool;
        uint8 decimals;
        uint256 maxAllowed;
        string symbol;
    }

    // Changed to fit into a single storage slot so the decimals needs to be recached
    struct Asset {
        bool isSupported;
        uint8 decimals;
        uint16 allowedOracleSlippageBps;
        uint16 allotatedPercentange;
    }
    mapping(address => Asset) internal assets;
    /// @dev list of all assets supported by the vault.

    mapping(address => Token) internal mintTokens;

    address[] public allAssets;

    // Rebalancing Configs approved for use by the Vault
    struct Rebalancer {
        bool isSupported;
        uint256 _deprecated; // Deprecated storage slot
        uint256 _redeemBasketPercentage;
        uint256 _unredeemBasketPercentage;
    }

    /// @dev mapping of Rebalancing contracts to their configiration
    mapping(address => Rebalancing) internal rebalancing;

    /// @dev list of all treasury rebalancing
    address[] internal allRebalancing;

    /// @notice Address of the Oracle price provider contract
    /// move to rebalancing contract
    address public priceProvider;

    /// @notice pause rebasing if true
    bool public rebasePaused = false;

    /// @notice pause operations that change the DRYP supply.
    /// eg mint, redeem, allocate, mint/burn for rebalancing
    bool public capitalPaused = true;

    /// @notice Percentage of assets to kept in Vault to handle (most) withdrawals. 100% = 1e18. 10% by default
    /// move to rebalancing contract
    uint256 public redeemBuffer;

    /// @dev Address of the Dryp token.
    DRYP internal dryp;

    /// @dev Address of the Dryp Pool Contract.
    Pool internal drypPool;

    /// @notice Address of the Strategist
    address public treasuryManger = address(0);

    /// @notice Max difference between total supply and total value of assets. 18 decimals.
    uint256 public maxSupplyDiff;

    /// @notice Super Admin on top of treasuryManager
    address public admin;

    Rebalancer private rebalancer;

    uint256 constant MINT_MINIMUM_UNIT_PRICE = 0.998e18;

    uint256 constant MIN_UNIT_PRICE_DRIFT = 0.7e18;
    uint256 constant MAX_UNIT_PRICE_DRIFT = 1.3e18;

    /// @notice Collateral swap configuration.
    /// @dev is packed into a single storage slot to save gas.
    struct SwapConfig {
        // Contract that swaps the treasury's collateral assets
        address swapper;
        // Max allowed percentage the total value can drop below the total supply in basis points.
        // For example 100 == 1%
        uint16 allowedUndervalueBps;
    }

    SwapConfig internal swapConfig = SwapConfig(address(0), 0);

    /**
     * @notice set the implementation for the admin, this needs to be in a base class else we cannot set it
     * @param newImpl address of the implementation
     */
    function setAdminImpl(address newImpl) external onlyAdmin {
        require(
            Address.isContract(newImpl),
            "new implementation is not a contract"
        );
        bytes32 position = adminImplPosition;
        assembly {
            sstore(position, newImpl)
        }
    }
}
