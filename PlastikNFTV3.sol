// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./UtilsV2.sol";
import "./PlastikBaseERC721V3.sol";

/// @custom:security-contact daniel@nozama.green
contract PlastikNFTV3 is PlastikBaseERC721V3, IPlastikArtLazyMint {
    event PlastikNFTMinted(address mintTo, uint256 tokenId);

    constructor(
        IPlastikRoyaltyCal _royaltyCal,
        PlastikCryptoV2 _plastikCrypto,
        PlastikRoleV2 _plastikRole,
        string memory name,
        string memory symbol
    )
        PlastikBaseERC721V3(
            _royaltyCal,
            _plastikCrypto,
            _plastikRole,
            name,
            symbol
        )
    {}

    function safeLazyMint(
        address buyer,
        NFTVoucherV2 calldata voucher,
        bytes calldata signature
    ) external payable onlyMinterRoleOrOwner returns (uint256) {
        require(voucher.tokenAddress == address(this), "The voucher must be for this contract");
        // must be compatible with eth_signTypedDataV4 in MetaMask
        address signer = plastikCrypto.verifyNFTVoucher(voucher, signature);

        require(
            signer == voucher.creatorAddress,
            "Creator Address does not match"
        );

        // mint to signer first to establish on-chain history
        _safeMint(signer, voucher.tokenId);
        _setTokenURI(voucher.tokenId, voucher.tokenURI);

        emit PlastikNFTMinted(signer, voucher.tokenId);

        royaltyCal.setTokenRoyalty(voucher.tokenId, signer, voucher.royalty);

        // transfer to the buyer
        transferFrom(signer, buyer, voucher.tokenId);
        return voucher.tokenId;
    }

    function safeMint(string memory tokenURI, uint256 tokenId, uint96 royaltyFee) onlyMinterRoleOrOwner public returns (uint256) {
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, tokenURI);
        emit PlastikNFTMinted(msg.sender, tokenId);

        royaltyCal.setTokenRoyalty(tokenId, msg.sender, royaltyFee);

        return tokenId;
    }

}
