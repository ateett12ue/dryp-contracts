// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Token TreasuryCore contract
 * @author Ateet Tiwari
 */

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { UtilMath } from "../../utils/UtilMath";
import { IOracle } from "../interfaces/IOracle.sol";
import { IGetExchangeRateToken } from "../interfaces/IGetExchangeRateToken.sol";

import "./TresuryInitializer.sol";

contract TreasuryCore is TreasuryInitializer {
    using SafeERC20 for IERC20;
    using UtilMath for uint256;

    // max signed int
    uint256 internal constant MAX_INT = 2**255 - 1;
    // max un-signed int
    uint256 internal constant MAX_UINT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /**
     * @dev Verifies that the rebasing is not paused.
     */
    modifier whenNotRebasePaused() {
        require(!rebasePaused, "Rebasing paused");
        _;
    }

    /**
     * @dev Verifies that the deposits are not paused.
     */
    modifier whenNotCapitalPaused() {
        require(!capitalPaused, "Capital paused");
        _;
    }

    modifier onlyRebalancer() {
        require(
            msg.sender == _rebalancer,
            "Caller is not the OUSD meta strategy"
        );
        _;
    }

    modifier onlyWhenTreasuryInitialized() {
        require(
            treasuryStarted == true,
            "treasury not initialized"
        );
        _;
    }

    

    /**
     * @notice function to return the address of USDT token.
     */
    function usdt() public view virtual override returns (address) {
        return _usdt;
    }

    /**
     * @notice function to return the address of USDC token.
     */
    function usdc() public view virtual override returns (address) {
        return _usdc;
    }

    /**
     * @notice function to return the address of Dexspan.
     */
    function isTokenAllowed(address token) public view returns (bool) {
        return mintTokens[token];
    }

    /**
     * @notice function to return the address of AssetForwarder.
     */
    function getAllAssets() external view returns (address[] memory) {
        return allAssets;
    }

    function isTreasuryStarted() external view returns (bool) {
        return treasuryStarted;
    }

    /**
     * @notice Deposit a supported asset and mint Dryp Token.
     * @param _asset Address of the asset being deposited
     * @param _amount Amount of the asset being deposited
     * @param _minimumDrypAmount Minimum Dryp to mint
     */
    function mint(
        address _asset,
        uint256 _amount,
        uint256 _minimumDrypAmount,
        address _recipient
    ) external whenNotCapitalPaused onlyWhenTreasuryInitialized onlyRole(TREASURY_MANAGER) {
        _mint(_asset, _amount, _minimumDrypAmount, _recipient);
    }

    // pool usdt + 
    // pool dryp -
    function _mint(
        address __asset,
        uint256 __amount,
        uint256 __minimumDrypAmount,
        address __recipient
    ) internal virtual {
        require(mintTokens[__asset].allowed, "Asset is not supported");
        require(__amount > 0, "Amount must be greater than 0");
        require(__amount < mintTokens[__asset].maxAllowed, "Amount must be less than maxAllowed");

        uint256 priceAdjustedDeposit = _drypPool.getDrypAmount(__amount);

        if (__minimumDrypAmount > 0) {
            require(
                priceAdjustedDeposit >= __minimumDrypAmount,
                "Mint amount lower than minimum"
            );
        }

        emit Mint(__recipient, priceAdjustedDeposit);
        // Mint matching amount of Dryp
        _dryp.mint(__recipient, priceAdjustedDeposit);

        // Transfer the deposited coins to the treasury as revenue
        IERC20 asset = IERC20(__asset);
        asset.safeTransferFrom(msg.sender, address(this), __amount);
        revenue[__asset] = amount;
    }

    /**
     * @notice Withdraw a supported asset and burn Dryp.
     * @param _amount Amount of Dryp to burn
     * @param _minimumUnitAmount Minimum stablecoin units to receive in return
     */
    function redeemAssets(uint256 _amount, address _recipient)
        external
        whenNotCapitalPaused
        nonReentrant
        onlyWhenTreasuryInitialized
        onlyRole(TREASURY_MANAGER)
    {
        _redeem(_amount, _minimumUnitAmount, _recipient);
    }

    /**
     * @notice Withdraw a supported asset and burn Dryp.
     * @param __amount Amount of Dryp to burn
     * @param __minimumUnitAmount Minimum stablecoin units to receive in re
     * @param __recipient user getting funds
     */
    function _redeem(uint256 __amount, address __recipient)
        internal
        virtual
    {  
        require(__amount > 0, "Redeem amount must be greater than 0");
        uint256 usdtRedeemValue = _drypPool.getRedeemValue(__amount);
        uint256[] memory outputs = _calculateRedeemOutputs(__amount);

        emit Redeem(__recipient, __amount);

        // Send outputs
        uint256 assetCount = allAssets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            if (outputs[i] == 0) continue;

            address assetAddr = allAssets[i];
            
            uint256 assetBalance = IERC20(assetAddr).balanceOf(address(this));
            if(output[i] > assetBalance)
            {
                revert("not available for redeem")
            }
            if (IERC20(assetAddr).balanceOf(address(this)) >= outputs[i]) {
                IERC20(assetAddr).safeTransfer(__recipient, outputs[i]);
            } else {
                revert("Liquidity error");
            }
        }

        // send back from user to dryp
        dryp.burn(__recipient, __amount);

        _postRedeem(outputs);
    }

    function _postRedeem(uint256[] outputs) internal {
        uint256 assetCount = allAssets.length;
        uint256 vaultValue = _totalValue();
        for (uint256 i = 0; i < assetCount; ++i) {
            if (outputs[i] == 0) continue;

            address assetAddr = allAssets[i];
            uint256 assetUsdtValue = redeemBasketAssets[address(assetAddr)].priceInUsdt;
            uint256 outputValueInUsdt = _toUnitsPrice(redeemBasketAssets[address(assetAddr)].decimal, output[i])
            uint256 assetValueRedeemed = outputValueInUsdt*assetUsdtValue;
            vaultValue = vaultValue - assetValueRedeemed;  
        }
        if(vaultValue > 0)
        {
            updateTotalValue(vaultValue);
        }
        else
        {
            revert("vault emptied")
        }
    }

    /*
     * @notice Determine the total value of assets held by the vault and its
     *         strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function totalValue() external view virtual onlyWhenTreasuryInitialized returns (uint256 value) {
        value = _totalValue();
    }

    /**
     * @dev Internal Calculate the total value of the assets held by the
     *         vault and its strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValueRedeemable() public view virtual onlyWhenTreasuryInitialized returns (uint256 value) {
        uint256 assetCount = allAssets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddr = allAssets[y];
            uint256 balance = IERC20(assetAddr).balanceOf(address(this));
            if (balance > 0) {
                uint256 outputValueInUsdt = _toUnitsPrice(redeemBasketAssets[address(assetAddr)].decimal, balance);
                value += outputValueInUsdt*redeemBasketAssets[address(assetAddr)].priceInUsdt;
            }
        }
    }

    /**
     * @dev Internal to calculate total value of all assets held in Vault.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValueNoRedeemable() public view virtual onlyWhenTreasuryInitialized returns (uint256 value) {
        uint256 assetCount = allAssets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddr = allAssets[y];
            uint256 balance = IERC20(assetAddr).balanceOf(address(this));
            if (balance > 0) {
                uint256 outputValueInUsdt = _toUnitsPrice(unredeemBasketAssets[address(assetAddr)].decimal, balance);
                value += outputValueInUsdt*unredeemBasketAssets[address(assetAddr)].priceInUsdt;
            }
        }
    }

    function _totalValueLocked() public view onlyWhenTreasuryInitialized returns (uint256 value) {
        uint256 lockedRevenue =  IERC20(_usdt).balanceOf(address(this));
        return lockedRevenue
    }



    /**
     * @notice Get the balance of an asset held in Vault and all strategies.
     * @param _asset Address of asset
     * @return uint256 Balance of asset in decimals of asset
     */
    function checkBalance(address _asset) external view returns (uint256) {
        return _checkBalance(_asset);
    }

    /**
     * @notice Get the balance of an asset held in Vault and all strategies.
     * @param _asset Address of asset
     * @return balance Balance of asset in decimals of asset
     */
    function _checkBalance(address _asset)
        internal
        view
        virtual
        returns (uint256 balance)
    {
        IERC20 asset = IERC20(_asset);
        uint256 balance = asset.balanceOf(address(this));
        return balance
    }

    /**
     * @notice Calculate the outputs for a redeem function, i.e. the mix of
     * coins that will be returned
     */
    function calculateRedeemOutputs(uint256 _amount)
        external
        view
        onlyWhenTreasuryInitialized
        returns (uint256[] memory)
    {
        return _calculateRedeemOutputs(_amount);
    }

    /**
     * @dev Calculate the outputs for a redeem function, i.e. the mix of
     * coins that will be returned.
     * @return outputs Array of amounts respective to the supported assets
     */
    function _calculateRedeemOutputs(uint256 _amount)
        internal
        view
        virtual
        onlyWhenTreasuryInitialized
        returns (uint256[] memory outputs)
    {
        uint256 assetCount = allAssets.length;
        uint256 totalUsdtValue = 0;
        outputs = new uint256[](assetCount);

        // Calculate assets balances and decimals once,
        // for a large gas savings.
        uint256 totalUnits = 0;
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddr = allAssets[i];
            TreasuryAsset memory asset = redeemBasketAssets[assetAddress];
            if (asset.isSupported) {
                totalUsdtValue += (asset.priceInUsdt * asset.allotedPercentage) / 100;
            }
        }
        // Calculate totalOutputRatio
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddress = allAssets[i];
            TreasuryAsset memory asset = redeemBasketAssets[assetAddress];
            if (asset.isSupported) {
                uint256 assetValueInUsdt = (asset.priceInUsdt * asset.allotedPercentage) / 100;
                uint256 amountToRedeem = (redeemAmount * assetValueInUsdt) / totalUsdtValue;
                outputs[i] = amountToRedeem
            }
        }
        return outputs;
    }

    /***************************************
                    Pricing
    ****************************************/

    /**
     * @notice Returns the total price in 18 digit units for a given asset.
     *      Never goes above 1, since that is how we price mints.
     * @param asset address of the asset
     * @return price uint256: unit (USD / ETH) price for 1 unit of the asset, in 18 decimal fixed
     */
    function priceUnitMint(address asset)
        external
        view
        returns (uint256 price)
    {
        /* need to supply 1 asset unit in asset's decimals and can not just hard-code
         * to 1e18 and ignore calling `_toUnits` since we need to consider assets
         * with the exchange rate
         */
        uint256 units = _toUnits(
            uint256(1e18).scaleBy(_getDecimals(asset), 18),
            asset
        );
        price = (_toUnitPrice(asset, true) * units) / 1e18;
    }

    /**
     * @notice Returns the total price in 18 digit unit for a given asset.
     *      Never goes below 1, since that is how we price redeems
     * @param asset Address of the asset
     * @return price uint256: unit (USD / ETH) price for 1 unit of the asset, in 18 decimal fixed
     */
    function priceUnitRedeem(address asset)
        external
        view
        returns (uint256 price)
    {
        /* need to supply 1 asset unit in asset's decimals and can not just hard-code
         * to 1e18 and ignore calling `_toUnits` since we need to consider assets
         * with the exchange rate
         */
        uint256 units = _toUnits(
            uint256(1e18).scaleBy(_getDecimals(asset), 18),
            asset
        );
        price = (_toUnitPrice(asset, false) * units) / 1e18;
    }

    /***************************************
                    Utils
    ****************************************/

    /**
     * @dev Convert a quantity of a token into 1e18 fixed decimal "units"
     * in the underlying base (USD/ETH) used by the vault.
     * Price is not taken into account, only quantity.
     *
     * Examples of this conversion:
     *
     * - 1e18 DAI becomes 1e18 units (same decimals)
     * - 1e6 USDC becomes 1e18 units (decimal conversion)
     * - 1e18 rETH becomes 1.2e18 units (exchange rate conversion)
     *
     * @param _raw Quantity of asset
     * @param _asset Core Asset address
     * @return value 1e18 normalized quantity of units
     */
    function _toUnitsPrice( uint256 _decimal, uint256 _amount)
        internal
        view
        returns (uint256)
    {
        uint256 usdtDecimal = 6;
        if (assetDecimal == 6) {
            return _amount;
        } else{
           uint256 _rawAdjusted= _amount.scaleBy(6, _decimal);
           return _rawAdjusted
        }
    }

    /**
     * @notice Return the number of assets supported by the Vault.
     */
    function getAssetCount() public view returns (uint256) {
        return allAssets.length;
    }

    /**
     * @notice Gets the vault configuration of a supported asset.
     */
    function getRedeemAssetConfig(address _asset)
        public
        view
        returns (TreasuryAsset memory config)
    {
        config = redeemBasketAssets[_asset];
    }

    function getUnRedeemAssetConfig(address _asset)
        public
        view
        returns (TreasuryAsset memory config)
    {
        config = unredeemBasketAssets[_asset];
    }

    /**
     * @notice Return all vault asset addresses in order
     */
    function getAllAssets() external view returns (address[] memory) {
        return allAssets;
    }
    

    /**
     * @notice Returns whether the vault supports the asset
     * @param _asset address of the asset
     * @return true if supported
     */
    function isSupportedAssetInRedeem(address _asset) external view returns (bool) {
        return redeemBasketAssets[_asset].isSupported;
    }

    function isSupportedAssetInUnRedeem(address _asset) external view returns (bool) {
        return unredeemBasketAssets[_asset].isSupported;
    }

    /**
     * @dev Falldown to the admin implementation
     * @notice This is a catch all for all functions not declared in core
     */
    fallback() external {
        bytes32 slot = adminImplPosition;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(
                gas(),
                sload(slot),
                0,
                calldatasize(),
                0,
                0
            )

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }

    function abs(int256 x) private pure returns (uint256) {
        require(x < int256(MAX_INT), "Amount too high");
        return x >= 0 ? uint256(x) : uint256(-x);
    }
}
