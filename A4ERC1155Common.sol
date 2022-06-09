// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract A4ERC1155Common is ERC1155SupplyUpgradeable, ERC1155BurnableUpgradeable, IERC2981Upgradeable, OwnableUpgradeable {

    using SafeMathUpgradeable for uint256;

    event Minted(uint256 tokenId, string tokenUri, address minter, uint256 tokenQty);
    event Burned(address burner, uint256 tokenId, uint256 amount);

    string private _name;
    string private _symbol;

    uint256 public _latestTokenId;
    mapping(uint256 => address) royaltyReceiver;
    mapping(uint256 => uint16) royaltyPercentage;
    mapping(uint256 => string) private _tokenUri;

    uint256 constant denominator = 1000;

    function initialize(string memory name, string memory symbol) initializer public {
        __ERC1155_init("");
        __Ownable_init();
        _name = name;
        _symbol = symbol;
    }

    function mint(string calldata _uri, uint256 _tokenQty, uint16 _royaltyPercentage, bytes memory data) public {
        require(bytes(_uri).length > 0, "Token URI for minting is empty");
        require(_royaltyPercentage <= denominator, "Royalty too big");

        _latestTokenId = _latestTokenId.add(1);
        uint256 tokenId = _latestTokenId;

        address signer = _msgSender();
        _mint(signer, tokenId, _tokenQty, data);
        royaltyReceiver[tokenId] = signer;
        royaltyPercentage[tokenId] = _royaltyPercentage;
        _tokenUri[tokenId] = _uri;

        emit Minted(tokenId, _uri, signer, _tokenQty);
    }

    function burn(address account, uint256 tokenId, uint256 value) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        _burn(account, tokenId, value);
        emit Burned(account, tokenId, value);
    }

    function uri(uint256 id) public view override returns (string memory) {
        return _tokenUri[id];
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }


    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) 
    override external view 
    returns (address receiver, uint256 royaltyAmount) {
        return (
        royaltyReceiver[_tokenId],
        _salePrice * royaltyPercentage[_tokenId] / denominator
        );
    }


    function supportsInterface(bytes4 interfaceId) override(ERC1155Upgradeable, IERC165Upgradeable) public view returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _resetTokenRoyalty(uint256 tokenId) internal {
        delete royaltyReceiver[tokenId];
        delete royaltyPercentage[tokenId];
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function nullableBalanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            try this.balanceOf(accounts[i], ids[i]) returns (uint256 v) {
                batchBalances[i] = v;
            } catch Error(string memory /*reason*/) {
                batchBalances[i] = 0;
            }
        }

        return batchBalances;
    }

}