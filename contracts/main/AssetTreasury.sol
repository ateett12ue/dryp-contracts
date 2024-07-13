// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Roles.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Treasury is Initializable{
    using Roles for Roles.Role;
    Roles.Role private _owner;
    Roles.Role private _admin;

    struct TokenInfo {
        IERC20 token;
        uint256 lockedAmount;
        uint256 openAmount;
    }

    TokenInfo[] public tokens;

    IERC20Upgradeable public treasuryToken;

    uint256 public lastTokenAddedTime;

    function initialize(
        address[] memory _initialTokens,
        address _treasuryToken,
    ) public initializer {
        __Ownable_init();
        require(_initialTokens.length == 4, "Must start with 4 tokens");
        _owner = msg.sender;
        _admin = msg.sender;;
        for (uint256 i = 0; i < _initialTokens.length; i++) {
            tokens.push(TokenInfo({
                token: IERC20Upgradeable(_initialTokens[i]),
                lockedAmount: 0,
                openAmount: 100 * 10 ** 18  // Assume 100 units of each token
            }));
        }

        treasuryToken = IERC20Upgradeable(_treasuryToken);
        lastTokenAddedTime = block.timestamp;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Caller is not the admin");
        _;
    }

    modifier onlyAdmin() {
        require(_admin == msg.sender, "Caller is not the admin");
        _;
    }

    function rebalance(uint256[] memory _amounts) external onlyOwner {
        require(_amounts.length == tokens.length, "Amounts array length mismatch");

        for (uint256 i = 0; i < _amounts.length; i++) {
            uint256 totalAmount = tokens[i].openAmount + tokens[i].lockedAmount + _amounts[i];
            uint256 newLockedAmount = (totalAmount * 90) / 100;
            uint256 newOpenAmount = totalAmount - newLockedAmount;

            tokens[i].lockedAmount = newLockedAmount;
            tokens[i].openAmount = newOpenAmount;

            tokens[i].token.transferFrom(msg.sender, address(this), _amounts[i]);
        }
    }

    function addNewToken(address _newToken) external onlyOwner {
        require(tokens.length < 8, "Maximum of 8 tokens allowed");
        require(block.timestamp >= lastTokenAddedTime + 30 days, "Can only add one token per month");

        tokens.push(TokenInfo({
            token: IERC20Upgradeable(_newToken),
            lockedAmount: 0,
            openAmount: 100 * 10 ** 18  // Assume 100 units of each token
        }));

        lastTokenAddedTime = block.timestamp;
    }

    function deposit(uint256[] memory _amounts) external onlyOwner {
        require(_amounts.length == tokens.length, "Amounts array length mismatch");

        for (uint256 i = 0; i < _amounts.length; i++) {
            require(_amounts[i] <= tokens[i].openAmount, "Exceeds open amount for token");

            tokens[i].token.transferFrom(msg.sender, address(this), _amounts[i]);
            tokens[i].openAmount -= _amounts[i];

            uint256 treasuryTokensToMint = _amounts[i];
            treasuryToken.transfer(msg.sender, treasuryTokensToMint);
        }
    }

    function withdraw(uint256[] memory _amounts) external onlyOwner {
        require(_amounts.length == tokens.length, "Amounts array length mismatch");

        for (uint256 i = 0; i < _amounts.length; i++) {
            require(_amounts[i] <= tokens[i].lockedAmount, "Exceeds locked amount for token");

            tokens[i].token.transfer(msg.sender, _amounts[i]);
            tokens[i].lockedAmount -= _amounts[i];

            uint256 treasuryTokensToBurn = _amounts[i];
            treasuryToken.transferFrom(msg.sender, address(this), treasuryTokensToBurn);
        }
    }
}
