// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract LPToken {
    error NotAmm();
    error ZeroAddress();
    error InsufficientBalance(uint256 available, uint256 required);

    string public constant name = "Assignment LP Token";
    string public constant symbol = "ALP";
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    address public immutable amm;

    mapping(address account => uint256 balance) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(address amm_) {
        if (amm_ == address(0)) revert ZeroAddress();
        amm = amm_;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != amm) revert NotAmm();
        if (to == address(0)) revert ZeroAddress();

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external {
        if (msg.sender != amm) revert NotAmm();

        uint256 accountBalance = balanceOf[from];
        if (accountBalance < amount) {
            revert InsufficientBalance(accountBalance, amount);
        }

        unchecked {
            balanceOf[from] = accountBalance - amount;
        }
        totalSupply -= amount;

        emit Transfer(from, address(0), amount);
    }
}
