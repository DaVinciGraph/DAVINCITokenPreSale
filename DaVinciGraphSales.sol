// SPDX-License-Identifier: MIT
// Specifies the license under which the code is distributed (MIT License).

// Website: davincigraph.io

// Compiler Version
pragma solidity ^0.8.9;

// Imports the SafeHTS library, which provides methods for safely interacting with Hedera Token Service (HTS).
import "./hedera/SafeHTS.sol";

// Imports the ReentrancyGuard and ownable contracts from the OpenZeppelin Contracts package, which helps protect against reentrancy attacks.
import "./openzeppelin/ReentrancyGuard.sol";
import "./openzeppelin/Ownable.sol";

contract DaVinciGraphSales is Ownable, ReentrancyGuard {
    // This will prevent indefinite prolongation of the withdrawal period
    uint256 public maxWithdrawTime;

    // Total selling amount
	int64 public totalAmount;

    // total reserved amount
	int64 public totalReservedAmount = 0;

    // Structure of davinci token, its treasury account, solid unit and price
    struct DAVINCIToken {
        address tokenAddress;
        address treasuryAccount;
        uint256 solidUnit; // 1 solid unit of DAVINCI TOKEN
	    uint256 price; // in (USDC,USDC[hts],USDT[hts]), $0.01 in private sale, $0.03 in public sale
    }

    // Holding the timing of the event and required actions
    struct Schedule {
        uint256 startTime;
        uint256 endTime;
        uint256 withdrawTime;
    }

	// Structure of payment tokens (USDC,USDC[hts],USDT[hts])
	struct PaymentTokens {
		string symbol;
		uint256 decimals;
		int64 collectedAmount;
	}

	// Structure of future pair tokens
	struct FuturePairTokens {
		string symbol;
        int64 fixedSharePercentage;
		bool isUsed;
        bool isAcceptable;
	}

    // State of davinci token
    DAVINCIToken public davinciToken;

    // State of the schedule
    Schedule public schedule;

	// State of payment tokens
	mapping(address => PaymentTokens) public paymentTokens;

	// State of future pair tokens
	mapping(address => FuturePairTokens) public futurePairTokens;

    /* =============================== Owner Functionalities ===================== */

	// Withdraw remainder of sale davinci token amount to treasury
	function withdrawRemainderOfDavincis() external onlyOwner {
        // Owner only can withdraw the remainder amount when the sale is over
		require(block.timestamp >= schedule.endTime, "Sale event is not over yet");

        // Calculate the remainder of Davinci tokens which are not reserved
		int64 remainder = totalAmount - totalReservedAmount;

        // Reject if there is no remainder
        require(remainder > 0, "There is no remainder of DAVINCIs"); 
		
        // Transfer the remainder Davinci tokens to the treasury account
		SafeHTS.safeTransferToken(davinciToken.tokenAddress, address(this), davinciToken.treasuryAccount, remainder);

        // Apply the withdrawal to total selling amount
        totalAmount = totalReservedAmount;

        // Log the withdrawal
		emit DavinciRemainderWithdrawn(davinciToken.treasuryAccount, remainder);
	}

	// Withdraw the collected usd amounts
	function withdrawPaymentToken(address token) external onlyOwner {
        // Payment token is required
        require(token != address(0), "Payment token address must be provided");

        // Owner only can withdraw the usd amount when the sale is over
		require(block.timestamp >= schedule.endTime, "Sale event is not over yet");

        // Payment token must have any amount to be withdrawn
        require(paymentTokens[token].collectedAmount > 0, "This payment token has no amount to be withdrawn");
		
        // Get the withdrable amount of the payment token
        int64 withdrawingAmount = paymentTokens[token].collectedAmount;

        // Transfer the amount to the treasury account
		SafeHTS.safeTransferToken(token, address(this), davinciToken.treasuryAccount, withdrawingAmount);

        // Set the collected amount of the token to zero
        paymentTokens[token].collectedAmount = 0;

        // Log the withdrawal
		emit RaisedFundWithdrawn(token, davinciToken.treasuryAccount, withdrawingAmount);
	}

    // Add a payment token to the list
    function addPaymentToken(address token, string memory symbol, uint256 decimals) external onlyOwner {
        // Token address is required
        require(token != address(0), "Token address must be provided");

        // Token symbol is required, to be easily recognizable when check the list
        require(bytes(symbol).length > 0, "Token symbol must be provided");

        // Decimals is required
        require(decimals > 0 && decimals < 18, "Token decimals must be provided");

        // Token is already in the payment list
        require(paymentTokens[token].decimals == 0, "Token is already added");

        // Add the token to the list
        paymentTokens[token] = PaymentTokens(symbol, decimals, 0);

        // Associate it to the contract
        SafeHTS.safeAssociateToken(token, address(this));

        // Log the addition
        emit PaymentTokenAdded(token, symbol, decimals);
    }

    // Remove a payment token, only for when one is added by mistake
    function removePaymentToken(address token) external onlyOwner {
        // Token address is required
        require(token != address(0), "Token address must be provided");

        // Token is not in the payment list
        require(paymentTokens[token].decimals > 0, "Token is not in the payment list");

        // The removing payment token has collected amount, which means if removed the amount cannot be withdrawn
        require(paymentTokens[token].collectedAmount == 0, "Withdraw the collected amount to be able to remove the payment token");

        // Dissociate the token from contract
        SafeHTS.safeDissociateToken(token, address(this));

        // Remove the token from the list
        delete paymentTokens[token];

        // Log the removal
        emit PaymentTokenRemoved(token);
    }

    // Add a future pair token to the list
    function addFuturePairToken(address token, string memory symbol, int64 fixedSharePercentage) external onlyOwner {
        // Token address is required
        require(token != address(0), "Token address must be provided");

        // Token symbol is required, to be easily recognizable when check the list
        require(bytes(symbol).length > 0, "Token symbol must be provided");
        
        // Some tokens like sauce and usdc have a fixed share
        require(fixedSharePercentage >= 0 && fixedSharePercentage <= 70, "Fixed share must be between 0 to 70");

        // Token is already in the future pair tokens list
        require(futurePairTokens[token].isAcceptable == false, "Token is already added");

        // Add the token to the list
        futurePairTokens[token] = FuturePairTokens(symbol, fixedSharePercentage, false, true);

        // Log the addition
        emit FuturePairTokenAdded(token, symbol, fixedSharePercentage);
    }

    // Remove a future pair token, only for when one is added by mistake
    function removeFuturePairToken(address token) external onlyOwner {
        // Token address is required
        require(token != address(0), "Token address must be provided");

        // Token is not in the list
        require(futurePairTokens[token].isAcceptable  == true, "Token is not in the list");

        // Used tokens cannot be removed
        require(futurePairTokens[token].isUsed  == false, "Used tokens cannot be removed");

        // Remove the token from the list
        delete futurePairTokens[token];

        // Log the removal
        emit FuturePairTokenRemoved(token);
    }

    // There may be instances where the duration of the event could be extended
    // or the time for withdrawals could be delayed until all necessary arrangements have been finalized
    function updateSchedule(uint256 startTime, uint256 endTime, uint256 withdrawTime) external onlyOwner returns (bool) {
        // Withdraw time cannot be extended to more than 4 months after deployment of the contract
        require(withdrawTime <= maxWithdrawTime, "Withdraw time cannot be higher than 4 month after deployment");
        
        // A flag to track if any of the value will change, to emit an event
        bool anythingGotUpdated = false;

        // Update start time if new start time is bigger than now and one month before max withdraw time
        if( startTime >= block.timestamp && startTime <= maxWithdrawTime - 30 days ){
            schedule.startTime = startTime;
            anythingGotUpdated = true;
        }

        // Update end time if the new value is later than tomorrow and sooner than 1 day before withdraw time
        if( endTime > block.timestamp + 1 days && endTime <= maxWithdrawTime - 1 days){
            schedule.endTime = endTime;
            anythingGotUpdated = true;
        }

        // Update the withdrawal time only if it's set beyond tomorrow, 
        // preventing premature withdrawals in case of mistakes until the owner corrects it
        if( withdrawTime > block.timestamp + 1 days ){
            schedule.withdrawTime = withdrawTime;
            anythingGotUpdated = true;
        }

        // Log if any of the values changed
        if( anythingGotUpdated ){
            emit ScheduleUpdated(startTime, endTime, withdrawTime);
            return true;
        }

        return false;
    }

    /* ================================== Public Queries ========================= */

	// Get a specific payment token info
	function getPaymentToken(address tokenAddress) public view returns (PaymentTokens memory) {
		return paymentTokens[tokenAddress];
	}

	// Get a specific future pair token info
	function getFuturePairToken(address tokenAddress) public view returns (FuturePairTokens memory) {
		return futurePairTokens[tokenAddress];
	}

    /* ===================================== Helpers ===================================== */

    function tinyDAVINCIsToTinyUSDs(int64 daVinciAmountInSmallestUnit) public view returns (int64) {
        // Calculate USD amount in its smallest units
        uint256 usdAmountInSmallestUnit = (int64ToUint256(daVinciAmountInSmallestUnit) * davinciToken.price) / davinciToken.solidUnit;

        return uint256Toint64(usdAmountInSmallestUnit);
    }

    function uint256Toint64(uint256 unsignedValue) internal pure returns (int64) {
        // maximum value that can fit in an int64
        uint256 maxInt64Value = 2**63 - 1;

        // Check that the unsigned value is within the range of uint64
        require(unsignedValue <= maxInt64Value, "Value out of int64 range");

        // Perform the conversion
        return int64(uint64(unsignedValue));
    }

    function int64ToUint256(int64 signedValue) internal pure returns (uint256) {
        require(signedValue >= 0, "Cannot convert a negative value to uint256");
        
        return uint256(uint64(signedValue));
    }

    /* ===================================== Events ====================================== */
    event Deployed(address davinciToken, address treasury, int64 amount, uint256 startTime, uint256 endTime, uint256 withdrawTime, uint256 maxWithdrawTime);
    event ScheduleUpdated(uint256 startTime, uint256 endTime, uint256 withdrawTime);
    event PaymentTokenAdded(address indexed paymentToken, string symbol, uint256 decimals);
    event PaymentTokenRemoved(address indexed paymentToken);
    event FuturePairTokenAdded(address indexed futurePairToken, string symbol, int64 fixedSharePercentage);
    event FuturePairTokenRemoved(address indexed futurePairToken);
	event Reserved(address indexed investor, address indexed paymentToken, int64 amount, int64 usdAmount, address futurePairToken);
	event ReservedAmountWithdrawn(address indexed investor, int64 amount);
	event DavinciRemainderWithdrawn(address indexed treasury, int64 amount);
	event RaisedFundWithdrawn(address indexed paymentToken, address indexed treasury, int64 amount);
}