// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";


contract VerifiedAccounts is Ownable, AccessControlEnumerable {
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    mapping(address => bool) verifyAddresses;

    event Verified(address indexed _address);
    event Unverified(address indexed _address);

    constructor() Ownable() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(VALIDATOR_ROLE, _msgSender());
        verifyAddresses[_msgSender()] = true;
    }

    function addVerifyAddress(address _address, bool value) public {
        require(hasRole(VALIDATOR_ROLE, msg.sender), "Only validators can verify");
        verifyAddresses[_address] = value;
        if (value) {
            emit Verified(_address);
        } else {
            emit Unverified(_address);
        }
    }

    function isVerified(address _address) public view returns (bool) {
        return verifyAddresses[_address];
    }
}
