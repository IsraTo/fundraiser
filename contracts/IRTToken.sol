pragma solidity ^0.4.11;

/* -------------------------------------------------------------------------- */
/* IsraTo IMPLEMENTATION OF EIP223 (AKA ERC223) TOKEN SPECIFICATION           */
/* -------------------------------------------------------------------------- */
/* https://github.com/ethereum/EIPs/issues/223                                */
/* -------------------------------------------------------------------------- */
/* ÐΞV: adam.j.levy@protonmail.com                                            */
/* -------------------------------------------------------------------------- */

import './SafeMath.sol';
import './Freezable.sol';

/**
 * @dev Receiver Contract Skelton (ERC223)
 */
contract ReceiverContract {
	struct TKN {
		address token; // address of the token's contract
		address sender;
		uint value;
		bytes data;
		bytes4 sig;
	}

	/* tkn is similar to msg variable in Ether transactions
	 * tkn.sender: the user who initiated this token transaction (like msg.sender)
	 * tkn.value: the number of tokens that were sent (like msg.value)
	 * tkn.data:  data passed with token transaction (like msg.data)
	 * tkn.sig: 4 bytes signature of function (if data is a function execution)
	 */
	function tokenFallback(address _from, uint _value, bytes _data) public returns (bool ok){
		TKN memory tkn;

		if (!supportsToken(msg.sender)) return false;

		tkn.sender = _from;
		tkn.value = _value;
		tkn.data = _data;
		tkn.sig = getSig(_data);

		return true;
	}

	function getSig(bytes _data) private constant returns (bytes4) {
		uint32 u = uint32(_data[3]) + (uint32(_data[2]) << 8) + (uint32(_data[1]) << 16) + (uint32(_data[0]) << 24);
		bytes4 sig = bytes4(u);
		return sig;
	}

	function supportsToken(address token) public returns (bool);
}

/* -------------------------------------------------------------------------- */

/**
 * @dev Implementation of ERC223 token (ERC20 compatible)
 */
contract T223 {
	using SafeMath for uint256;

	uint256 public totalSupply;

	mapping (address => uint256) balances;

	function balanceOf(address _owner) public constant returns (uint256) {
		return balances[_owner];
	}

	/**
	 * @dev Fix to prevent the ERC20 short address attack
	 * 		http://vessenes.com/the-erc20-short-address-attack-explained/
	 * @param size Payload size
	 */
	modifier onlyPayloadSize(uint size) {
		require(msg.data.length >= size+4);
		_;
	}

	/**
	 * @dev Transfer tokens to a specified address
	 * @param _to 	 The contract's address to transfer to
	 * @param _value The amount of tokens to be transferred
	 * @param _data  Data passed with the transaction
	*/
	function transfer(address _to, uint256 _value, bytes _data) onlyPayloadSize(2 * 32) public returns (bool success) {
		require(internalTransfer(_to, _value));

		if (isContract(_to)) {
			return transferToContract(_to, _value, _data);
		}

		return true;
	}

	/**
	 * variadic transfer function without _data
	 */
	function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) public returns (bool success) {
		return transfer(_to, _value, new bytes(0));
	}

	/**
	 * @dev Token transfer to address (ERC20 compatible)
	 */
	function internalTransfer(address _to, uint256 _value) private returns (bool success) {
		balances[msg.sender] = balances[msg.sender].sub(_value);
		balances[_to] = balances[_to].add(_value);
		Transfer(msg.sender, _to, _value); // ERC20
		return true;
	}

	/**
	 * @dev Transfer tokens to a contract
	 *      will throw if receiver contract has no tokenFallback() method
	 *
	 * @param _to 	 The contract's address to transfer to
	 * @param _value The amount to be transferred
	 * @param _data  Data passed with the transaction
	 */
	function transferToContract(address _to, uint256 _value, bytes _data) private returns (bool success) {
		ReceiverContract receiver = ReceiverContract(_to);
		receiver.tokenFallback(msg.sender, _value, _data);
		Transfer(msg.sender, _to, _value, _data); // ERC223
		return true;
	}

	/**
	 * @dev Find out if _address is a contract (get the size of the bytecode)
	 * @param _address 	 The address to test
	 * @return true if _address is a contract (bytecode exists)
	 */
	function isContract(address _address) private returns (bool is_contract) {
		uint length;
		assembly { length := extcodesize(_address) }
		return (length>0);
	}

	/* Transfer event (variadic to stay compatible with ERC20) */
	event Transfer(address indexed from, address indexed to, uint256 value); // ERC20
	event Transfer(address indexed from, address indexed to, uint256 value, bytes data); // ERC223
}

/* -------------------------------------------------------------------------- */

/**
 * @dev IRTToken is an ERC223 mintable, burnable and pausable token
 */
contract IRTToken is T223, Freezable {
	string public constant name = "IsraTo";
	string public constant symbol = "IRT";
	uint8 public constant decimals = 18;

	uint256 public constant maxSupply = 250000000 * 10**18; // max: 250,000,000 IRT
	uint256 public totalSupply = 0; // actual circulating supply

	event LogMint(address indexed to, uint256 amount);
	event LogBurn(address indexed burner, uint256 amount);

	/**
	 * @dev  Function to mint tokens (no more than maxSupply)
	 * @param _to		Address that will receive the minted tokens
	 * @param _amount 	The amount of tokens to mint
	 * @return 			True if the operation was successful
	 */
	function mint(address _to, uint256 _amount) onlyOwner public returns (bool) {
		require(_amount>0);

		totalSupply = totalSupply.add(_amount);

		require(totalSupply <= maxSupply);

		balances[_to] = balances[_to].add(_amount);

		LogMint(_to, _amount);
		Transfer(0x0, _to, _amount); // to keep ERC20 compliance
		return true;
	}

	/**
	 * @dev People can burn a specific amount of their tokens
	 * @param _amount The amount of token to be burned
	 */
	function burn(uint256 _amount) public {
		require(_amount>0);

		address burner = msg.sender;

		balances[burner] = balances[burner].sub(_amount);
		totalSupply = totalSupply.sub(_amount);

		LogBurn(burner, _amount);
	}

	/**
	 * @dev Prevent transfer if Token is freezed
	 * @return True if the operation was successful
	 */
	function transfer(address _to, uint256 _amount, bytes _data) whenNotFreezed public returns (bool) {
		return super.transfer(_to, _amount, _data);
	}

	function transfer(address _to, uint256 _amount) whenNotFreezed public returns (bool) {
		return super.transfer(_to, _amount);
	}
 }