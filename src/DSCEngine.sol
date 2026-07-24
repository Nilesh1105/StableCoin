//SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";

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
    error DSCEngine__BreaksHealthFactor(uint256 _healthFactorOfTheUser);
    error DSCEngine__DSCMintFailed();

    ////////////////////////////////////////
    //state variable                      //
    ////////////////////////////////////////
    mapping(address token => address priceFeed) private s_tokenToPriceFeed;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_dscMinted;
    address[] private s_collateralTokens;

    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    DecentralizedStableCoin private immutable i_dsc;

    ////////////////////////////////////////
    //event                               //
    ////////////////////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 collateralAmount);
    event CollateralRedeemed(address indexed user, address indexed token, uint256 collateralRedeemed);

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
    constructor(address[] memory _tokenAddresses, address[] memory _priceFeedAddresses, address _dscAddress) {
        if (_tokenAddresses.length != _priceFeedAddresses.length) {
            revert DSCEngine__LengthOfTokenAddressMustBeSameAsLengthOfPriceFeedAddress();
        }

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            s_tokenToPriceFeed[_tokenAddresses[i]] = _priceFeedAddresses[i];
            s_collateralTokens.push(_tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(_dscAddress);
    }

    ////////////////////////////////////////
    //external functions                  //
    ////////////////////////////////////////
    /**
     * With the help of below function, a user is able to deposit the collateral.
     * @param _collateralTokenAddress is the address of the token which he want to deposit as a collateral.
     * @param _collateralAmount is the collateral amount.
     */

    function depositCollateralAndMintDsc(
        address _collateralTokenAddress,
        uint256 _collateralAmount,
        uint256 _dscAmountToMint
    ) external {
        depositCollateral(_collateralTokenAddress, _collateralAmount);
        mintDsc(_dscAmountToMint);
    }

    /**
     * @notice Burns DSC and redeem collateral in a single transaction.
     * @notice Burning DSC before redeeming the collateral improves users 'healthFactor' which makes redemption of minted DSC easy.
     * @param _dscAmountToBurn is the amount of DSC which we want to burn.
     * @param _collateralTokenAddress Address of the collateral token.
     * @param _redemptionAmount Amount of the collateral token.
     */
    function burnDscAndRedeemCollateral(
        uint256 _dscAmountToBurn,
        address _collateralTokenAddress,
        uint256 _redemptionAmount
    ) external {
        burnDsc(_dscAmountToBurn);
        redeemCollateral(_collateralTokenAddress, _redemptionAmount);
    }

    ////////////////////////////////////////
    //public functions                    //
    ////////////////////////////////////////
    /**
     * With the help of this function, a user is able to deposit the collateral & mint DSC in a single transection.
     * @param _collateralTokenAddress is the address of the token which he want to deposit as a collateral.
     * @param _collateralAmount is the collateral amount.
     */
    function depositCollateral(address _collateralTokenAddress, uint256 _collateralAmount)
        public
        checkAddressIsValid(_collateralTokenAddress)
        checkAmountIsValid(_collateralAmount)
    {
        if (s_tokenToPriceFeed[_collateralTokenAddress] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        s_collateralDeposited[msg.sender][_collateralTokenAddress] += _collateralAmount;

        bool tokenTransferSuccess =
            IERC20(_collateralTokenAddress).transferFrom(msg.sender, address(this), _collateralAmount);
        if (!tokenTransferSuccess) {
            revert DSCEngine__TokenTransferFailed();
        }

        emit CollateralDeposited(msg.sender, _collateralTokenAddress, _collateralAmount);
    }

    /**
     * With the help of this function, we are able to mint DSC against our collateral.
     * @notice follows CEI
     * @param _dscAmountToMint is used to enter the amount to mint DSC.
     * @notice User always must have more collateral value than the minimum threshold.
     */
    function mintDsc(uint256 _dscAmountToMint) public checkAmountIsValid(_dscAmountToMint) {
        s_dscMinted[msg.sender] += _dscAmountToMint;

        _revertIfHealthFactorIsBroken(msg.sender);

        bool minted = i_dsc.mint(msg.sender, _dscAmountToMint);
        if (!minted) {
            revert DSCEngine__DSCMintFailed();
        }
    }

    /**
     * This function is used to redeem the collateral which is deposited by the user.
     * @notice while doing redemption, a user must need to have his 'healthFactor' more than our requirement
     * @param _collateralTokenAddress is the address of the token which we want to redeem.
     * @param _redemptionAmount is the amount of the token.
     */
    function redeemCollateral(address _collateralTokenAddress, uint256 _redemptionAmount)
        public
        checkAddressIsValid(_collateralTokenAddress)
        checkAmountIsValid(_redemptionAmount)
    {
        s_collateralDeposited[msg.sender][_collateralTokenAddress] -= _redemptionAmount;
        emit CollateralRedeemed(msg.sender, _collateralTokenAddress, _redemptionAmount);

        bool success = IERC20(_collateralTokenAddress).transfer(msg.sender, _redemptionAmount);
        if (!success) {
            revert DSCEngine__TokenTransferFailed();
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Burns the specified amount of DSC from the caller.
     * The caller must approve this contract to spend the DSC first.
     * @param _dscAmountToBurn Amount of DSC to burn.
     */
    function burnDsc(uint256 _dscAmountToBurn) public checkAmountIsValid(_dscAmountToBurn) {
        s_dscMinted[msg.sender] -= _dscAmountToBurn;

        bool success = IERC20(i_dsc).transferFrom(msg.sender, address(this), _dscAmountToBurn);
        if (!success) {
            revert DSCEngine__TokenTransferFailed();
        }

        i_dsc.burn(_dscAmountToBurn);
    }

    ////////////////////////////////////////
    //private function                   //
    ////////////////////////////////////////
    /**
     * @notice This functions is used to check our health factor.
     * Minted DSC exceeds the minimum threshold, then we will revert.
     * @param _user is the address of the the user.
     */
    function _revertIfHealthFactorIsBroken(address _user) private view {
        uint256 userHealthFactor = _healthFactor(_user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /**
     * This functions returns how close to liquidation a user is?
     * If user goes below 1, then they can get liquidated.
     * @param _user is the address of the user for which we want to know the current health factor.
     *
     */
    function _healthFactor(address _user) private view returns (uint256) {
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(_user);
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    /**
     * In this function, we will get the 'amount of dsc' & 'collateral value in usd' for a specific user.
     * @param _user is the address of the user for which we want to get the data.
     * @return totalDscMinted is the 'dsc minted' by the specific user.
     * @return collateralValueInUsd is the total 'collateral amount in usd' of that user.
     */
    function _getAccountInformation(address _user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_dscMinted[_user];
        collateralValueInUsd = getAccountCollateralValue(_user);
    }

    /////////////////////////////////////////////
    //public & external - view & pure functions//
    /////////////////////////////////////////////
    /**
     * @notice In this function we will get the price feed address for the specific user.
     * @param _tokenAddress is the address for which we want to get the price feed.
     */
    function getPriceFeed(address _tokenAddress) external view returns (address) {
        return s_tokenToPriceFeed[_tokenAddress];
    }

    /**
     * @notice In this function we are able to convert collateral value for all tokens which are deposited by the user in USD.
     * @param _user is the address of the user for which we want the data.
     * @return totalCollateralValueInUsd is the value of the all of the deposited collateral in USD.
     */
    function getAccountCollateralValue(address _user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[_user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /**
     * @notice we convert the collateral value in usd.
     * @param _token is the address of the token for which we want to convert it in USD.
     * @param _amount is the amount of the token.
     * @return .the total calculated value of the token in terms of USD.
     */
    function getUsdValue(address _token, uint256 _amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_tokenToPriceFeed[_token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * _amount) / PRECISION;
    }
}
