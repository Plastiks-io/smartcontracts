// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";


contract PlasticRecoveryProjects is Ownable, AccessControlEnumerable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    mapping(address => bool) public plasticRecoveryProjects;

    event PlasticRecoveryProjectAdded(address indexed _address);
    event PlasticRecoveryProjectRemoved(address indexed _address);

    constructor() Ownable() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(ADMIN_ROLE, _msgSender());
        plasticRecoveryProjects[_msgSender()] = true;
    }

    function addPlasticRecoveryProject(address _address, bool value) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Only admin can verify");
        plasticRecoveryProjects[_address] = value;
        if (value) {
            emit PlasticRecoveryProjectAdded(_address);
        } else {
            emit PlasticRecoveryProjectRemoved(_address);
        }
    }

    function isPlasticRecoveryProject(address _address) public view returns (bool) {
        return plasticRecoveryProjects[_address];
    }
}
