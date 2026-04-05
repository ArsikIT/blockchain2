// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockERC20 {
    error ZeroAddress();
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;
    mapping(address owner => mapping(address spender => uint256 allowance)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert ZeroAddress();

        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 currentAllowance = allowance[from][msg.sender];

        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) {
                revert InsufficientAllowance(currentAllowance, amount);
            }

            unchecked {
                allowance[from][msg.sender] = currentAllowance - amount;
            }

            emit Approval(from, msg.sender, allowance[from][msg.sender]);
        }

        _transfer(from, to, amount);
        return true;
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();

        uint256 senderBalance = balanceOf[from];
        if (senderBalance < amount) {
            revert InsufficientBalance(senderBalance, amount);
        }

        unchecked {
            balanceOf[from] = senderBalance - amount;
        }
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }
}
