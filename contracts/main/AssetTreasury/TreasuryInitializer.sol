// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Dryp TreasuryInitializer contract
 * @notice The Treasury contract initializes the Treasury.
 * @author Ateet Tiwari
 */

import "./TreasuryStorage.sol";

contract TreasuryInitializer is TreasuryStorage {
    function initialize(address __drypToken, address __drypPool, address _treasuryManager, address __rebalancer, address __usdc, address __usdt)
        external
        initializer
    {
        require(__drypToken != address(0), "drypToken address is zero");
        require(__drypPool != address(0), "dryp Pool address is zero");
        require(__treasuryManager != address(0), "treasury manager address is zero");
        require(__rebalancer != address(0), "rebalancer address is zero");
        require(__usdc != address(0), "usdc address is zero");
        require(__usdt != address(0), "usdt address is zero");

        _dryp = DRYP(__drypToken);
        _drypPool = Pool(__drypPool);
        _rebalancer = __rebalancer;

        rebasePaused = true;
        capitalPaused = false;

        // Initial Vault buffer of 10%
        redeemBuffer = 10e18;
        noredeemBuffer = 90e18;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(TREASURY_MANAGER, _treasuryManager);
        treasury_manager = _treasuryManager;
        rebalancer = Rebalancer(_rebalancer)
        _usdt = __usdt;
        _usdc = __usdc;

        mintTokens[_usdt] = ExchangeToken({
            allowed: true,
            symbol: "USDT",
            decimals: 6,
            megaPool: "",
            maxAllowed: 100e6,
            priceInUsdt: 1
        })

        mintTokens[_usdc] = ExchangeToken({
            allowed: true,
            symbol: "USDC",
            decimals: 6,
            megaPool: "",
            maxAllowed: 100e6,
            priceInUsdt: 1.1
        })

        allRebalancingChanges = new address[](0);
        allAssets = new address[](0);
        
    }
}
