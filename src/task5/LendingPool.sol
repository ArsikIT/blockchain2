// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../task1/MockERC20.sol";
import {MockPriceOracle} from "./MockPriceOracle.sol";

contract LendingPool {
    error ZeroAmount();
    error PositionHealthy();
    error InsufficientCollateral();
    error ExceedsMaxLtv();
    error HealthFactorTooLow(uint256 healthFactor);
    error NoDebt();
    error NotEnoughBorrowLiquidity();

    uint256 internal constant BPS = 10_000;
    uint256 internal constant ONE = 1e18;
    uint256 internal constant YEAR = 365 days;

    uint256 public constant MAX_LTV_BPS = 7_500;
    uint256 public constant LIQUIDATION_BONUS_BPS = 500;

    MockERC20 public immutable collateralToken;
    MockERC20 public immutable debtToken;
    MockPriceOracle public immutable priceOracle;
    uint256 public immutable annualInterestBps;

    struct Position {
        uint256 collateralDeposited;
        uint256 debtBorrowed;
        uint256 lastAccrued;
    }

    mapping(address user => Position position) internal positions;

    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 repaidAmount,
        uint256 collateralSeized
    );

    constructor(
        address collateralToken_,
        address debtToken_,
        address priceOracle_,
        uint256 annualInterestBps_
    ) {
        collateralToken = MockERC20(collateralToken_);
        debtToken = MockERC20(debtToken_);
        priceOracle = MockPriceOracle(priceOracle_);
        annualInterestBps = annualInterestBps_;
    }

    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[msg.sender];
        _accrueInterest(position);

        collateralToken.transferFrom(msg.sender, address(this), amount);
        position.collateralDeposited += amount;

        emit Deposited(msg.sender, amount);
    }

    function borrow(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[msg.sender];
        _accrueInterest(position);

        if (position.collateralDeposited == 0) revert InsufficientCollateral();
        if (debtToken.balanceOf(address(this)) < amount) revert NotEnoughBorrowLiquidity();

        position.debtBorrowed += amount;

        uint256 currentHealthFactor = _healthFactor(position.collateralDeposited, position.debtBorrowed);
        if (currentHealthFactor < ONE) revert ExceedsMaxLtv();

        debtToken.transfer(msg.sender, amount);

        emit Borrowed(msg.sender, amount);
    }

    function repay(uint256 amount) external returns (uint256 actualRepaid) {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[msg.sender];
        _accrueInterest(position);

        uint256 debt = position.debtBorrowed;
        if (debt == 0) revert NoDebt();

        actualRepaid = amount > debt ? debt : amount;

        debtToken.transferFrom(msg.sender, address(this), actualRepaid);
        position.debtBorrowed = debt - actualRepaid;

        emit Repaid(msg.sender, actualRepaid);
    }

    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        Position storage position = positions[msg.sender];
        _accrueInterest(position);

        uint256 collateral = position.collateralDeposited;
        if (amount > collateral) revert InsufficientCollateral();

        uint256 remainingCollateral = collateral - amount;
        if (position.debtBorrowed > 0) {
            uint256 currentHealthFactor = _healthFactor(remainingCollateral, position.debtBorrowed);
            if (currentHealthFactor <= ONE) revert HealthFactorTooLow(currentHealthFactor);
        }

        position.collateralDeposited = remainingCollateral;
        collateralToken.transfer(msg.sender, amount);

        emit Withdrawn(msg.sender, amount);
    }

    function liquidate(address user, uint256 repayAmount)
        external
        returns (uint256 actualRepaid, uint256 collateralSeized)
    {
        if (repayAmount == 0) revert ZeroAmount();

        Position storage position = positions[user];
        _accrueInterest(position);

        uint256 debt = position.debtBorrowed;
        if (debt == 0) revert NoDebt();

        uint256 currentHealthFactor = _healthFactor(position.collateralDeposited, debt);
        if (currentHealthFactor >= ONE) revert PositionHealthy();

        actualRepaid = repayAmount > debt ? debt : repayAmount;
        debtToken.transferFrom(msg.sender, address(this), actualRepaid);

        collateralSeized = _collateralForDebt(actualRepaid);
        collateralSeized = (collateralSeized * (BPS + LIQUIDATION_BONUS_BPS)) / BPS;

        if (collateralSeized > position.collateralDeposited) {
            collateralSeized = position.collateralDeposited;
        }

        position.debtBorrowed = debt - actualRepaid;
        position.collateralDeposited -= collateralSeized;

        collateralToken.transfer(msg.sender, collateralSeized);

        emit Liquidated(msg.sender, user, actualRepaid, collateralSeized);
    }

    function getPosition(address user)
        external
        view
        returns (uint256 deposited, uint256 borrowed, uint256 currentHealthFactor)
    {
        Position memory position = positions[user];
        borrowed = _previewDebt(position);
        deposited = position.collateralDeposited;
        currentHealthFactor = _healthFactor(deposited, borrowed);
    }

    function previewDebt(address user) external view returns (uint256) {
        return _previewDebt(positions[user]);
    }

    function healthFactor(address user) external view returns (uint256) {
        Position memory position = positions[user];
        return _healthFactor(position.collateralDeposited, _previewDebt(position));
    }

    function _accrueInterest(Position storage position) internal {
        if (position.lastAccrued == 0) {
            position.lastAccrued = block.timestamp;
            return;
        }

        uint256 debt = position.debtBorrowed;
        if (debt == 0) {
            position.lastAccrued = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - position.lastAccrued;
        if (elapsed == 0) return;

        uint256 interest = (debt * annualInterestBps * elapsed) / (BPS * YEAR);
        position.debtBorrowed = debt + interest;
        position.lastAccrued = block.timestamp;
    }

    function _previewDebt(Position memory position) internal view returns (uint256) {
        if (position.debtBorrowed == 0) return 0;
        if (position.lastAccrued == 0 || block.timestamp <= position.lastAccrued) return position.debtBorrowed;

        uint256 elapsed = block.timestamp - position.lastAccrued;
        uint256 interest = (position.debtBorrowed * annualInterestBps * elapsed) / (BPS * YEAR);
        return position.debtBorrowed + interest;
    }

    function _healthFactor(uint256 collateralAmount, uint256 debtAmount) internal view returns (uint256) {
        if (debtAmount == 0) return type(uint256).max;

        uint256 collateralValue = (collateralAmount * priceOracle.collateralPrice()) / ONE;
        uint256 debtValue = (debtAmount * priceOracle.debtPrice()) / ONE;

        return (collateralValue * MAX_LTV_BPS * ONE) / (debtValue * BPS);
    }

    function _collateralForDebt(uint256 debtAmount) internal view returns (uint256) {
        uint256 debtValue = (debtAmount * priceOracle.debtPrice()) / ONE;
        return (debtValue * ONE) / priceOracle.collateralPrice();
    }
}
