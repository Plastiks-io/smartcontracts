// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import "./UtilsV2.sol";
import "./PlastikCryptoV2.sol";
import "./PlastikRoleV2.sol";
import "./PlastikRoyaltyCal.sol";

/// @custom:security-contact daniel@nozama.green
contract PlastikNFTMulV3 is
    Ownable,
    ERC1155URIStorage,
    ERC1155Burnable,
    ERC1155Supply
{
    IPlastikRoyaltyCal internal royaltyCal;
    PlastikCryptoV2 internal plastikCrypto;
    PlastikRoleV2 internal plastikRole;

    event PlastikNFTMultiMinted(
        address mintTo,
        uint256 tokenId,
        uint256 amount
    );

    constructor(
        address _royaltyCal,
        address _plastikCrypto,
        address _plastikRole
    ) ERC1155("https://plastiks.io/ipfs") {
        royaltyCal = IPlastikRoyaltyCal(_royaltyCal);
        plastikCrypto = PlastikCryptoV2(_plastikCrypto);
        plastikRole = PlastikRoleV2(_plastikRole);
    }

    modifier onlyMinter() {
        if (_msgSender() != owner()) {
            plastikRole.verifyMinterRole(_msgSender());
        }
        _;
    }

    function setBaseURI(string memory newuri) public onlyOwner {
        _setBaseURI(newuri);
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        string memory tokenURI,
        uint96 royaltyFee,
        bytes memory data
    ) external onlyMinter returns (uint256) {
        _mint(to, id, amount, data);
        _setURI(id, tokenURI);
        royaltyCal.setTokenRoyalty(id, to, royaltyFee);
        emit PlastikNFTMultiMinted(to, id, amount);
        return id;
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        string[] memory uris,
        uint96[] memory royaltyFee,
        bytes memory data
    ) public onlyMinter {
        require(
            uris.length == amounts.length,
            "ERC1155: uris and amounts length mismatch"
        );
        _mintBatch(to, ids, amounts, data);

        for (uint256 i = 0; i < uris.length; i++) {
            _setURI(ids[i], uris[i]);
            royaltyCal.setTokenRoyalty(ids[i], to, royaltyFee[i]);
            emit PlastikNFTMultiMinted(to, ids[i], amounts[i]);
        }
    }

    function uri(uint256 tokenId)
        public
        view
        virtual
        override(ERC1155, ERC1155URIStorage)
        returns (string memory)
    {
        return super.uri(tokenId);
    }

    function safeLazyMint(
        address buyer,
        uint256 amount,
        NFTVoucherV2 calldata voucher,
        bytes memory signature,
        bytes memory data
    ) external payable onlyMinter returns (uint256) {
        require(
            voucher.tokenAddress == address(this),
            "The voucher must be for this contract"
        );
        // must be compatible with eth_signTypedDataV4 in MetaMask
        address signer = plastikCrypto.verifyNFTVoucher(voucher, signature);
        require(
            signer == voucher.creatorAddress,
            "Creator Address does not match"
        );

        if (!exists(voucher.tokenId)) {
            _mint(signer, voucher.tokenId, voucher.amount, data);
            _setURI(voucher.tokenId, voucher.tokenURI);
            royaltyCal.setTokenRoyalty(
                voucher.tokenId,
                signer,
                voucher.royalty
            );
            emit PlastikNFTMultiMinted(signer, voucher.tokenId, voucher.amount);
        }

        safeTransferFrom(signer, buyer, voucher.tokenId, amount, data);

        return voucher.tokenId;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
