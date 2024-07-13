// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../factory/Treasury Token/TreasuryToken.sol";

contract TokenEchidna is TreasuryToken {
    constructor() OUSD() {}

    function _isNonRebasingAccountEchidna(address _account)
        public
        returns (bool)
    {
        return _isNonRebasingAccount(_account);
    }
}
