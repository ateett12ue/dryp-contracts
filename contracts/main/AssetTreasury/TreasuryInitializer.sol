// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Dryp TreasuryInitializer contract
 * @notice The Treasury contract initializes the Treasury.
 * @author Ateet Tiwari
 */

import "./TreasuryStorage.sol";

contract TreasuryInitializer is TreasuryStorage {
    function initialize(address _priceProvider, address _drypToken, address _drypPool, address _treasuryManager)
        external
        onlyAdmin
        initializer
    {
        require(_priceProvider != address(0), "PriceProvider address is zero");
        require(_drypToken != address(0), "drypToken address is zero");
        require(_drypPool != address(0), "dryp Pool address is zero");
        require(_treasuryManager != address(0), "treasury manager address is zero");

        dryp = DRYP(_drypToken);
        drypPool = Pool(_drypPool);

        priceProvider = _priceProvider;

        rebasePaused = false;
        capitalPaused = true;

        // Initial Vault buffer of 10%
        redeemBuffer = 1e18;

        treasuryManger = _treasuryManager

        rebalancer = Rebalancer(address(0))
        
        mintTokens[USDT_ADDRESS] = Token({
            allowed: true,
            symbol: "USDT",
            decimals: 6,
            megaPool: MEGA_POOL,
            maxAllowed: MAX_ALLOWED
        })
        admin = msg.sender;
        // Initialize all strategies
        allRebalancing = new address[](0);
        allAssets = new address[](0);
    }
}
