// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/common/ERC2981.sol";

interface IPlastikRoyaltyCal is IERC2981 {
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external;

    function resetTokenRoyalty(uint256 _tokenId) external;
}

contract PlastikRoyaltyCal is ERC2981, IPlastikRoyaltyCal {
    event TokenRoyaltySet(uint256 tokenId, address receiver, uint96 fee);
    event TokenRoyaltyReset(uint256 tokenId);

    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) public {
        super._setTokenRoyalty(tokenId, receiver, feeNumerator);
        emit TokenRoyaltySet(tokenId, receiver, feeNumerator);
    }

    function resetTokenRoyalty(uint256 tokenId) public {
        super._resetTokenRoyalty(tokenId);
        emit TokenRoyaltyReset(tokenId);
    }
}
