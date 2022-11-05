// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./UtilsV2.sol";

contract PlastikRoleV2 is AccessControl {
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(Constants.MINTER_ROLE, _msgSender());
    }

    function grantMinterRole(address account) public {
        grantRole(Constants.MINTER_ROLE, account);
    }

    function verifyMinterRole(address account) public view {
        if (!hasRole(Constants.MINTER_ROLE, account)) {
            revert("Only minter role can mint");
        }
    }
}
