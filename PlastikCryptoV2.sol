// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./UtilsV2.sol";

contract PlastikCryptoV2 is Ownable, EIP712 {

    address priceValidator;

    constructor(address _priceSigner) EIP712("PLASTIK", "2.0") {
        priceValidator = _priceSigner;
    }


    function setPriceValidator(address newValidator) public onlyOwner returns (bool) {
        priceValidator = newValidator;
        return true;
    }

    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the signer.
    /// @dev Will revert if the signature is invalid. Does not verify that the signer is authorized to mint NFTs.
    /// @param voucher An NFTVoucher describing an unminted NFT.
    function verifyNFTVoucher(
        NFTVoucherV2 calldata voucher,
        bytes memory signature
    ) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    Constants.NFTVOUCHERV2_TYPEHASH,
                    voucher.tokenAddress,
                    voucher.tokenId,
                    voucher.amount,
                    keccak256(bytes(voucher.tokenURI)),
                    voucher.creatorAddress,
                    voucher.royalty
                )
            )
        );
        return ECDSA.recover(digest, signature);
    }

    function verifyPriceSignature(
        address sender,
        PlastikSellPrice calldata item,
        bytes calldata signature,
        address ercToken
    ) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    Constants.PLASTIKSELLPRICEREQUEST_TYPEHASH,
                    item.buyer,
                    item.ratio,
                    item.decimals,
                    item.currency,
                    item.timestamp,
                    item.tokenAddress
                )
            )
        );
        address sig = ECDSA.recover(digest, signature);
        require(sig == priceValidator, "Price validator invalid");
        require(sender == item.buyer, "Buyer sign price invalid");
        require(ercToken == item.tokenAddress, "ercToken invalid");
        require(
            block.timestamp < item.timestamp + 10 minutes,
            "Price is expired"
        );
        return sig;
    }

    function verifySellerSign(
        SellRequest calldata item,
        bytes calldata signature
    ) public view returns (address) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    Constants.SELLREQUEST_TYPEHASH,
                    item.tokenAddress,
                    item.tokenId,
                    item.price,
                    item.amount,
                    item.erc20Address,
                    item.ngoFeePct,
                    item.sellerAddress
                )
            )
        );
        return ECDSA.recover(digest, signature);
    }

    function verifySellerSellRequest(
        address seller,
        SellRequest calldata sellRequest,
        address tokenAddress,
        uint256 tokenId
    ) public pure {
        require(seller == sellRequest.sellerAddress, "Invalid seller address");
        require(
            sellRequest.tokenAddress == tokenAddress,
            "Invalid token address"
        );
        require(sellRequest.tokenId == tokenId, "Invalid token id");
    }

    function verifyPRGVoucher(PRGVoucher calldata voucher, bytes memory signature)
        public
        view
        returns (address)
    {
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    Constants.PRGVOUCHER_TYPEHASH,
                    voucher.tokenAddress,
                    voucher.tokenId,
                    voucher.amount,
                    keccak256(bytes(voucher.tokenURI)),
                    voucher.creatorAddress
                )
            )
        );
        return ECDSA.recover(digest, signature);
    }
}
