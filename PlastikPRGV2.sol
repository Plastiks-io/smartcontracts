// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

import "./UtilsV2.sol";
import "./VerifiedAccounts.sol";
import "./PlastikCryptoV2.sol";
import "./PlastikRoleV2.sol";

/// @custom:security-contact daniel@nozama.green
contract PlastikPRGV2 is
    Ownable,
    ERC1155URIStorage,
    ERC1155Burnable,
    ERC1155Supply
{
    mapping(uint256 => mapping(address => mapping(uint256 => uint256)))
        public attachedPRGToNFT; //tokenId => NFTAdress => tokenIdNFTAdrress => amount

    mapping(address => bool) whiteListSenders;

    event PRGNFTMinted(address indexed mintTo, uint256 tokenId, uint256 amount);
    event TheArtOfRecycling(
        address indexed sustainableUser,
        uint256 tokenId,
        uint256 amount,
        address indexed nftAddress,
        uint256 indexed nftTokenId
    );

    VerifiedAccounts internal verifiedAccounts;
    PlastikCryptoV2 internal plastikCrypto;
    PlastikRoleV2 internal plastikRole;

    constructor(address _addressVerification, address _plastikCrypto, address _plastikRole)
        ERC1155("https://plastiks.io/ipfs")
    {
        verifiedAccounts = VerifiedAccounts(_addressVerification);
        plastikCrypto = PlastikCryptoV2(_plastikCrypto);
        plastikRole = PlastikRoleV2(_plastikRole);
        whiteListSenders[_msgSender()] = true;
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

    function setVerification(address _verifiedAddress)
        public
        onlyOwner
        returns (bool)
    {
        verifiedAccounts = VerifiedAccounts(_verifiedAddress);
        return true;
    }

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        string memory tokenURI,
        bytes memory data
    ) external onlyMinter returns (uint256) {
        require(
            verifiedAccounts.isVerified(to),
            "Creator is not a verified recycler"
        );
        _mint(to, id, amount, data);
        _setURI(id, tokenURI);
        emit PRGNFTMinted(to, id, amount);
        return id;
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        string[] memory uris,
        bytes memory data
    ) public onlyMinter {
        require(
            verifiedAccounts.isVerified(to),
            "Creator is not a verified recycler"
        );
        require(
            uris.length == amounts.length,
            "ERC1155: uris and amounts length mismatch"
        );
        _mintBatch(to, ids, amounts, data);

        for (uint256 i = 0; i < uris.length; i++) {
            _setURI(ids[i], uris[i]);
            emit PRGNFTMinted(to, ids[i], amounts[i]);
        }
    }

    function safeLazyMint(
        address buyer,
        uint256 amount,
        PRGVoucher calldata voucher,
        bytes memory signature,
        bytes memory data
    ) external payable onlyMinter returns (uint256) {
        require(
            voucher.tokenAddress == address(this),
            "The voucher must be for this contract"
        );
        // must be compatible with eth_signTypedDataV4 in MetaMask
        address signer = plastikCrypto.verifyPRGVoucher(voucher, signature);
        require(
            signer == voucher.creatorAddress,
            "Creator Address does not match"
        );

        require(
            verifiedAccounts.isVerified(voucher.creatorAddress),
            "Creator is not a verified recycler"
        );

        if (!exists(voucher.tokenId)) {
            _mint(signer, voucher.tokenId, voucher.amount, data);
            _setURI(voucher.tokenId, voucher.tokenURI);
            emit PRGNFTMinted(signer, voucher.tokenId, voucher.amount);
        }

        safeTransferFrom(signer, buyer, voucher.tokenId, amount, data);

        return voucher.tokenId;
    }

    function uri(uint256 tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return super.uri(tokenId);
    }

    function attachPRGToNFT(
        address sustainableUser,
        uint256 tokenId,
        uint256 amount,
        address nftTokenAddress,
        uint256 nftTokenId
    ) public onlyMinter returns (bool) {
        attachedPRGToNFT[tokenId][nftTokenAddress][nftTokenId] += amount;

        emit TheArtOfRecycling(
            sustainableUser,
            tokenId,
            amount,
            nftTokenAddress,
            nftTokenId
        );

        return true;
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
        require(
            from == address(0) ||
            whiteListSenders[from] ||
            verifiedAccounts.isVerified(from),
            "from account is not a verified recycler"
        );
    }

    function addWhiteListSenderAddress(address _address, bool value) onlyOwner public returns(bool) {
        whiteListSenders[_address] = value;
        return true;
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
