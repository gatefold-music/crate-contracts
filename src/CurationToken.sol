// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract CurationToken is ERC20Upgradeable, OwnableUpgradeable {

    // Initializes factory
    function initialize(string memory _name, string memory _symbol, address _owner) initializer public {
        __ERC20_init(_name, _symbol);
        __Ownable_init(_owner);
    }
    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }

    function approveForOwner(address _owner, address _spender) public onlyOwner {
        _approve(_owner, _spender, type(uint256).max);
    }

    function maxApproval(address _spender) public {
        _approve(msg.sender, _spender, type(uint256).max);
    }

    function burn(address _account, uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "Must own correct amount of tokens");
        _burn(_account, _amount);
    }
}
