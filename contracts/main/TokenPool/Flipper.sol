// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.2;
// import "../TreasuryToken/Dryp.sol";
// import "../../interfaces/Tether.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// // Contract to exchange usdt, usdc, dai from and to ousd.
// //   - 1 to 1. No slippage
// //   - Optimized for low gas usage
// //   - No guarantee of availability

// contract Flipper is Ownable {
//     using SafeERC20 for IERC20;

//     uint256 constant MAXIMUM_PER_TRADE = (25000 * 1e18);

//     DRYP immutable dryp;
//     IERC20 immutable usdt;

//     // ---------------------
//     // Dev constructor
//     // ---------------------
//     constructor(
//         address _dryp,
//         address _usdt
//     ) {
//         require(address(_dryp) != address(0));
//         require(address(_usdt) != address(0));
//         ousd = DRYP(_dryp);
//         usdt = IERC20(_usdt);
//     }

//     // -----------------
//     // Trading functions
//     // -----------------

//     /// @notice Purchase OUSD with USDT
//     /// @param amount Amount of OUSD to purchase, in 18 fixed decimals.
//     function buyDrypWithUsdt(uint256 amount) external {
//         require(amount <= MAXIMUM_PER_TRADE, "Amount too large");
//         // Potential rounding error is an intentional trade off
//         // USDT does not return a boolean and reverts,
//         // so no need for a require.
//         usdt.transferFrom(msg.sender, address(this), amount / 1e12);
//         require(dryp.transfer(msg.sender, amount), "DRYP transfer failed");
//     }

//     /// @notice Sell OUSD for USDT
//     /// @param amount Amount of OUSD to sell, in 18 fixed decimals.
//     function sellDrypForUsdt(uint256 amount) external {
//         require(amount <= MAXIMUM_PER_TRADE, "Amount too large");
//         // USDT does not return a boolean and reverts,
//         // so no need for a require.
//         usdt.transfer(msg.sender, amount / 1e12);
//         require(
//             dryp.transferFrom(msg.sender, address(this), amount),
//             "DRYP transfer failed"
//         );
//     }


//     /// @notice Owner function to withdraw a specific amount of a token
//     function withdraw(address token, uint256 amount)
//         external
//         onlyOwner
//         nonReentrant
//     {
//         IERC20(token).safeTransfer(_governor(), amount);
//     }

//     /// @notice Owner function to withdraw all tradable tokens
//     /// @dev Contract will not perform any swaps until liquidity is provided
//     /// again by transferring assets to the contract.
//     function withdrawAll() external onlyOwner nonReentrant {
//         IERC20(dryp).safeTransfer(_owner(), dryp.balanceOf(address(this)));
//         IERC20(address(usdt)).safeTransfer(
//             _owner(),
//             usdt.balanceOf(address(this))
//         );
//     }
// }
