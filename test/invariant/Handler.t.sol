// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract Handler is Test {
    TSwapPool pool;
    ERC20Mock weth;
    ERC20Mock poolToken;

    address liquidityProvider = makeAddr("liquidityProvider");

    //* Ghost variables -> exist only in this handler contract
    uint256 startingPoolToken;
    uint256 startingWeth;
    int256 expectedDeltaPoolToken;
    int256 expectedDeltaWeth;
    int256 actualDeltaPoolToken;
    int256 actualDeltaWeth;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    // deposit, swapExactOutput

    function deposit(uint256 wethAmount) public {
        // let's make sure it's a 'reasonable' amount
        // avoid weird overflow errors
        wethAmount = bound(wethAmount, 0, type(uint64).max);

        startingPoolToken = poolToken.balanceOf(address(pool));
        startingWeth = weth.balanceOf(address(pool));

        expectedDeltaPoolToken = int256(pool.getPoolTokensToDepositBasedOnWeth(wethAmount));
        expectedDeltaWeth = int256(wethAmount);

        // deposit
        vm.startPrank(liquidityProvider);
        poolToken.mint(liquidityProvider, uint256(expectedDeltaPoolToken));
        weth.mint(liquidityProvider, wethAmount);
        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        pool.deposit(wethAmount, 0, uint256(expectedDeltaPoolToken), uint64(block.timestamp));
        vm.stopPrank();

        // actual
        uint256 endingPoolToken = poolToken.balanceOf(address(pool));
        uint256 endingWeth = weth.balanceOf(address(pool));

        actualDeltaPoolToken = int256(endingPoolToken) - int256(startingPoolToken);
        actualDeltaWeth = int256(endingWeth) - int256(startingWeth);
    }
}
