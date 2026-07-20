//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {ERC20, ERC20Burnable} from "@openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title : DecentralizedStableCoin
 * @author : Nilesh Shinde
 *
 * This is the contract meant to be governed by DSCEngine.
 * This contract is just ERC20 implementation of our stable coin system.
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    ////////////////////////////////////////
    // Errors                             //
    ////////////////////////////////////////
    error DecentralizedStableCoin__AddressIsZero();
    error DecentralizedStableCoin__AmountIsZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();

    ////////////////////////////////////////
    // Functions                          //
    ////////////////////////////////////////
    constructor() ERC20("DecentralizedStableCoin", "DSC") Ownable(msg.sender) {}

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralizedStableCoin__AddressIsZero();
        }

        if (_amount == 0) {
            revert DecentralizedStableCoin__AmountIsZero();
        }

        _mint(_to, _amount);

        return true;
    }

    function burn(uint256 _amount) public override onlyOwner {
        if (_amount == 0) {
            revert DecentralizedStableCoin__AmountIsZero();
        }

        uint256 balance = balanceOf(msg.sender);

        if (balance < _amount) {
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }
}
