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
    address user = makeAddr("user");

    //* Ghost variables -> exist only in this handler contract
    uint256 startingPoolToken;
    uint256 startingWeth;
    int256 public expectedDeltaPoolToken;
    int256 public expectedDeltaWeth;
    int256 public actualDeltaPoolToken;
    int256 public actualDeltaWeth;

    constructor(TSwapPool _pool) {
        pool = _pool;
        weth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    // deposit, swapExactOutput

    function deposit(uint256 wethAmount) public {
        // let's make sure it's a 'reasonable' amount
        // avoid weird overflow errors
        uint256 minWeth = pool.getMinimumWethDepositAmount();
        wethAmount = bound(wethAmount, minWeth, type(uint64).max);

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

    function swapPoolTokenForWethBasedOnOutputWeth(uint256 outputWeth) public {
        //e upper limit needed to avoid reverting tx
        uint256 minWeth = pool.getMinimumWethDepositAmount();
        outputWeth = bound(outputWeth, minWeth, weth.balanceOf(address(pool)));
        // ∆X
        // ∆x = (β/(1-β)) * x
        uint256 poolTokenBalance = poolToken.balanceOf(address(pool));
        uint256 wethBalance = weth.balanceOf(address(pool));

        // If these two values are the same, we will divide by 0
        if (wethBalance == outputWeth) return;
        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(outputWeth, poolTokenBalance, wethBalance);
        if (poolTokenAmount > type(uint64).max) return;

        startingPoolToken = poolToken.balanceOf(address(pool));
        startingWeth = weth.balanceOf(address(pool));

        expectedDeltaPoolToken = int256(poolTokenAmount);
        expectedDeltaWeth = int256(-1) * int256(outputWeth);

        if (poolToken.balanceOf(user) < poolTokenAmount) {
            poolToken.mint(user, poolTokenAmount - poolToken.balanceOf(user) + 1);
        }

        vm.startPrank(user);
        poolToken.approve(address(pool), type(uint256).max);
        pool.swapExactOutput(poolToken, weth, outputWeth, uint64(block.timestamp));
        vm.stopPrank();

        // actual
        uint256 endingPoolToken = poolToken.balanceOf(address(pool));
        uint256 endingWeth = weth.balanceOf(address(pool));

        actualDeltaPoolToken = int256(endingPoolToken) - int256(startingPoolToken);
        actualDeltaWeth = int256(endingWeth) - int256(startingWeth);
    }
}
