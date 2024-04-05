// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract CurationToken is ERC20, Initializable, Ownable {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    /// Initializes factory
    // function initialize(string memory _name, string memory _symbol) public initializer {
    //     ERC20.initialize(_name, _symbol);
    // }
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