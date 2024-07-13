// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../governance/Governable.sol";
import "../token/OUSD.sol";
import "../interfaces/Tether.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Contract to exchange underlying token from and to treasuryToken.
//   - 1 to 1. No slippage
//   - Optimized for low gas usage
//   - No guarantee of availability

contract RedemTreasury {
    using SafeERC20 for IERC20;

    uint256 constant MAXIMUM_PER_TRADE = (25000 * 1e18);

    // Settable coin addresses allow easy testing and use of mock currencies.
    IERC20 immutable matic;
    IERC20 immutable link;
    IERC20 immutable dai;
    IERC20 immutable wbtc;

    // ---------------------
    // Dev constructor
    // ---------------------
    constructor(
        address _matic,
        address _link,
        address _dai,
        address _wbtc
    ) {
        require(address(_matic) != address(0));
        require(address(_link) != address(0));
        require(address(_dai) != address(0));
        require(address(_wbtc) != address(0));
        matic = IERC20(_matic);
        link = OUSD(_link);
        dai = IERC20(_dai);
        wbtc = Tether(_wbtc);
    }

    // -----------------
    // Trading functions
    // -----------------

    /// @notice Purchase treasuryTokne with USDT
    /// @param amount Amount of OUSD to purchase, in 18 fixed decimals.
    function buyTTokenWithUSDT(uint256 amount) external {
        require(amount <= MAXIMUM_PER_TRADE, "Amount too large");
        require(
            usdt.transferFrom(msg.sender, address(this), amount),
            "USDT transfer failed"
        );
        require(ttoken.transfer(msg.sender, amount), "OUSD transfer failed");
    }

    /// @notice Sell OUSD for Dai
    /// @param amount Amount of OUSD to sell, in 18 fixed decimals.
    function sellOusdForUSDT(uint256 amount) external {
        require(amount <= MAXIMUM_PER_TRADE, "Amount too large");
        require(usdt.transfer(msg.sender, amount), "DAI transfer failed");
        require(
            ttoken.transferFrom(msg.sender, address(this), amount),
            "OUSD transfer failed"
        );
    }

    /// @notice Purchase OUSD with USDC
    /// @param amount Amount of OUSD to purchase, in 18 fixed decimals.
    function buyTTokenWithUsdc(uint256 amount) external {
        require(amount <= MAXIMUM_PER_TRADE, "Amount too large");
        // Potential rounding error is an intentional trade off
        require(
            usdc.transferFrom(msg.sender, address(this), amount / 1e12),
            "USDC transfer failed"
        );
        require(TToken.transfer(msg.sender, amount), "TToken transfer failed");
    }

    /// @notice Sell OUSD for USDC
    /// @param amount Amount of OUSD to sell, in 18 fixed decimals.
    function sellTTokenForUsdc(uint256 amount) external {
        require(amount <= MAXIMUM_PER_TRADE, "Amount too large");
        require(
            usdc.transfer(msg.sender, amount / 1e12),
            "USDC transfer failed"
        );
        require(
            TToken.transferFrom(msg.sender, address(this), amount),
            "TToken transfer failed"
        );
    }
    
    /// @notice Owner function to withdraw a specific amount of a token
    function withdraw(address token, uint256 amount)
        external
        onlyGovernor
        nonReentrant
    {
        IERC20(token).safeTransfer(_governor(), amount);
    }

    /// @notice Owner function to withdraw all tradable tokens
    /// @dev Contract will not perform any swaps until liquidity is provided
    /// again by transferring assets to the contract.
    function withdrawAll() external onlyGovernor nonReentrant {
        IERC20(dai).safeTransfer(_governor(), dai.balanceOf(address(this)));
        IERC20(ttoken).safeTransfer(_governor(), ousd.balanceOf(address(this)));
        IERC20(address(usdt)).safeTransfer(
            _governor(),
            usdt.balanceOf(address(this))
        );
        IERC20(usdc).safeTransfer(_governor(), usdc.balanceOf(address(this)));
    }
}
