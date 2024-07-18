// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title DRYP Token TreasuryCore contract
 * @notice The Treasury contract stores assets. On a deposit, Dryp Token will be minted
           and sent to the depositor. On a withdrawal, Dryp Token will be burned and
           assets will be sent to the withdrawer.
 * @author Ateet Tiwari
 */


// treasury
// Token 
// Token Pool Contract -- price v2 Amm
// Treasury Manager
// Rebalancing -- redeem values



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
            msg.sender == ousdMetaStrategy,
            "Caller is not the OUSD meta strategy"
        );
        _;
    }

    modifier onlyTreasuryManager() {
        require(
            msg.sender == admin,
            "Caller is not the admin"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            msg.sender == treasuryManger,
            "Caller is not the treasury admin"
        );
        _;
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
    ) external whenNotCapitalPaused onlyTreasuryManager {
        _mint(_asset, _amount, _minimumDrypAmount, _recipient);
    }

    // pool usdt + 
    // pool dryp -
    function _mint(
        address _asset,
        uint256 _amount,
        uint256 _minimumDrypAmount,
        address _recipient
    ) internal virtual {
        require(mintTokens[_asset].allowed, "Asset is not supported");
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount < mintTokens[_asset].maxAllowed, "Amount must be less than maxAllowed");

        // uint256 units = _toUnits(_amount, _asset);
        // uint256 unitPrice = _toUnitPrice(_asset, true);
        // hoping for 1-1 mapping
        uint256 priceAdjustedDeposit = drypPool.getDrypAmount(_asset, _amount);

        if (_minimumDrypAmount > 0) {
            require(
                priceAdjustedDeposit >= _minimumDrypAmount,
                "Mint amount lower than minimum"
            );
        }

        emit Mint(recipient, priceAdjustedDeposit);
        // Mint matching amount of Dryp
        dryp.mint(recipient, priceAdjustedDeposit);

        // Transfer the deposited coins to the Stable Pool
        IERC20 asset = IERC20(_asset);
        asset.safeTransferFrom(msg.sender, address(revenue), _amount);
    }

    /**
     * @notice Withdraw a supported asset and burn Dryp.
     * @param _amount Amount of Dryp to burn
     * @param _minimumUnitAmount Minimum stablecoin units to receive in return
     */
    function redeemAssets(uint256 _amount, uint256 _minimumUnitAmount, address _recipient)
        external
        whenNotCapitalPaused
        nonReentrant
        onlyTreasuryManager
    {
        _redeem(_amount, _minimumUnitAmount, _recipient);
    }

    /**
     * @notice Withdraw a supported asset and burn Dryp.
     * @param _amount Amount of Dryp to burn
     * @param _minimumUnitAmount Minimum stablecoin units to receive in return
     */
    function _redeem(uint256 _amount, uint256 _minimumUnitAmount, address _recipient)
        internal
        virtual
    {
        // Calculate redemption outputs
        bool redeemApproved = _preRedeem(_amount);
        if(!redeemApproved)
        {
            revert("Locked value not matched")
        }
        uint256[] memory outputs = _calculateRedeemOutputs(_amount);

        emit Redeem(_recipient, _amount);

        // Send outputs
        uint256 assetCount = allAssets.length;
        for (uint256 i = 0; i < assetCount; ++i) {
            if (outputs[i] == 0) continue;

            address assetAddr = allAssets[i];

            if(output[i] < redeemBasked[address(assetAddr)].value)
            {
                revert("not available for redeem")
            }
            if (IERC20(assetAddr).balanceOf(address(this)) >= outputs[i]) {
                // Use tresury funds first if sufficient
                IERC20(assetAddr).safeTransfer(_recipient, outputs[i]);
            } else {
                revert("Liquidity error");
                // address rebalAdd = assetDefaultStrategies[assetAddr];
                // if (rebalAdd != address(0)) {
                //     // Nothing in Vault, but something in Strategy, send from there
                //     IReblancer rebalancer = IReblancer(rebalAdd);
                //     rebalancer.withdraw(msg.sender, assetAddr, outputs[i]);
                // } else {
                //     // Cant find funds anywhere
                //     revert("Liquidity error");
                // }
            }
        }

        // if (_minimumUnitAmount > 0) {
        //     uint256 unitTotal = 0;
        //     for (uint256 i = 0; i < outputs.length; ++i) {
        //         unitTotal += _toUnits(outputs[i], allAssets[i]);
        //     }
        //     require(
        //         unitTotal >= _minimumUnitAmount,
        //         "Redeem amount lower than minimum"
        //     );
        // }

        dryp.burn(_recipient, _amount);

        _postRedeem(outputs);
    }

    function _preRedeem(uint256 _amount) internal  returns (bool){
        require(_amount > 0, "dryp amount can't be zero");
        uint256 lockedValue = revenue.totalLocked();
        uint256 redeemValueFromPool = pool.getRedeemValue(_amount);
        require(redeemValueFromPool > 0, "Redeem failed");

        if(lockedValue > redeemValueFromPool)
        {
            return true;
        }
        else
        {
            return false
        }
    }

    function _postRedeem(uint256[] outputs) internal {
        // Until we can prove that we won't affect the prices of our assets
        // by withdrawing them, this should be here.
        // It's possible that a redeem was off on its asset total, perhaps
        // a reward token sold for more or for less than anticipated.
        for (uint256 i = 0; i < assetCount; ++i) {
            if (outputs[i] == 0) continue;

            address assetAddr = allAssets[i];

            if(output[i] < redeemBasked[address(assetAddr)].value)
            {
                revert("not available for redeem")
            }
            if (redeemBasked[address(assetAddr)].value >= outputs[i]) {
                // Use tresury funds first if sufficient
               redeemBasked[address(assetAddr)].value = redeemBasked[address(assetAddr)].value - outputs[i]
            } else {
                revert("Liquidity error");
                // address rebalAdd = assetDefaultStrategies[assetAddr];
                // if (rebalAdd != address(0)) {
                //     // Nothing in Vault, but something in Strategy, send from there
                //     IReblancer rebalancer = IReblancer(rebalAdd);
                //     rebalancer.withdraw(msg.sender, assetAddr, outputs[i]);
                // } else {
                //     // Cant find funds anywhere
                //     revert("Liquidity error");
                // }
            }
        }
    }
    /**
     * @notice Calculate the total value of assets held by the Vault and all
     *      strategies and update the supply of dryp.
     */
    function rebase() external virtual nonReentrant {
        _rebase();
    }

    /**
     * @dev Calculate the total value of assets held by the Vault and all
     *      strategies and update the supply of OTokens, optionally sending a
     *      portion of the yield to the trustee.
     * @return totalUnits Total balance of Vault in units
     */
    function _rebase() internal whenNotRebasePaused returns (uint256) {
        uint256 drypSupply = dryp.totalSupply();
        uint256 vaultValue = _totalValue();
        uint256 valueLocked = revenue.totalValueLocked();
        if (drypSupply == 0) {
            return vaultValue;
        }

        // Yield fee collection
        address _trusteeAddress = revenueAddress; // gas savings
        if (_trusteeAddress != address(0) && (vaultValue > drypSupply)) {
            
        }

        // Only rachet OToken supply upwards
        ousdSupply = oUSD.totalSupply(); // Final check should use latest value
        if (vaultValue > ousdSupply) {
            oUSD.changeSupply(vaultValue);
        }
        return vaultValue;
    }

    /**
     * @notice Determine the total value of assets held by the vault and its
     *         strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function totalValue() external view virtual returns (uint256 value) {
        value = _totalValue();
    }

    /**
     * @dev Internal Calculate the total value of the assets held by the
     *         vault and its strategies.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValue() internal view virtual returns (uint256 value) {
        return _totalValueInVault() + _totalValueInStrategies();
    }

    /**
     * @dev Internal to calculate total value of all assets held in Vault.
     * @return value Total value in USD/ETH (1e18)
     */
    function _totalValueInVault() internal view returns (uint256 value) {
        uint256 assetCount = allAssets.length;
        for (uint256 y = 0; y < assetCount; ++y) {
            address assetAddr = allAssets[y];
            uint256 balance = IERC20(assetAddr).balanceOf(address(this));
            if (balance > 0) {
                value += _toUnits(balance, assetAddr);
            }
        }
    }

    function _totalValueLocked() internal view returns (uint256 value) {
        uint256 lockedRevenue =  revenue.getLocked();
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
        returns (uint256[] memory outputs)
    {
        uint256 assetCount = allAssets.length;
        uint256[] memory assetUnits = new uint256[](assetCount);
        uint256[] memory assetBalances = new uint256[](assetCount);
        outputs = new uint256[](assetCount);

        // Calculate assets balances and decimals once,
        // for a large gas savings.
        uint256 totalUnits = 0;
        for (uint256 i = 0; i < assetCount; ++i) {
            address assetAddr = allAssets[i];
            uint256 balance = _checkBalance(assetAddr);
            assetBalances[i] = balance;
            assetUnits[i] = _toUnits(balance, assetAddr);
            totalUnits = totalUnits + assetUnits[i];
        }
        // Calculate totalOutputRatio
        uint256 totalOutputRatio = 0;
        for (uint256 i = 0; i < assetCount; ++i) {
            uint256 unitPrice = _toUnitPrice(allAssets[i], false);
            uint256 ratio = (assetUnits[i] * unitPrice) / totalUnits;
            totalOutputRatio = totalOutputRatio + ratio;
        }
        // Calculate final outputs
        uint256 factor = _amount.divPrecisely(totalOutputRatio);
        for (uint256 i = 0; i < assetCount; ++i) {
            outputs[i] = (assetBalances[i] * factor) / totalUnits;
        }
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
    function _toUnits(uint256 _raw, address _asset)
        internal
        view
        returns (uint256)
    {
        UnitConversion conversion = assets[_asset].unitConversion;
        if (conversion == UnitConversion.DECIMALS) {
            return _raw.scaleBy(18, _getDecimals(_asset));
        } else if (conversion == UnitConversion.GETEXCHANGERATE) {
            uint256 exchangeRate = IGetExchangeRateToken(_asset)
                .getExchangeRate();
            return (_raw * exchangeRate) / 1e18;
        } else {
            revert("Unsupported conversion type");
        }
    }

    /**
     * @dev Returns asset's unit price accounting for different asset types
     *      and takes into account the context in which that price exists -
     *      - mint or redeem.
     *
     * Note: since we are returning the price of the unit and not the one of the
     * asset (see comment above how 1 rETH exchanges for 1.2 units) we need
     * to make the Oracle price adjustment as well since we are pricing the
     * units and not the assets.
     *
     * The price also snaps to a "full unit price" in case a mint or redeem
     * action would be unfavourable to the protocol.
     *
     */
    function _toUnitPrice(address _asset, bool isMint)
        internal
        view
        returns (uint256 price)
    {
        UnitConversion conversion = assets[_asset].unitConversion;
        price = IOracle(priceProvider).price(_asset);

        if (conversion == UnitConversion.GETEXCHANGERATE) {
            uint256 exchangeRate = IGetExchangeRateToken(_asset)
                .getExchangeRate();
            price = (price * 1e18) / exchangeRate;
        } else if (conversion != UnitConversion.DECIMALS) {
            revert("Unsupported conversion type");
        }

        /* At this stage the price is already adjusted to the unit
         * so the price checks are agnostic to underlying asset being
         * pegged to a USD or to an ETH or having a custom exchange rate.
         */
        require(price <= MAX_UNIT_PRICE_DRIFT, "Vault: Price exceeds max");
        require(price >= MIN_UNIT_PRICE_DRIFT, "Vault: Price under min");

        if (isMint) {
            /* Never price a normalized unit price for more than one
             * unit of OETH/OUSD when minting.
             */
            if (price > 1e18) {
                price = 1e18;
            }
            require(price >= MINT_MINIMUM_UNIT_PRICE, "Asset price below peg");
        } else {
            /* Never give out more than 1 normalized unit amount of assets
             * for one unit of OETH/OUSD when redeeming.
             */
            if (price < 1e18) {
                price = 1e18;
            }
        }
    }

    function _getDecimals(address _asset)
        internal
        view
        returns (uint256 decimals)
    {
        decimals = assets[_asset].decimals;
        require(decimals > 0, "Decimals not cached");
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
    function getAssetConfig(address _asset)
        public
        view
        returns (Asset memory config)
    {
        config = assets[_asset];
    }

    /**
     * @notice Return all vault asset addresses in order
     */
    function getAllAssets() external view returns (address[] memory) {
        return allAssets;
    }

    /**
     * @notice Return the number of strategies active on the Vault.
     */
    function getRebalancingCount() external view returns (uint256) {
        return allRebalancing.length;
    }

    /**
     * @notice Return the array of all strategies
     */
    function getAllRebalancing() external view returns (address[] memory) {
        return allRebalancing;
    }

    /**
     * @notice Returns whether the vault supports the asset
     * @param _asset address of the asset
     * @return true if supported
     */
    function isSupportedAsset(address _asset) external view returns (bool) {
        return assets[_asset].isSupported;
    }

    /**
     * @dev Falldown to the admin implementation
     * @notice This is a catch all for all functions not declared in core
     */
    // solhint-disable-next-line no-complex-fallback
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
