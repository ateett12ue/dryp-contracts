// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./treasury.sol";

contract TreasuryFactory {
    SimpleStorage[] public deployedContracts;

    event ContractDeployed(address contractAddress);

    function createSimpleStorage(uint256 _initialData) public {
        SimpleStorage newContract = new SimpleStorage(_initialData);
        deployedContracts.push(newContract);
        emit ContractDeployed(address(newContract));
    }

    function getDeployedContracts() public view returns (SimpleStorage[] memory) {
        return deployedContracts;
    }
}
