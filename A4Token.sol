
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/access/Ownable.sol";



contract A4Token is
    ERC20Capped,
    Ownable
    {

    constructor(uint256 cap)
        public
        ERC20("A4", "A4")
        ERC20Capped(cap)
    {
    }

    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    function mint(address account, uint256 amount) public onlyOwner
    {
        _mint(account, amount);
    }
}