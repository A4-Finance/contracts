// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin-upgradeable/contracts/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol';
import '@openzeppelin-upgradeable/contracts/interfaces/IERC2981Upgradeable.sol';
import "@openzeppelin-upgradeable/contracts/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract A4ERC721Common is OwnableUpgradeable, ERC721URIStorageUpgradeable, IERC2981Upgradeable {

    using SafeMathUpgradeable for uint256;

    event Minted(uint256 tokenId, string tokenUri, address minter);
    event Burned(uint256 tokenId, address burner);

    uint256 public _latestTokenId;
    mapping(uint256 => address) royaltyReceiver;
    mapping(uint256 => uint16) royaltyPercentage;

    uint256 constant denominator = 1000;

    function initialize(string memory name, string memory symbol) initializer public {
        __ERC721_init(name, symbol);
        __Ownable_init();
    }

    /**
     * @notice Validates user is authorized for token manipulation
     * @param tokenId The token identifier
     */
    modifier tokenAuth(uint256 tokenId) {
        address owner = ownerOf(tokenId);
        address operator = _msgSender();
        require(
            owner == operator || getApproved(tokenId) == operator || isApprovedForAll(owner, operator),
            "ERC721Collection: only owner or approved can manipulate with token"
        );
        _;
    }

    function mint(string calldata _tokenUri, uint16 _royaltyPercentage) public {
        require(bytes(_tokenUri).length > 0, "Token URI for minting is empty");
        require(_royaltyPercentage <= denominator, "Royalty too big");

        _latestTokenId = _latestTokenId.add(1);
        uint256 tokenId = _latestTokenId;

        address signer = _msgSender();
        _safeMint(signer, tokenId);
        _setTokenURI(tokenId, _tokenUri);
        royaltyReceiver[tokenId] = signer;
        royaltyPercentage[tokenId] = _royaltyPercentage;

        emit Minted(tokenId, _tokenUri, signer);
    }

    function burn(uint256 tokenId) external tokenAuth(tokenId) {
        _burn(tokenId);
        emit Burned(tokenId, _msgSender());
    }

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) 
    override external view 
    returns (address receiver, uint256 royaltyAmount) {
        return (
        royaltyReceiver[_tokenId],
        _salePrice * royaltyPercentage[_tokenId] / denominator
        );
    }

    function ownerOfBatch(uint256[] memory ids)
        public
        view
        returns (address[] memory)
    {
        address[] memory batchOwners = new address[](ids.length);

        for (uint256 i = 0; i < ids.length; ++i) {
            try this.ownerOf(ids[i]) returns (address v) {
                batchOwners[i] = v;
            } catch Error(string memory /*reason*/) {
                batchOwners[i] = address(0);
            }
        }

        return batchOwners;
    }



    function supportsInterface(bytes4 interfaceId) override(ERC721Upgradeable, IERC165Upgradeable) public view returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _resetTokenRoyalty(uint256 tokenId) internal {
        delete royaltyReceiver[tokenId];
        delete royaltyPercentage[tokenId];
    }

}