// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin-upgradeable/contracts/utils/ContextUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "./A4ERC1155.sol";

/// @title Factory contract for deployment of ERC721 collections
contract ERC1155CollectionFactory is ContextUpgradeable, OwnableUpgradeable {

    mapping(address => bool) public isTrustedForwarder;
    address[] public collections;

    /// @notice Events of the contract
    event ERC1155CollectionCreated(address indexed creator, address nft, string name, string uri);

    function initialize(string memory url) initializer public {
        __Ownable_init();
    }

    function getCollections() public view returns (address[] memory) {
        return collections;
    }

    /// @notice Method for deploy new ERC721Collection contract
    /// @param name Name of NFT collection
    /// @param symbol Symbol of NFT collection
    /// @return nftCollectionAddress Address of newly created ERC721 collection
    function createERC1155Collection(
        string memory name,
        string memory symbol,
        string memory contractURI
    ) external returns (address) {

        A4ERC1155 nftCollection = new A4ERC1155(
            name,
            symbol,
            contractURI
        );
        nftCollection.transferOwnership(msg.sender);

        address nftCollectionAddress = address(nftCollection);
        collections.push(nftCollectionAddress);
        emit ERC1155CollectionCreated(_msgSender(), nftCollectionAddress, name, contractURI);
        return nftCollectionAddress;
    }

    function setForwarder(address forwarder, bool valid) external onlyOwner() {
        isTrustedForwarder[forwarder] = valid;
    }

    function _msgSender() internal override view returns (address) {
        address signer = msg.sender;
        if (msg.data.length >= 20 && isTrustedForwarder[signer]) {
            assembly {
                signer := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        }
        return signer;
    }
}
