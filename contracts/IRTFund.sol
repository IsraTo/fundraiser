pragma solidity ^0.4.11;

/* -------------------------------------------------------------------------- */
/* IsraTo LIQUIDITY CONTRACT                                                 */
/* -------------------------------------------------------------------------- */
/* ÐΞV: adam.j.levy@protonmail.com                                            */
/* -------------------------------------------------------------------------- */

import './SafeMath.sol';
import './Ownable.sol';
import './IRTToken.sol';

/**
 * @dev IRT Fund is a liquidity contract for the cold start.
 * 		People can sell their IRT at a fixed rate if they want to do so.
 *		It's like a buy order from IsraTo.
 */
contract IRTFund is Ownable {
	using SafeMath for uint256;

	struct TKN {
		address token; // address of the token's contract
		address sender;
		uint value;
		bytes data;
		bytes4 sig;
	}

	event LogDeposit(
		address indexed donator,
		uint256 weiAmount
	);

	event LogSale(
		address indexed seller,
		uint256 quantity,
		uint256 weiAmount,
		uint256 rate
	);

	IRTToken public token; // the IRT token
	uint256 public buy_rate = 8000; // we buy @ 0.000125 ETH/IRT (8000 IRT/ETH)

	function IRTFund(IRTToken _token) {
		require(_token != 0x0);
		token = _token;
	}

	/* anyone can contribute to the liquidity contract */
	function () payable {
		LogDeposit(msg.sender, msg.value);
	}

	function setRate(uint256 _rate) onlyOwner public {
		buy_rate = _rate;
	}

	/* anyone can sell IRT tokens for ETH */
	function sell(uint256 quantity) public {
		internalSell(msg.sender, quantity);
	}

	function internalSell(address seller, uint256 quantity) private {
		require(seller != 0x0);
		require(quantity > 0);
		require(msg.value == 0); // not payable (do not send ETH here)
		require(token.balanceOf(seller) >= quantity);

		uint256 weiAmount = quantity.div(buy_rate);

		if (this.balance >= weiAmount) {
			token.transfer(owner, quantity); // Send IRT to owner
			seller.transfer(weiAmount); // send ETH to the seller
			LogSale(seller, quantity, weiAmount, buy_rate);
		}
	}

	/* tkn is similar to msg variable in Ether transactions
	 * tkn.sender: the user who initiated this token transaction (like msg.sender)
	 * tkn.value: the number of tokens that were sent (like msg.value)
	 * tkn.data:  data passed with token transaction (like msg.data)
	 * tkn.sig: 4 bytes signature of function (if data is a function execution)
	 */
	function tokenFallback(address _from, uint _value, bytes _data) public returns (bool ok){
		require(isIRTContract(msg.sender));

		TKN memory tkn;
		address tokenContract = msg.sender;

		tkn.sender = _from;
		tkn.value = _value;
		tkn.data = _data;
		tkn.sig = getSig(_data);

		internalSell(tkn.sender, tkn.value);

		return true;
	}

	function getSig(bytes _data) private constant returns (bytes4) {
		uint32 u = uint32(_data[3]) + (uint32(_data[2]) << 8) + (uint32(_data[1]) << 16) + (uint32(_data[0]) << 24);
		bytes4 sig = bytes4(u);
		return sig;
	}

	function isIRTContract(address _tokenContract) public returns (bool) {
		require(token == _tokenContract);
		return true;
	}
}