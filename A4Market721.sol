// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/token/ERC721/IERC721Upgradeable.sol";
import '@openzeppelin-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol';
import "@openzeppelin-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import '@openzeppelin-upgradeable/contracts/interfaces/IERC2981Upgradeable.sol';
import '@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/utils/AddressUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/utils/math/SafeMathUpgradeable.sol';
import "@openzeppelin-upgradeable/contracts/utils/introspection/ERC165CheckerUpgradeable.sol";

contract Marketplace721 is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using AddressUpgradeable for address;
    using SafeMathUpgradeable for uint256;
    using ERC165CheckerUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public boostAccount;

    uint256 public gracePeriod;

    enum ListingType {
        None,
        FixedPrice,
        Auction
    }

    struct Listing {
        ListingType listingType;
        address seller;
        address collection;
        uint256 tokenId;
        uint256 timeStart;
        uint256 timeEnd;
        IERC20Upgradeable currency;
        uint256 minimalBid;
        uint256 lastBid;
        address lastBidder;
        bool claimed;

        mapping(address => uint256) pendingAmounts;
    }

    struct ListingAdditional {
        uint256 boost;
        uint256 bidStep;
    }


    mapping(uint256 => Listing) public listings;
    mapping(uint256 => ListingAdditional) public listingsAdditional;

    mapping(address => mapping(uint256 => uint256)) public tokenToLastListing;

    mapping(address => bool) public isCollection;

    mapping(address => bool) public collectionCreators;

    struct Currency {
        bool enabled;
        uint256 bidStep;
    }

    mapping(address => Currency) public currencies;

    mapping(address => bool) public isBlacklisted;

    uint256 private _lastListingId;
    uint256 public activeCount;


    // EVENTS

    event CollectionCreated(address indexed collection);

    event ListingCreated(
        uint256 indexed listingId,
        address indexed collection,
        uint256 indexed tokenId,
        ListingType listingType,
        uint256 timeStart,
        uint256 timeEnd,
        address currency,
        uint256 minimalBid,
        address seller
    );

    event ListingBought(uint256 indexed id, address indexed buyer, address indexed seller, uint256 price);

    event ListingBid(uint256 indexed id, address indexed bidder, address indexed seller, uint256 amount, uint256 timeEnd);

    event ListingCanceled(uint256 indexed id, address indexed canceler);

    event PendingWithdrawn(uint256 indexed listingId, address indexed claimer, uint256 amount);

    event CollectibleClaimed(uint256 indexed listingId, address indexed seller, address indexed target, uint256 amount);

    event CurrencySet(address indexed currency, bool enabled, uint256 bidStep);

    event GracePeriodSet(uint256 newGracePeriod);

    event CollectionSet(address indexed collection, bool status);

    event Blacklisted(address indexed account, bool blacklisted);

    event Boosted(address indexed account, uint256 indexed listingId, uint256 amount);

    event BoostSet(address indexed boost);

    // CONSTRUCTOR

    function initialize(address boost_, uint256 gracePeriod_) public initializer {
        gracePeriod = gracePeriod_;
        boostAccount = boost_;

        __ReentrancyGuard_init();
        __Ownable_init();
    }

    function getActiveListings(ListingType listingType) public view returns (uint256[] memory) {
        uint256[] memory list = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _lastListingId; i++) {
            if ( listings[i].claimed != true && listings[i].listingType == listingType) {
                list[index] = i;
                index++;
            }
        }
        return list;
    }

    function getLastListing(address collection, uint256 tokenId) public view returns (uint256) {
        for (uint256 i = _lastListingId; i >= 0; i--) {
            if ( listings[i].collection == collection && listings[i].tokenId == tokenId) {
                return i;
            }
        }
        revert("Token for nonexistent listing.");
    }

    function getActiveListings() public view returns (uint256[] memory) {
        uint256[] memory list = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _lastListingId; i++) {
            if ( listings[i].claimed != true ) {
                list[index] = i;
                index++;
            }
        }
        return list;
    }

    function getTokenActiveListings(address collection, uint256 tokenId) public view returns (uint256[] memory) {
        uint256[] memory list = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _lastListingId; i++) {
            if ( listings[i].claimed != true && listings[i].collection == collection && listings[i].tokenId == tokenId ) {
                list[index] = i;
                index++;
            }
        }
        return list;
    }

        function getCollectionActiveListings(address collection) public view returns (uint256[] memory) {
        uint256[] memory list = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _lastListingId; i++) {
            if ( listings[i].claimed != true && listings[i].collection == collection ) {
                list[index] = i;
                index++;
            }
        }
        return list;
    }

    function getSellerActiveListings(address seller) public view returns (uint256[] memory) {
        uint256[] memory list = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 1; i <= _lastListingId; i++) {
            if ( listings[i].claimed != true && listings[i].seller == seller ) {
                list[index] = i;
                index++;
            }
        }
        return list;
    }

    function getCollectionActiveListingsAmount(address collection) public view returns (uint256) {
        uint256 amount = 0;
        for (uint256 i = 1; i <= _lastListingId; i++) {
            if ( listings[i].claimed != true && listings[i].collection == collection ) {
                if ( listings[i].listingType == ListingType.FixedPrice ) {
                    amount += listings[i].minimalBid;
                }
                if ( listings[i].listingType == ListingType.Auction ) {
                    if ( listings[i].lastBidder == address(0)) {
                        amount += listings[i].minimalBid;
                    } else {
                        amount += listings[i].lastBid;
                    }
                }
            }
        }
        return amount;
    }

    // PUBLIC FUNCTIONS

    function createListing(
        ListingType listingType,
        address collection,
        uint256 tokenId,
        uint256 timeStart,
        uint256 timeEnd,
        IERC20Upgradeable currency,
        uint256 minimalBid,
        uint256 bidStep
    ) external returns (uint256) {
        require(!isBlacklisted[collection], "Marketplce: collection in blacklist");
        require(currencies[address(currency)].enabled, "This currency is not allowed");
        require(listingType != ListingType.None, "Listing should have a type");
        require(timeEnd > timeStart, "Sale end should be greater than sale start");


        if (timeStart == 0) timeStart = block.timestamp;
        if (bidStep == 0) bidStep = currencies[address(currency)].bidStep;

        IERC721Upgradeable(collection).transferFrom(_msgSender(), address(this), tokenId);
        return _createListing(
            listingType,
            collection,
            _msgSender(),
            tokenId,
            timeStart,
            timeEnd,
            currency,
            minimalBid,
            bidStep
        );
    }

    function buy(uint256 listingId) external nonReentrant {
        _buy(listingId);
    }

    function bid(uint256 listingId, uint256 amount) external nonReentrant {
        uint256 totalBid = amount + listings[listingId].pendingAmounts[_msgSender()];
        listings[listingId].pendingAmounts[_msgSender()] = 0;
        listings[listingId].currency.transferFrom(
            _msgSender(),
            address(this),
            totalBid
        );

        _bid(listingId, amount);
    }

    function cancel(uint256 listingId) external {
        require(listings[listingId].seller == _msgSender(), "No owned listing");
        require(block.timestamp < listings[listingId].timeStart, "Sale is started yet");
        require(listings[listingId].lastBidder == address(0), "Already purchased");

        listings[listingId].lastBidder = _msgSender();
        listings[listingId].claimed = true;
        IERC721Upgradeable(listings[listingId].collection).safeTransferFrom(address(this), _msgSender(), listings[listingId].tokenId);

        emit ListingCanceled(listingId, _msgSender());
    }

    function claimCollectible(uint256 listingId) external nonReentrant {
        require(block.timestamp >= listings[listingId].timeEnd, "Sale hasn't finished yet");
        require(!listings[listingId].claimed, "Already claimed");

        listings[listingId].claimed = true;
        activeCount--;

        address target;
        if (listings[listingId].listingType == ListingType.Auction && listings[listingId].lastBidder != address(0)) {
            target = listings[listingId].lastBidder;
            _distributeValue(listingId);
        } else {
            target = listings[listingId].seller;
        }

        IERC721Upgradeable(listings[listingId].collection).transferFrom(
            address(this),
            target,
            listings[listingId].tokenId
        );

        emit CollectibleClaimed(listingId, listings[listingId].seller, target, listings[listingId].lastBid);
    }

    function withdrawPending(uint256 listingId) external nonReentrant {
        uint256 pending = listings[listingId].pendingAmounts[_msgSender()];
        listings[listingId].pendingAmounts[_msgSender()] = 0;

        require(pending != 0, "Can't withdraw zero amount");
        _transferCurrency(listingId, _msgSender(), pending);

        emit PendingWithdrawn(listingId, _msgSender(), pending);
    }

    function boost(uint256 listingId_, uint256 amount_) external {
        require(listings[listingId_].listingType != ListingType.None, "Listing no exists");
        require(block.timestamp < listings[listingId_].timeEnd, "Sale has finished");

        listingsAdditional[listingId_].boost += amount_;
        listings[listingId_].currency.safeTransferFrom(_msgSender(), boostAccount, amount_);

        emit Boosted(_msgSender(), listingId_, amount_);
    }

    // OWNER FUNCTIONS

    function setCurrency(address currency, bool enabled, uint256 bidStep) external onlyOwner {
        require(bidStep > 0, "Bid step should be greater than zero");

        currencies[currency] = Currency({
            enabled: enabled,
            bidStep: bidStep
        });

        emit CurrencySet(currency, enabled, bidStep);
    }

    function setGracePeriod(uint256 gracePeriod_) external onlyOwner {
        gracePeriod = gracePeriod_;

        emit GracePeriodSet(gracePeriod);
    }

    function setBlacklisted(address account, bool blacklisted) external onlyOwner {
        require(isBlacklisted[account] != blacklisted, "Already in this status");
        isBlacklisted[account] = blacklisted;

        emit Blacklisted(account, blacklisted);
    }

    function setBoost(address account_) external onlyOwner {
        boostAccount = account_;

        emit BoostSet(boostAccount);
    }

    // PRIVATE FUNCTIONS

    function _createListing(
        ListingType listingType,
        address collection,
        address seller,
        uint256 tokenId,
        uint256 timeStart,
        uint256 timeEnd,
        IERC20Upgradeable currency,
        uint256 minimalBid,
        uint256 bidStep
    ) private returns (uint256) {
        require(timeStart >= block.timestamp, "Start time can not be in past");
        require(bidStep >= currencies[address(currency)].bidStep, "Bid step < minimal");

        _lastListingId++;
        activeCount++;
        listings[_lastListingId].listingType = listingType;
        listings[_lastListingId].seller = seller;
        listings[_lastListingId].collection = collection;
        listings[_lastListingId].tokenId = tokenId;
        listings[_lastListingId].timeStart = timeStart;
        listings[_lastListingId].timeEnd = timeEnd;
        listings[_lastListingId].currency = currency;
        listings[_lastListingId].minimalBid = minimalBid;

        tokenToLastListing[address(collection)][tokenId] = _lastListingId;

        emit ListingCreated(
            _lastListingId,
            address(collection),
            tokenId,
            listingType,
            timeStart,
            timeEnd,
            address(currency),
            minimalBid,
            listings[_lastListingId].seller
        );

        return _lastListingId;
    }

    function _buy(uint256 listingId) private {
        require(listings[listingId].listingType == ListingType.FixedPrice, "Buys are only for fixed price");
        require(block.timestamp >= listings[listingId].timeStart, "Sale hasn't started yet");
        require(block.timestamp < listings[listingId].timeEnd, "Sale has finished");
        require(listings[listingId].lastBidder == address(0), "Already purchased");

        listings[listingId].currency.safeTransferFrom(
            _msgSender(),
            address(this),
            listings[listingId].minimalBid
        );

        listings[listingId].lastBid = listings[listingId].minimalBid;
        listings[listingId].lastBidder = _msgSender();
        listings[listingId].claimed = true;
        IERC721Upgradeable(listings[listingId].collection).safeTransferFrom(address(this), _msgSender(), listings[listingId].tokenId);

        _distributeValue(listingId);

        emit ListingBought(listingId, _msgSender(), listings[listingId].seller, listings[listingId].minimalBid);
    }

    function _bid(uint256 listingId, uint256 amount) private {
        require(listings[listingId].listingType == ListingType.Auction, "Bids are only for auctions");
        require(block.timestamp >= listings[listingId].timeStart, "Sale hasn't started yet");
        require(block.timestamp < listings[listingId].timeEnd, "Sale has finished");
        require(
            amount >= listings[listingId].lastBid + listingsAdditional[listingId].bidStep,
            "Bid should be not less than previous plus bid step"
        );
        require(amount >= listings[listingId].minimalBid, "Bid should not be less than minimal bid");

        uint256 lastBid = listings[listingId].lastBid;
        address lastBidder = listings[listingId].lastBidder;

        listings[listingId].lastBid = amount;
        listings[listingId].lastBidder = _msgSender();
        if (listings[listingId].timeEnd - block.timestamp < gracePeriod) {
            listings[listingId].timeEnd = block.timestamp + gracePeriod;
        }

        if (lastBidder != address(0)) {
            _transferCurrency(listingId, lastBidder, lastBid);
        }

        emit ListingBid(listingId, _msgSender(), listings[listingId].seller, amount, listings[listingId].timeEnd);
    }

    function _transferCurrency(uint256 listingId, address account, uint256 amount) private {
        if (amount > 0) {
            if (address(listings[listingId].currency) == address(0)) {
                bool result = payable(account).send(amount);
                if (!result) {
                    listings[listingId].pendingAmounts[account] += amount;
                }
            } else {
                listings[listingId].currency.safeTransfer(account, amount);
            }
        }
    }

    function _distributeValue(uint256 listingId) private {
        address royaltyReceiver;
        uint256 royaltyAmount;

        if(listings[listingId].collection.supportsInterface(type(IERC2981Upgradeable).interfaceId)) {
            (royaltyReceiver, royaltyAmount) = IERC2981Upgradeable(listings[listingId].collection).royaltyInfo(listings[listingId].tokenId, listings[listingId].lastBid);
        }

        // We assume the fee destination function is safe to send
        // funds to as it is controlled by the token contract owner
        if(royaltyAmount != 0) {
            _transferCurrency(listingId, royaltyReceiver, royaltyAmount);
        }

        _transferCurrency(listingId, listings[listingId].seller, listings[listingId].lastBid - royaltyAmount);
    }

}