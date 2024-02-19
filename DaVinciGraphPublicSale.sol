// SPDX-License-Identifier: MIT
// Specifies the license under which the code is distributed (MIT License).

// Website: davincigraph.io

// Compiler Version
pragma solidity ^0.8.9;

// Imports the SafeHTS library, which provides methods for safely interacting with Hedera Token Service (HTS).
import "./hedera/SafeHTS.sol";

// Imports the DaVinciGraph Sales base contract
import "./DaVinciGraphSales.sol";

contract DaVinciGraphPublicSale is DaVinciGraphSales {
	// Investors would not be able to reserve more than this amount
    int64 public constant MAXIMUM_RESERVING_AMOUNT = 500_000e9; // 500K DAVINCIs

	// Investors allocation of DaVinci Token structure
	struct InvestorTokenAllocation {
		int64 reservedAmount;
		bool hasWithdrawn;
	}

    // Initialize davinciToken info and association, and schedule info
    constructor(int64 _totalAmount, address _davinciToken, address _treasuryAccount, uint256 _startTime, uint256 _endTime, uint256 _withdrawTime){
        // Set the Davinci token info
		davinciToken = DAVINCIToken(_davinciToken, _treasuryAccount, 1e9, 3e4);

		// Set the schedule 
        schedule = Schedule(_startTime, _endTime, _withdrawTime);

		// Set the total Davinci amount for sale
        totalAmount = _totalAmount;

		// Asociate Davinci token address to the contract
        SafeHTS.safeAssociateToken(_davinciToken, address(this));

		// Set max withdraw time, which means owner won't be able to postpone withdraw time from this point further
        maxWithdrawTime = block.timestamp + (3 * 30 days);

		// Log this deployment
        emit Deployed(_davinciToken, _treasuryAccount, _totalAmount, _startTime, _endTime, _withdrawTime, maxWithdrawTime);
    }

	// State of investors token allocation
	mapping(address => InvestorTokenAllocation) public investorsTokenAllocation;

    /* ============================== Investors Functionalities ========================== */

    // Reserve DAVINCI token, (An Investor can pay the price for whatever amount up to 500K Davincis )
	// The reserved amount will be securely held for the user until the designated withdrawal date, at which point he will be able to withdraw
	function reserve(int64 reservingDavinciAmount, address paymentTokenAddress, address futurePairToken) external nonReentrant{
        // If public sale is not started, reject
        require(block.timestamp >= schedule.startTime, "Cannot reserve yet, Public sale is not started");
        
        // If public sale is over, reject
        require(block.timestamp < schedule.endTime, "Cannot reserve anymore, Public sale is over");

		// The minimum buy allowance in public sale is equal to 1 solid unit of Davinci token
		require(reservingDavinciAmount >= uint256Toint64(davinciToken.solidUnit), "Minimum buy allowance is 1 DAVINCIs");

		// Each investor can only buy up to 500K DAVINCIs in public sale
		require(reservingDavinciAmount <= MAXIMUM_RESERVING_AMOUNT, "Maximum buy allowance per investor is 1 million DAVINCIs");

        // Reserving requested amount must not exceed the total selling amount
        require(totalReservedAmount + reservingDavinciAmount <= totalAmount, "These amount of DAVINCI is not left to reserve");

		// Ensure that the token selected by the user for payment is included in the list of acceptable payment tokens
		require(paymentTokens[paymentTokenAddress].decimals > 0, "The token you want to pay in is not acceptable");

		// Ensure that the future pair token selected by the user is included in the list of acceptable future pair tokens
		require(futurePairTokens[futurePairToken].isAcceptable == true, "Not an acceptable future pair token");

		// Callculate the DAVINCI token amount which user allowed to buy
        int64 amountAllowedToBuy = MAXIMUM_RESERVING_AMOUNT - investorsTokenAllocation[msg.sender].reservedAmount;

		// Reject if the amount of DAVINCI he requested is higher than what he allowed to
        require(reservingDavinciAmount <= amountAllowedToBuy, "You are not allowed to buy this much");

		// Calculate the amount of payment tokens (which all are USD wrappers) which user actually need to pay to reserve the DAVINCIs
		int64 usdAmount = tinyDAVINCIsToTinyUSDs(reservingDavinciAmount);

		// Transfer the payment tokens (usd) from user account to the contract
		SafeHTS.safeTransferToken(paymentTokenAddress, msg.sender, address(this), usdAmount);

		// Add the amount user just paid for to his reserved amount
		investorsTokenAllocation[msg.sender].reservedAmount = investorsTokenAllocation[msg.sender].reservedAmount + reservingDavinciAmount;

		// Add the amount user just paid for to the contract total reserved amount
		totalReservedAmount = totalReservedAmount + reservingDavinciAmount;

		// Mark the future pair token as used
		futurePairTokens[futurePairToken].isUsed = true;

        // Add the usd amount to the payment token collected amount
        paymentTokens[paymentTokenAddress].collectedAmount = paymentTokens[paymentTokenAddress].collectedAmount + usdAmount;

		// Log this reservation
		emit Reserved(msg.sender, paymentTokenAddress, reservingDavinciAmount, usdAmount, futurePairToken);
	}

	// Withdraw
	function withdrawReservedAmount(address investor) external nonReentrant{
        // Investors only can withdraw when the schedule allows to
        require(block.timestamp >= schedule.withdrawTime, "It is not withdraw time yet");
		
        // Investor account id must be provided
        require(investor != address(0), "Investor address must be provided");

        // Investor address must be in the list
		require(investorsTokenAllocation[investor].reservedAmount > 0, "You are not an investor");

        // Investor already has withdrawn his reserved amount
		require(investorsTokenAllocation[investor].hasWithdrawn == false, "You have withdrawn your reserved amount");
		
        // Transfer the withdrawing amount to his account
        SafeHTS.safeTransferToken(davinciToken.tokenAddress, address(this), investor, investorsTokenAllocation[investor].reservedAmount);

        // Mark the investor allocation as withdrawn
        investorsTokenAllocation[investor].hasWithdrawn = true;
		
        // Log his withdrawal
		emit ReservedAmountWithdrawn(investor, investorsTokenAllocation[investor].reservedAmount);
	}

	// get a specific Investor allocation info
	function getInvestorTokenAllocation(address investor) public view returns (InvestorTokenAllocation memory) {
		return investorsTokenAllocation[investor];
	}
}