// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library Constants {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 constant NFTVOUCHER_TYPEHASH =
        keccak256(
            "NFTVoucher(address tokenAddress,uint256 tokenId,string tokenURI,address creatorAddress,uint96 royalty)"
        );
    bytes32 constant NFTVOUCHERV2_TYPEHASH =
        keccak256(
            "NFTVoucherV2(address tokenAddress,uint256 tokenId,uint256 amount,string tokenURI,address creatorAddress,uint96 royalty)"
        );
    bytes32 constant PRGVOUCHER_TYPEHASH =
        keccak256(
            "PRGVoucher(address tokenAddress,uint256 tokenId,uint256 amount,string tokenURI,address creatorAddress)"
        );
    bytes32 constant SELLREQUEST_TYPEHASH =
        keccak256(
            "SellRequest(address tokenAddress,uint256 tokenId,uint256 price,uint256 amount,address erc20Address,uint96 ngoFeePct,address sellerAddress)"
        );
    bytes32 constant PLASTIKSELLPRICEREQUEST_TYPEHASH =
        keccak256(
            "PlastikSellPrice(address buyer,uint256 ratio,uint256 decimals,uint96 currency,uint256 timestamp,address tokenAddress)"
        );
    bytes32 constant BIDREQUEST_TYPEHASH =
        keccak256(
            "BidRequest(address tokenAddress,uint256 tokenId,address erc20Address,address sellerAddress,address bidderAddress,uint256 biddingPrice)"
        );
    string public constant BASE_URI = "https://plastiks.io/ipfs/";
}

/// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
struct NFTVoucher {
    /// @notice The address of the ERC721 or ERC1155
    address tokenAddress;
    /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
    uint256 tokenId;
    /// @notice The metadata URI to associate with this token.
    string tokenURI;
    /// @notice The address of the original signer of this lazy minting
    address creatorAddress;
    /// @notice The royalty percentage for the original creator (offset 2 digits)
    uint96 royalty;
}

/// @notice Represents an un-minted NFT, which has not yet been recorded into the blockchain. A signed voucher can be redeemed for a real NFT using the redeem function.
struct NFTVoucherV2 {
    /// @notice The address of the ERC721 or ERC1155
    address tokenAddress;
    /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
    uint256 tokenId;
    /// @notice The amount of tokens to mint
    uint256 amount;
    /// @notice The metadata URI to associate with this token.
    string tokenURI;
    /// @notice The address of the original signer of this lazy minting
    address creatorAddress;
    /// @notice The royalty percentage for the original creator (offset 2 digits)
    uint96 royalty;
}

struct PRGVoucher {
    /// @notice The address of the ERC721 or ERC1155
    address tokenAddress;
    /// @notice The id of the token to be redeemed. Must be unique - if another token with this ID already exists, the redeem function will revert.
    uint256 tokenId;
    /// @notice The amount of tokens to mint
    uint256 amount;
    /// @notice The metadata URI to associate with this token.
    string tokenURI;
    /// @notice The address of the original signer of this lazy minting
    address creatorAddress;
}

struct SellRequest {
    address tokenAddress;
    uint256 tokenId;
    uint256 price;
    uint256 amount;
    address erc20Address;
    uint96 ngoFeePct;
    address sellerAddress;
}

struct PlastikSellPrice {
    address buyer;
    uint256 ratio;
    uint256 decimals;
    uint96 currency;
    uint256 timestamp;
    address tokenAddress;
}

interface IPlastikArtLazyMint {
    function safeLazyMint(
        address buyer,
        NFTVoucherV2 calldata voucher,
        bytes calldata signature
    ) external payable returns (uint256);
}

interface IPlastikRRGLazyMint {
    function safeLazyMint(
        address buyer,
        NFTVoucherV2 calldata voucher,
        bytes calldata signature
    ) external payable returns (uint256);
}

interface IPlastikPRGLazyMint {
    function safeLazyMint(
        address buyer,
        PRGVoucher calldata voucher,
        bytes calldata signature
    ) external payable returns (uint256);
}
