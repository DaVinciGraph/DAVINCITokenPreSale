// SPDX-License-Identifier: MIT
// Specifies the license under which the code is distributed (MIT License).

// Website: davincigraph.io

// Compiler Version
pragma solidity ^0.8.9;

// Imports the SafeHTS library, which provides methods for safely interacting with Hedera Token Service (HTS).
import "./hedera/SafeHTS.sol";

// Imports the DaVinciGraph Sales base contract
import "./DaVinciGraphSales.sol";

contract DaVinciGraphPrivateSale is DaVinciGraphSales {
	// Investors would not be able to reserve less than this amount
	int64 public constant MINIMUM_RESERVING_AMOUNT = 2300e9;

	// Investors allocation of DaVinci Token structure
	struct InvestorTokenAllocation {
		int64 buyAllowanceAmount;
		int64 reservedAmount;
		bool hasWithdrawn;
	}

    // Initialize davinciToken info and association, and schedule info
    constructor(address _davinciToken, address _treasuryAccount, uint256 _startTime, uint256 _endTime, uint256 _withdrawTime){
        // Set the Davinci token info
		davinciToken = DAVINCIToken(_davinciToken, _treasuryAccount, 1e9, 1e4);

		// Set the schedule 
        schedule = Schedule(_startTime, _endTime, _withdrawTime);

		// Set the total Davinci amount for sale
        totalAmount = 30_000_000e9; // 30M DaVinci Token

		// Asociate Davinci token address to the contract
        SafeHTS.safeAssociateToken(_davinciToken, address(this));

		// Set max withdraw time, which means owner won't be able to postpone withdraw time from this point further
        maxWithdrawTime = block.timestamp + (4 * 30 days);

		// Log this deployment
        emit Deployed(_davinciToken, _treasuryAccount, totalAmount, _startTime, _endTime, _withdrawTime, maxWithdrawTime);
    }

	// State of investors token allocation
	mapping(address => InvestorTokenAllocation) public investorsTokenAllocation;

    /* ============================== Investors Functionalities ========================== */

    // Reserve DAVINCI token, (An Investor can pay the price for whatever amount he is allow to)
	// The reserved amount will be securely held for the user until the designated withdrawal date, at which point he will be able to withdraw
	function reserve(int64 reservingDavinciAmount, address paymentTokenAddress, address futurePairToken) external nonReentrant{
        // If private sale is not started, reject
        require(block.timestamp >= schedule.startTime, "Cannot reserve yet, Private sale is not started");
        
        // If private sale is over, reject
        require(block.timestamp < schedule.endTime, "Cannot reserve anymore, Private sale is over");

		// The minimum amount is equal to the lowest buying allowance of a bronze nft which is 2300 davinci tokens
		require(reservingDavinciAmount >= MINIMUM_RESERVING_AMOUNT, "Minimum davinci amount to reserve is 2300");

        // Reserving requested amount must not exceed the total selling amount
        require(totalReservedAmount + reservingDavinciAmount <= totalAmount, "Total reserve amount will exceed total amount");

		// Ensure that the token selected by the user for payment is included in the list of acceptable payment tokens
		require(paymentTokens[paymentTokenAddress].decimals > 0, "The token you want to pay in is not acceptable");

		// Ensure that the future pair token selected by the user is included in the list of acceptable future pair tokens
		require(futurePairTokens[futurePairToken].isAcceptable == true, "Not an acceptable future pair token");

		// User must be an investor to be able to reserve DAVINCIs
		require(investorsTokenAllocation[msg.sender].buyAllowanceAmount > 0, "You haven not been added as an investor");

		// Callculate the DAVINCI token amount which user allowed to buy
		int64 amountAllowedToBuy = investorsTokenAllocation[msg.sender].buyAllowanceAmount - investorsTokenAllocation[msg.sender].reservedAmount;

		// Reject if the amount of DAVINCI he requested is higher than what he allowed to
		require(reservingDavinciAmount <= amountAllowedToBuy, "You are not allowed to buy this much");

        // Calculate the amount which remains unreserved after this reservation
        int64 unreservedAmountAfterThis = amountAllowedToBuy - reservingDavinciAmount;

        // If nothing remained or the remaining is greater or equal to 2300, allow the investor to reserve
        require( unreservedAmountAfterThis >= MINIMUM_RESERVING_AMOUNT || unreservedAmountAfterThis == 0, "Reserving this amount result in unreseved of less than 2300 davinci");

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
		require(investorsTokenAllocation[investor].buyAllowanceAmount > 0, "You are not an investor");

        // Investor already has withdrawn his reserved amount
		require(investorsTokenAllocation[investor].hasWithdrawn == false, "You have withdrawn your reserved amount");
		
        // Transfer the withdrawing amount to his account
        SafeHTS.safeTransferToken(davinciToken.tokenAddress, address(this), investor, investorsTokenAllocation[investor].reservedAmount);

        // Mark the investor allocation as withdrawn
        investorsTokenAllocation[investor].hasWithdrawn = true;
		
        // Log his withdrawal
		emit ReservedAmountWithdrawn(investor, investorsTokenAllocation[investor].reservedAmount);
	}

    /* ============================== Owner Functionalities ===================== */

	// Insert an account as an investor with a specific buy allowance amount
    function addInvestorTokenAllocation(address investor, int64 amount) external onlyOwner {
		// Investor account is rquired
        require(investor != address(0), "Investor Account must be provided");

        // Amount is required
		require(amount > 0, "The amount which the investor is allowed to buy must be bigger than zero");

        // Investor must not be added before
		require(investorsTokenAllocation[investor].buyAllowanceAmount == 0, "Investor is already added");

        // Add investors davinci token allocation to the list
		investorsTokenAllocation[investor] = InvestorTokenAllocation(amount, 0, false);

        // Log his addition
		emit InvestorTokenAllocationAdded(investor, amount);
	}

	// Increase an investors buy allowance amount
    function increaseInvestorBuyAllowance(address investor, int64 extraAmount) external onlyOwner {
		// Investor account is required
        require(investor != address(0), "Investor Account must be provided");

        // Extra reserving amount is required
		require(extraAmount > 0, "The extra amount which the investor is allowed to buy must be bigger than zero");

        // Investor is not in the list
		require(investorsTokenAllocation[investor].buyAllowanceAmount > 0, "Not an investor");

        // Add the extra amount to the investor buy allowance
		investorsTokenAllocation[investor].buyAllowanceAmount = investorsTokenAllocation[investor].buyAllowanceAmount + extraAmount;
	
        // Log the increasing
		emit InvestorBuyAllowanceAmountIncreased(investor, extraAmount);
	}

    /* ============================= public Query the structs ========================= */

	// Get a specific Investor allocation info
	function getInvestorTokenAllocation(address investor) public view returns (InvestorTokenAllocation memory) {
		return investorsTokenAllocation[investor];
	}

	event InvestorTokenAllocationAdded(address indexed investor, int64 buyAllowanceAmount);
	event InvestorBuyAllowanceAmountIncreased(address indexed investor, int64 extraAmount);
}