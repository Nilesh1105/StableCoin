//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/**
 * @title DSCEngine
 * @author Nilesh Shinde
 * @notice This system maintains the 1 DSC coin == $1 peg for all of the time.
 * It is similar to DAI, if DAI have no Governance, no Fees and was backed by only wBTC and wETH.
 * Our DSC system should always be "overcollateralized". At no point, should the value of allCollateral < the $ backed value of all
 * DSC.
 * @notice This contracts is the code of Decentralized StableCoin system. It handles all logic for minting and redeeming DSC, as
 * well as depositing and withdrawing collateral.
 */
contract DSCEngine {
    ////////////////////////////////////////
    //error                               //
    ////////////////////////////////////////
    error DSCEngine__InvalidAddress();
    error DSCEngine__InvalidAmount();
    error DSCEngine__LengthOfTokenAddressMustBeSameAsLengthOfPriceFeedAddress();
    error DSCEngine__TokenTransferFailed();
    error DSCEngine__TokenNotAllowed();

    ////////////////////////////////////////
    //state variable                      //
    ////////////////////////////////////////
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_userToTokenAmount;

    ////////////////////////////////////////
    //event                               //
    ////////////////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 collateralAmount);

    ////////////////////////////////////////
    //modifier                            //
    ////////////////////////////////////////
    modifier checkAddressIsValid(address _address) {
        if (_address == address(0)) {
            revert DSCEngine__InvalidAddress();
        }
        _;
    }

    modifier checkAmountIsValid(uint256 _amount) {
        if (_amount == 0) {
            revert DSCEngine__InvalidAmount();
        }
        _;
    }

    ////////////////////////////////////////
    //functions                           //
    ////////////////////////////////////////
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses) {
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__LengthOfTokenAddressMustBeSameAsLengthOfPriceFeedAddress();
        }

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_tokenToPriceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];
        }
    }

    ////////////////////////////////////////
    //external functions                  //
    ////////////////////////////////////////
    /**
     * With the help of below function, a user is able to deposit the collateral.
     * @param _collateralTokenAddress is the address of the token which he want to deposit as a collateral.
     * @param _collateralAmount is the collateral amount.
     */
    function depositCollateral(address _collateralTokenAddress, uint256 _collateralAmount)
        external
        checkAddressIsValid(_collateralTokenAddress)
        checkAmountIsValid(_collateralAmount)
    {
        if (s_tokenToPriceFeed[_collateralTokenAddress] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        s_userToTokenAmount[msg.sender][_collateralTokenAddress] += _collateralAmount;

        bool tokenTransferSuccess =
            IERC20(_collateralTokenAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!tokenTransferSuccess) {
            revert DSCEngine__TokenTransferFailed();
        }

        emit CollateralDeposited(msg.sender, _collateralTokenAddress, _collateralAmount);
    }

    /////////////////////////////////////////////
    //public & external - view & pure functions//
    /////////////////////////////////////////////
    function getPriceFeed(address _tokenAddress) external view returns (address) {
        return s_tokenToPriceFeed[_tokenAddress];
    }
}
