// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
/**
 * @dev Optional functions from the ERC20 standard.
 * Converted from openzeppelin/contracts/token/ERC20/ERC20Detailed.sol
 * @author Ateet Tiwari
 */
abstract contract InitializableERC20Detailed is Initializable, ERC20Upgradeable, ERC20BurnableUpgradeable, OwnableUpgradeable  {
    // Storage gap to skip storage from prior to OUSD reset
    uint256[100] private _____gap;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for `name`, `symbol`, and `decimals`. All three of
     * these values are immutable: they can only be set once during
     * construction.
     * @notice To avoid variable shadowing appended `Arg` after arguments name.
     */
    function _initialize(
        string memory nameArg,
        string memory symbolArg,
        uint8 decimalsArg
    ) internal initializer {
        _name = nameArg;
        _symbol = symbolArg;
        _decimals = decimalsArg;
        __ERC20_init(_name, _symbol);
        __ERC20Burnable_init();
        // __Pausable_init();
        __Ownable_init();
    }

    /**
     * @notice Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the number of decimals used to get its user representation.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    ///**
    //  * @notice Returns the pause state of the token
    //  * name.
    //  */
    // function pause() public onlyOwner {
    //     _pause();
    // }

    // /**
    //  * @notice Returns the unpause state of the token
    //  * name.
    //  */
    // function unpause() public onlyOwner {
    //     _unpause();
    // }
}
