// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

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
    //Errors                              //
    ////////////////////////////////////////
    error DecentralizedStableCoin__AddressIsZero();
    error DecentralizedStableCoin__AmountIsZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();

    ////////////////////////////////////////
    //functions                           //
    ////////////////////////////////////////
    constructor(address _owner) ERC20("DecentralizedStableCoin", "DSC") Ownable(_owner) {}

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
}
