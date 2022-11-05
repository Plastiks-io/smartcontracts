// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

import "./PlastikCryptoV2.sol";
import "./PlastikRoleV2.sol";
import "./UtilsV2.sol";
import "./PlastikRoyaltyCal.sol";

/// @custom:security-contact daniel@nozama.green
abstract contract PlastikBaseERC721V3 is
    Ownable,
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    IERC2981
{
    string internal __baseURI;
    IPlastikRoyaltyCal internal royaltyCal;
    PlastikCryptoV2 internal plastikCrypto;
    PlastikRoleV2 internal plastikRole;

    constructor(
        IPlastikRoyaltyCal _royaltyCal,
        PlastikCryptoV2 _plastikCrypto,
        PlastikRoleV2 _plastikRole,
        string memory name,
        string memory symbol
    ) ERC721(name, symbol) {
        __baseURI = Constants.BASE_URI;
        royaltyCal = _royaltyCal;
        plastikCrypto = _plastikCrypto;
        plastikRole = _plastikRole;
    }

    function _baseURI() internal view override returns (string memory) {
        return __baseURI;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        __baseURI = baseURI_;
    }

    modifier onlyMinterRoleOrOwner() {
        if (_msgSender() != owner()) {
            plastikRole.verifyMinterRole(_msgSender());
        }
        _;
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        override
        returns (address, uint256)
    {
        return royaltyCal.royaltyInfo(_tokenId, _salePrice);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
        royaltyCal.resetTokenRoyalty(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, IERC165, ERC721Enumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC721Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
