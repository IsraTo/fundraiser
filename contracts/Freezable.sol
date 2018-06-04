pragma solidity ^0.4.11;

import './Ownable.sol';

/**
 * @title Freezable
 * @dev Emergency stop mechanism
 */
contract Freezable is Ownable {
	event LogFreeze();
	event LogUnfreeze();

	bool public freezed = false;

	modifier whenNotFreezed() {
		require(!freezed);
		_;
	}

	modifier whenFreezed {
		require(freezed);
		_;
	}

	function freeze() onlyOwner whenNotFreezed public returns (bool) {
		freezed = true;
		LogFreeze();
		return true;
	}

	function unfreeze() onlyOwner whenFreezed public returns (bool) {
		freezed = false;
		LogUnfreeze();
		return true;
	}
}