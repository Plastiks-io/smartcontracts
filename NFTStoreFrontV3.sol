// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./UtilsV2.sol";
import "./PlastikPRGV2.sol";
import "./PlastikNFTV3.sol";
import "./PlastikNFTMulV3.sol";
import "./PlastikCryptoV2.sol";
import "./PlasticRecoveryProjects.sol";
import "./PlastikBurner.sol";


interface IPlastikNFTLazyMint {
   function safeLazyMint(
        address buyer,
        NFTVoucher calldata voucher,
        bytes calldata signature
    ) external payable returns (uint256);
}

contract NFTStoreFrontV3 is Ownable, IERC721Receiver {
    using SafeMath for uint256;
    using SafeMath for uint96;

    event PlatformFee(uint96 platformFee);
    event RewardsFee(uint96 rewardsFeePct);
    event PlastikBurned(address indexed burner, uint256 amount);
    event BuyPRG(
        address indexed assetOwner,
        uint256 indexed tokenId,
        uint256 quantity,
        address indexed buyer
    );

    uint96 private platformFeePct;
    uint96 private rewardsFeePct;

    struct Fee {
        uint256 platformFee;
        uint256 ngoFee;
        uint256 assetFee;
        uint256 royaltyFee;
        uint256 rewardFee;
        uint256 burnAmount;
        address tokenCreator;
    }

    struct PurchaseSignatures {
        bytes artSellSignature;
        bytes artVoucherSignature;
        bytes[] prgSellSignatures;
        bytes[] prgSignatures;
        PlastikSellPrice sellPrice;
        bytes signaturePrice;
        uint256 amountNft;
        bool isMultiNft;
        uint256[] amountsPrg;
        address sendTo;
    }

    struct PurchasePRG {
        SellRequest sellRequest;
        bytes sellSignature;
        PlastikSellPrice sellPrice;
        bytes signaturePrice;
        uint256 amount;
        address sendTo;
    }

    struct CalcFee {
        SellRequest sellRequest;
        uint256 amountToBuy;
        PlastikSellPrice sellPrice;
        bool isPRG;
    }

    address platformWalletAddress;
    address ngoWalletAddress;
    address rewardsWalletAddress;
    PlastikBurner plastikBurner;
    PlastikCryptoV2 plastikCrypto;
    PlasticRecoveryProjects plasticRecoveryProjects;

    constructor(
        address _platformWalletAddress,
        address _ngoWalletAddress,
        address _rewardsWalletAddress,
        uint96 _platformFeePct,
        uint96 _rewardsFeePct,
        address _plastikCrypto,
        address _plasticRecoveryProjects,
        address payable _plastikBurner
    ) Ownable() {
        platformWalletAddress = _platformWalletAddress;
        ngoWalletAddress = _ngoWalletAddress;
        rewardsWalletAddress = _rewardsWalletAddress;
        platformFeePct = _platformFeePct;
        rewardsFeePct = _rewardsFeePct;
        plastikCrypto = PlastikCryptoV2(_plastikCrypto);
        plasticRecoveryProjects = PlasticRecoveryProjects(
            _plasticRecoveryProjects
        );
        plastikBurner = PlastikBurner(_plastikBurner);
    }

    function mixLazyMintedNFTV1WithPRGs(
        PurchaseSignatures calldata purchase,
        SellRequest calldata artSellRequest,
        NFTVoucher calldata artVoucher,
        SellRequest[] calldata prgSellRequests,
        PRGVoucher[] calldata prgVouchers
    ) public {
        plastikCrypto.verifyPriceSignature(
            _msgSender(),
            purchase.sellPrice,
            purchase.signaturePrice,
            artSellRequest.erc20Address
        );

        address artSeller = plastikCrypto.verifySellerSign(
            artSellRequest,
            purchase.artSellSignature
        );
        plastikCrypto.verifySellerSellRequest(
            artSeller,
            artSellRequest,
            artVoucher.tokenAddress,
            artVoucher.tokenId
        );

        IPlastikNFTLazyMint(artVoucher.tokenAddress).safeLazyMint(
            purchase.sendTo,
            artVoucher,
            purchase.artVoucherSignature
        );

        Fee memory artFee = getFees(
            CalcFee(
                artSellRequest,
                purchase.amountNft,
                purchase.sellPrice,
                false
            )
        );

        _distributeFee(
            _msgSender(),
            artSellRequest.sellerAddress,
            artSellRequest.erc20Address,
            artFee
        );

        for (uint8 i = 0; i < prgVouchers.length; i++) {
            address rrgSeller = plastikCrypto.verifySellerSign(
                prgSellRequests[i],
                purchase.prgSellSignatures[i]
            );
        }

        for (uint8 i = 0; i < prgVouchers.length; i++) {
            uint256 tokenId = PlastikPRGV2(prgVouchers[i].tokenAddress)
                .safeLazyMint(
                    purchase.sendTo,
                    purchase.amountsPrg[i],
                    prgVouchers[i],
                    purchase.prgSignatures[i],
                    ""
                );

            PlastikPRGV2(prgVouchers[i].tokenAddress).attachPRGToNFT(
                purchase.sendTo,
                tokenId,
                purchase.amountsPrg[i],
                artVoucher.tokenAddress,
                artVoucher.tokenId
            );

            Fee memory fee = getFees(
                CalcFee(
                    prgSellRequests[i],
                    purchase.amountsPrg[i],
                    purchase.sellPrice,
                    true
                )
            );

            _distributeFee(
                _msgSender(),
                prgSellRequests[i].sellerAddress,
                prgSellRequests[i].erc20Address,
                fee
            );

            emit BuyPRG(
                prgSellRequests[i].sellerAddress,
                prgVouchers[i].tokenId,
                purchase.amountsPrg[i],
                purchase.sendTo
            );

        }
    }

    function mixLazyMintedNFTWithPRGs(
        PurchaseSignatures calldata purchase,
        SellRequest calldata artSellRequest,
        NFTVoucherV2 calldata artVoucher,
        SellRequest[] calldata prgSellRequests,
        PRGVoucher[] calldata prgVouchers
    ) public {
        plastikCrypto.verifyPriceSignature(
            _msgSender(),
            purchase.sellPrice,
            purchase.signaturePrice,
            artSellRequest.erc20Address
        );

        address artSeller = plastikCrypto.verifySellerSign(
            artSellRequest,
            purchase.artSellSignature
        );
        plastikCrypto.verifySellerSellRequest(
            artSeller,
            artSellRequest,
            artVoucher.tokenAddress,
            artVoucher.tokenId
        );

        if (purchase.isMultiNft) {
            PlastikNFTMulV3(artVoucher.tokenAddress).safeLazyMint(
                purchase.sendTo,
                purchase.amountNft,
                artVoucher,
                purchase.artVoucherSignature,
                ""
            );
        } else {
            PlastikNFTV3(artVoucher.tokenAddress).safeLazyMint(
                purchase.sendTo,
                artVoucher,
                purchase.artVoucherSignature
            );
        }

        Fee memory artFee = getFees(
            CalcFee(
                artSellRequest,
                purchase.amountNft,
                purchase.sellPrice,
                false
            )
        );

        _distributeFee(
            _msgSender(),
            artSellRequest.sellerAddress,
            artSellRequest.erc20Address,
            artFee
        );

        for (uint8 i = 0; i < prgVouchers.length; i++) {
            address rrgSeller = plastikCrypto.verifySellerSign(
                prgSellRequests[i],
                purchase.prgSellSignatures[i]
            );
        }

        for (uint8 i = 0; i < prgVouchers.length; i++) {
            uint256 tokenId = PlastikPRGV2(prgVouchers[i].tokenAddress)
                .safeLazyMint(
                    purchase.sendTo,
                    purchase.amountsPrg[i],
                    prgVouchers[i],
                    purchase.prgSignatures[i],
                    ""
                );

            PlastikPRGV2(prgVouchers[i].tokenAddress).attachPRGToNFT(
                purchase.sendTo,
                tokenId,
                purchase.amountsPrg[i],
                artVoucher.tokenAddress,
                artVoucher.tokenId
            );

            Fee memory fee = getFees(
                CalcFee(
                    prgSellRequests[i],
                    purchase.amountsPrg[i],
                    purchase.sellPrice,
                    true
                )
            );


            _distributeFee(
                _msgSender(),
                prgSellRequests[i].sellerAddress,
                prgSellRequests[i].erc20Address,
                fee
            );

            emit BuyPRG(
                prgSellRequests[i].sellerAddress,
                prgVouchers[i].tokenId,
                purchase.amountsPrg[i],
                purchase.sendTo
            );

        }
    }

    function mixExistingNFTWithPRGs(
        PurchaseSignatures calldata purchase,
        SellRequest calldata artSellRequest,
        SellRequest[] calldata prgSellRequests,
        PRGVoucher[] calldata prgVouchers
    ) public {
        plastikCrypto.verifyPriceSignature(
            _msgSender(),
            purchase.sellPrice,
            purchase.signaturePrice,
            artSellRequest.erc20Address
        );

        address artSeller = plastikCrypto.verifySellerSign(
            artSellRequest,
            purchase.artSellSignature
        );
        plastikCrypto.verifySellerSellRequest(
            artSeller,
            artSellRequest,
            artSellRequest.tokenAddress,
            artSellRequest.tokenId
        );

        if (purchase.isMultiNft) {
            IERC1155(artSellRequest.tokenAddress).safeTransferFrom(
                artSellRequest.sellerAddress,
                purchase.sendTo,
                artSellRequest.tokenId,
                purchase.amountNft,
                ""
            );
        } else {
            IERC721(artSellRequest.tokenAddress).safeTransferFrom(
                artSellRequest.sellerAddress,
                purchase.sendTo,
                artSellRequest.tokenId
            );
        }

        Fee memory artFee = getFees(
            CalcFee(
                artSellRequest,
                purchase.amountNft,
                purchase.sellPrice,
                false
            )
        );

        _distributeFee(
            _msgSender(),
            artSellRequest.sellerAddress,
            artSellRequest.erc20Address,
            artFee
        );

        for (uint8 i = 0; i < prgVouchers.length; i++) {
            address rrgSeller = plastikCrypto.verifySellerSign(
                prgSellRequests[i],
                purchase.prgSellSignatures[i]
            );
            plastikCrypto.verifySellerSellRequest(
                rrgSeller,
                prgSellRequests[i],
                prgVouchers[i].tokenAddress,
                prgVouchers[i].tokenId
            );
            uint256 tokenId = PlastikPRGV2(prgVouchers[i].tokenAddress)
                .safeLazyMint(
                    purchase.sendTo,
                    purchase.amountsPrg[i],
                    prgVouchers[i],
                    purchase.prgSignatures[i],
                    ""
                );

            PlastikPRGV2(prgVouchers[i].tokenAddress).attachPRGToNFT(
                purchase.sendTo,
                tokenId,
                purchase.amountsPrg[i],
                artSellRequest.tokenAddress,
                artSellRequest.tokenId
            );

            Fee memory fee = getFees(
                CalcFee(
                    prgSellRequests[i],
                    purchase.amountsPrg[i],
                    purchase.sellPrice,
                    true
                )
            );

            _distributeFee(
                _msgSender(),
                prgSellRequests[i].sellerAddress,
                prgSellRequests[i].erc20Address,
                fee
            );
            emit BuyPRG(
                rrgSeller,
                prgVouchers[i].tokenId,
                purchase.amountsPrg[i],
                purchase.sendTo
            );
        }
    }

    function buyLazyMintedPRG(
        PurchasePRG calldata purchasePRG,
        PRGVoucher calldata voucher,
        bytes calldata signature
    ) public {
        plastikCrypto.verifyPriceSignature(
            _msgSender(),
            purchasePRG.sellPrice,
            purchasePRG.signaturePrice,
            purchasePRG.sellRequest.erc20Address
        );
        address seller = plastikCrypto.verifySellerSign(
            purchasePRG.sellRequest,
            purchasePRG.sellSignature
        );
        plastikCrypto.verifySellerSellRequest(
            seller,
            purchasePRG.sellRequest,
            voucher.tokenAddress,
            voucher.tokenId
        );
        PlastikPRGV2(voucher.tokenAddress).safeLazyMint(
            purchasePRG.sendTo,
            purchasePRG.amount,
            voucher,
            signature,
            ""
        );
        Fee memory fee = getFees(
            CalcFee(
                purchasePRG.sellRequest,
                purchasePRG.amount,
                purchasePRG.sellPrice,
                true
            )
        );
        _distributeFee(
            _msgSender(),
            purchasePRG.sellRequest.sellerAddress,
            purchasePRG.sellRequest.erc20Address,
            fee
        );
        emit BuyPRG(
            seller,
            voucher.tokenId,
            purchasePRG.amount,
            purchasePRG.sendTo
        );
    }

    function buyPRG(PurchasePRG calldata purchasePRG) public {
        plastikCrypto.verifyPriceSignature(
            _msgSender(),
            purchasePRG.sellPrice,
            purchasePRG.signaturePrice,
            purchasePRG.sellRequest.erc20Address
        );
        address seller = plastikCrypto.verifySellerSign(
            purchasePRG.sellRequest,
            purchasePRG.sellSignature
        );
        require(
            seller == purchasePRG.sellRequest.sellerAddress,
            "Invalid seller address"
        );

        IERC1155(purchasePRG.sellRequest.tokenAddress).safeTransferFrom(
            purchasePRG.sellRequest.sellerAddress,
            purchasePRG.sendTo,
            purchasePRG.sellRequest.tokenId,
            purchasePRG.amount,
            ""
        );
        emit BuyPRG(
            seller,
            purchasePRG.sellRequest.tokenId,
            purchasePRG.amount,
            purchasePRG.sendTo
        );

        Fee memory fee = getFees(
            CalcFee(
                purchasePRG.sellRequest,
                purchasePRG.amount,
                purchasePRG.sellPrice,
                true
            )
        );
        _distributeFee(
            _msgSender(),
            purchasePRG.sellRequest.sellerAddress,
            purchasePRG.sellRequest.erc20Address,
            fee
        );
    }

    function _convertCurrencyToPlastik(
        uint256 price,
        PlastikSellPrice memory sellPrice
    ) private view returns (uint256) {

        if (sellPrice.currency == 0) {
            // 0 - PLASTIK, 1 - USD
            // result = price;
            return price;
        } else if (sellPrice.currency == 1) {
            // result = (price * 10 ** sellPrice.decimals)/sellPrice.ratio;
            return (price * 10**sellPrice.decimals) / sellPrice.ratio;
        }
        revert("Currency invalid for price conversion");

    }

    function _distributeFee(
        address _buyer,
        address _seller,
        address _erc20Address,
        Fee memory _fee
    ) private {
        IERC20 erc20Address = IERC20(_erc20Address);
        if (_fee.platformFee > 0) {
            require(
                erc20Address.transferFrom(
                    _buyer,
                    platformWalletAddress,
                    _fee.platformFee
                ),
                "failure while transferring platform fee"
            );
        }
        if (_fee.ngoFee > 0) {
            require(
                erc20Address.transferFrom(
                    _buyer,
                    ngoWalletAddress,
                    _fee.ngoFee
                ),
                "failure while transferring ngo fee"
            );
        }
        if (_fee.royaltyFee > 0) {
            require(
                erc20Address.transferFrom(
                    _buyer,
                    _fee.tokenCreator,
                    _fee.royaltyFee
                ),
                "failure while transferring royalty fee"
            );
        }
        if (_fee.rewardFee > 0) {
            require(
                erc20Address.transferFrom(
                    _buyer,
                    rewardsWalletAddress,
                    _fee.rewardFee
                ),
                "failure while transferring reward fee"
            );
        }
        if (_fee.burnAmount > 0) {
            require(
                erc20Address.transferFrom(
                    _buyer,
                    address(plastikBurner),
                    _fee.burnAmount
                ),
                "failure while transferring burn amount"
            );
            emit PlastikBurned(_buyer, _fee.burnAmount);
        }
        require(
            erc20Address.transferFrom(_buyer, _seller, _fee.assetFee),
            "failure while transferring asset fee"
        );
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        msg.sender.call(data);
        return
            bytes4(
                keccak256("onERC721Received(address,address,uint256,bytes)")
            );
    }

    function platformServiceFee() public view virtual returns (uint96) {
        return platformFeePct;
    }

    function setPlatformServiceFee(uint96 _platformFee)
        public
        onlyOwner
        returns (bool)
    {
        platformFeePct = _platformFee;
        emit PlatformFee(platformFeePct);
        return true;
    }

    function getFees(CalcFee memory calcFee)
        internal
        view
        returns (Fee memory)
    {
        require(
            calcFee.sellRequest.ngoFeePct.add(platformFeePct) <= 10000,
            "Invalid platform fee or NGO fee"
        );
        uint256 price = _convertCurrencyToPlastik(
            calcFee.sellRequest.price,
            calcFee.sellPrice
        );

        uint256 assetFee;
        address creator;
        uint256 royaltyFee;
        uint256 burnAmount = 0;
        uint256 paymentAmt = price * calcFee.amountToBuy;
        uint256 platformFee = paymentAmt.mul(platformFeePct).div(10000);
        uint256 rewardFee = 0;
        uint256 ngoFee = paymentAmt.mul(calcFee.sellRequest.ngoFeePct).div(
            10000
        );
        uint256 amount = paymentAmt.sub(platformFee).sub(ngoFee);

        if (calcFee.isPRG) {
            burnAmount = plastikBurner.currentBurnRate() * calcFee.amountToBuy;
            if (platformFee > burnAmount) {
                platformFee -= burnAmount;
            } else {
                burnAmount = platformFee;
                platformFee = 0;
            }
        } else {
            rewardFee = platformFee.mul(rewardsFeePct).div(10000);
            if (platformFee > rewardFee) {
                platformFee -= rewardFee;
            } else {
                rewardFee = platformFee;
                platformFee = 0;
            }
        }

        if (
            ERC165Checker.supportsInterface(
                calcFee.sellRequest.tokenAddress,
                type(IERC2981).interfaceId
            )
        ) {
            (creator, royaltyFee) = (
                (
                    IERC2981(calcFee.sellRequest.tokenAddress).royaltyInfo(
                        calcFee.sellRequest.tokenId,
                        amount
                    )
                )
            );
        }

        assetFee = amount.sub(royaltyFee);

        if (
            plasticRecoveryProjects.isPlasticRecoveryProject(
                calcFee.sellRequest.sellerAddress
            )
        ) {
            assetFee += ngoFee;
            ngoFee = 0;
        }

        return
            Fee(
                platformFee,
                ngoFee,
                assetFee,
                royaltyFee,
                rewardFee,
                burnAmount,
                creator
            );
    }

    function setPlastikCrypto(address _crypto) public onlyOwner returns (bool) {
        plastikCrypto = PlastikCryptoV2(_crypto);
        return true;
    }

    function setPlasticRecoveryProjects(address _recoveryProjects)
        public
        onlyOwner
        returns (bool)
    {
        plasticRecoveryProjects = PlasticRecoveryProjects(_recoveryProjects);
        return true;
    }

    function setPlasticBurner(address payable _plasticBurner)
        public
        onlyOwner
        returns (bool)
    {
        plastikBurner = PlastikBurner(_plasticBurner);
        return true;
    }

    function rewardsFee() public view virtual returns (uint96) {
        return rewardsFeePct;
    }

    function setRewardsFeePct(uint96 _rewardsFeePct)
        public
        onlyOwner
        returns (bool)
    {
        rewardsFeePct = _rewardsFeePct;
        emit RewardsFee(rewardsFeePct);
        return true;
    }
}
