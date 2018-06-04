pragma solidity ^0.4.11;

/**
 * @dev	- This contract provides basic ownership control.
 * 		- Ownership transfer needs to be accepted by the new owner
 */
contract Ownable {
	address public owner;
	address public pendingOwner;

	function Ownable() {
		owner = msg.sender;
	}

	modifier onlyOwner() { require(msg.sender == owner); _; }
	modifier onlyPendingOwner() { require(msg.sender == pendingOwner); _; }

	/**
	 * @dev Allows the current owner to set the pendingOwner address
	 * @param newOwner The address to transfer ownership to
	 */
	function startOwnershipTransfer(address newOwner) onlyOwner public {
		require(newOwner != 0x0);
		pendingOwner = newOwner;
	}

	/**
	 * @dev Allows the pendingOwner address to finalize the transfer
	 */
	function finalizeOwnershipTransfer() onlyPendingOwner public {
		owner = pendingOwner;
		pendingOwner = 0x0;
	}
}