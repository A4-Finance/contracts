// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/CountersUpgradeable.sol";

contract NFTProfile is Initializable, ERC721URIStorageUpgradeable, OwnableUpgradeable {
    using CountersUpgradeable for CountersUpgradeable.Counter;
    CountersUpgradeable.Counter private _tokenIds;

    mapping (address => uint256) lastTokens;

    function initialize(string memory name, string memory symbol) initializer public {
        __ERC721_init(name, symbol);
        __Ownable_init();
    }

    function mint(address _to, string memory _tokenURI) public {
        require(_msgSender() == _to, "NFTProfile: only self minting.");

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();
        _mint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        lastTokens[_to] = tokenId;
    }

    function lastTokenOf(address user) public view returns (uint256) {
        return lastTokens[user];
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        if (from != address(0)) {
            require(owner() == _msgSender(), "Ownable: caller is not the owner");
        }
        super._beforeTokenTransfer(from, to, tokenId);
    }

}
