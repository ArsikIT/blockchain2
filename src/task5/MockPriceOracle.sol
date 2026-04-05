// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockPriceOracle {
    error ZeroPrice();

    uint256 public collateralPrice;
    uint256 public debtPrice;

    constructor(uint256 collateralPrice_, uint256 debtPrice_) {
        if (collateralPrice_ == 0 || debtPrice_ == 0) revert ZeroPrice();
        collateralPrice = collateralPrice_;
        debtPrice = debtPrice_;
    }

    function setCollateralPrice(uint256 newPrice) external {
        if (newPrice == 0) revert ZeroPrice();
        collateralPrice = newPrice;
    }

    function setDebtPrice(uint256 newPrice) external {
        if (newPrice == 0) revert ZeroPrice();
        debtPrice = newPrice;
    }
}
