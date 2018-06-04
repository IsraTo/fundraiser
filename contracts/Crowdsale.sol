pragma solidity ^0.4.11;

/* -------------------------------------------------------------------------- */
/* IsraTo SALE CONTRACT                                                       */
/* -------------------------------------------------------------------------- */
/* This contract controls the crowdsale of IRT tokens                         */
/* -------------------------------------------------------------------------- */
/* ÐΞV: abraham.j.levy@protonmail.com                                         */
/* -------------------------------------------------------------------------- */

import './SafeMath.sol';
import './Ownable.sol';
import './IRTToken.sol';

contract Crowdsale is Ownable {
	using SafeMath for uint256;

	/**
	 * Event for token purchase logging
	 * @param purchaser   Who paid for the tokens
	 * @param beneficiary Who got the tokens
	 * @param weiAmount   Weis paid for purchase
	 * @param quantity    Quantity of tokens purchased
	 */ 
	event LogTokenPurchase(
		address indexed purchaser, 
		address indexed beneficiary, 
		uint256 weiAmount, 
		uint256 quantity
	);

	event LogFinalized();

	IRTToken public token; // the token being sold

	/* UNIX timestamp of each event */
	uint256 public constant startDate = TBA; 
	uint256 public constant endDate = TBA;

	/* Wallet Addresses */
	address public wallet;
	address public foundersBank;
	address public bountyBank;
	address public investorsBank;
	address public advisorsBank;
	
	bool public isFinalized = false; // Crowdsale is finalized 

	enum FundingState {
		Pending,	// Contract initialized
		Funding,	// Ongoing Token Sale
		Complete	// Token Sale Complete
	}

    FundingState public state = FundingState.Pending;

	uint256 public tokenSold = 0; // total tokens sold during the crowdsale
	uint256 public rate = 666; // token units per wei (1 ETH => 666 IRT)

	/* Total amount of raised money (in weis) */
	uint256 public weiRaised = 0;

	/* Max amount to be raised in weis */
	uint256 public constant hard_cap = 31250 * 1 ether; // 31,250 ETH

	/* Token distribution (operations, founders, bounty etc.) */
	uint256 public constant crowdsaleAllocation = 125000000 * 10**18; // 125,000,000 IRT (50% of supply)
	uint256 public constant operationsAllocation = 45000000 * 10**18; // 45,000,000 IRT (18% of supply)
	uint256 public constant foundersAllocation = 30000000 * 10**18; // 30,000,000 IRT (12% of supply)
	uint256 public constant bountyAllocation = 20000000 * 10**18; // 20,000,000 IRT (8% of supply)
	uint256 public constant investorsAllocation = 17500000 * 10**18; // 17,500,000 IRT (7% of supply)
	uint256 public constant advisorsAllocation = 12500000 * 10**18; // 12,500,000 IRT (5% of supply)

	/* Founder's tokens locked for 365 days after campaign is over */
	uint256 public constant foundersLockup = 365 days;
	uint256 public foundersPaymentCount = 0; // number of payments made to founder

	/**
	 * Contract's constructor
	 */
	function Crowdsale(address _wallet, address _founders, address _bounty, address _investors, address _advisors) {
		require(_wallet != 0x0);
		require(_founders != 0x0);
		require(_bounty != 0x0);
		require(_investors != 0x0);
		require(_advisors != 0x0);

		token = new IRTToken();
		token.mint(msg.sender, operationsAllocation);
		token.mint(_bounty, bountyAllocation);
		token.mint(_investors, investorsAllocation);
		token.mint(_advisors, advisorsAllocation);

		wallet = _wallet;
		foundersBank = _founders;
		bountyBank = _bounty;
		investorsBank = _investors;
		advisorsBank = _advisors;
		
		updateStateMachine();
	}

	/**
	 * Fallback function can be used to buy tokens
	 */
	function () payable {
		buy();
	}

	/**
	 * @dev The basic entry point to contribute to the crowdsale
	 */
	function buy() public payable {
		buyInternal(msg.sender);
	}

	function buyFor(address beneficiary) public payable {
		buyInternal(beneficiary);
	}

	/**
	 * @dev Private token purchase function
	 */
	function buyInternal(address beneficiary) private {
		updateStateMachine();

		require(beneficiary != 0x0);
		require(isValidTransaction());

		uint256 weiAmount = msg.value;
		uint256 quantity = weiAmount.mul(rate);

		tokenSold = tokenSold.add(quantity);

		/* total weis raised in the crowdsale */
		weiRaised = weiRaised.add(weiAmount);

		token.mint(beneficiary, quantity);
		LogTokenPurchase(msg.sender, beneficiary, weiAmount, quantity);

		wallet.transfer(msg.value); // direct deposit to the wallet
	}

	function updateStateMachine() private returns (bool) {
		if (state == FundingState.Complete) {
			return false;
		}

		/* Switch to Pending if campaign is not started yet */
		if (now<startDate) {
			state = FundingState.Pending;
			return false;
		}

		/* Switch to Complete if hard cap is reached or campaign ended */
		if (weiRaised>=hard_cap || now>endDate) {
			state = FundingState.Complete;
			return false;
		}

		/* During the campaign ... */
		if (now>=startDate && now<=endDate) {

			/* Switch from Pending to Funding */
			if (state == FundingState.Pending) {
				state = FundingState.Funding;
			}

			if (now >= startDate) rate = 6000;
			if (now >= (startDate + 4 hours)) rate = 5500;
			if (now >= (startDate + 24 hours)) rate = 5000;
			if (now >= (startDate + 2 days)) rate = 4750;
			if (now >= (startDate + 7 days)) rate = 4500;
			if (now >= (startDate + 14 days)) rate = 4250;
			if (now >= (startDate + 25 hours)) rate = 4000;
		}
	}

	/**
	 * @return true if the transaction is possible
	 */
	function isValidTransaction() internal constant returns (bool) {
		bool nonZeroPurchase = msg.value != 0;
		bool notPending = state != FundingState.Pending;
		bool notComplete = state != FundingState.Complete;

		return nonZeroPurchase && notPending && notComplete;
	}

	/**
	 * @return true if the token sale event has ended
	 */
	function hasEnded() public constant returns (bool) {
		bool timeout = now > endDate;
		bool hard_cap_reached = weiRaised >= hard_cap;
		return timeout || hard_cap_reached;
	}

	/**
	 * @dev Can only be called after sale ends
	 */
	function finalize() onlyOwner public {
		require(!isFinalized);
		require(hasEnded());

		LogFinalized();
		isFinalized = true;
	}

	/* ---------------------------------------------------------------------- */

	/**
	 * @dev Function to distribute tokens to the founders.
	 *
	 * Founders' tokens are locked for a period of 365 days
	 * after the sale ends, then:
	 * 	- They can only get 10 payments
	 *	- Each payment = 10% of the founders' allocation
	 */
	function payFounders() onlyOwner public {
		require(foundersPaymentCount<10);
		require(now >= endDate + foundersLockup + (foundersPaymentCount * 30 days));

		foundersPaymentCount++;
		token.mint(foundersBank, foundersAllocation.div(10));
	}
}

/* -------------------------------------------------------------------------- */