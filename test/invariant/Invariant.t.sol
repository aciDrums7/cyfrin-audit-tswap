// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test } from "forge-std/Test.sol";
import { StdInvariant } from "forge-std/StdInvariant.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { PoolFactory } from "../../src/PoolFactory.sol";
import { TSwapPool } from "../../src/TSwapPool.sol";
import { Handler } from "../invariant/Handler.t.sol";

contract Invariant is StdInvariant, Test {
    // these pools have 2 assets
    ERC20Mock poolToken;
    ERC20Mock weth;

    // We are gonna need the contracts
    PoolFactory factory;
    TSwapPool pool; //* poolToken / WETH

    Handler handler;

    int256 constant STARTING_POOL_TOKEN = 100e18; //^ Starting ERC20 / poolToken
    int256 constant STARTING_WETH = 50e18; //^ Starting WETH

    function setUp() public {
        weth = new ERC20Mock();
        poolToken = new ERC20Mock();
        factory = new PoolFactory(address(weth));
        pool = TSwapPool(factory.createPool(address(poolToken)));

        // Create those initial x & y balances
        poolToken.mint(address(this), uint256(STARTING_POOL_TOKEN));
        weth.mint(address(this), uint256(STARTING_WETH));

        poolToken.approve(address(pool), type(uint256).max);
        weth.approve(address(pool), type(uint256).max);

        // Deposit into the pool, give the starting x & y balances
        pool.deposit(
            uint256(STARTING_WETH), uint256(STARTING_WETH), uint256(STARTING_POOL_TOKEN), uint64(block.timestamp)
        );

        handler = new Handler(pool);

        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = Handler.deposit.selector;
        selectors[1] = Handler.swapPoolTokenForWethBasedOnOutputWeth.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    function statefulFuzz_ConstantProductFormulaStaysTheSameForPoolToken() public view {
        // assert() what?
        // The change in the pool size of WETH should follow this equation:
        // ∆x = (β/(1-β)) * x
        // ??????
        // In a handler
        // actual delta X == ∆x = (β/(1-β)) * x
        assert(handler.actualDeltaPoolToken() == handler.expectedDeltaPoolToken());
    }

    function statefulFuzz_ConstantProductFormulaStaysTheSameForWeth() public view {
        // assert() what?
        // The change in the pool size of WETH should follow this equation:
        // ∆x = (β/(1-β)) * x
        // ??????
        // In a handler
        // actual delta X == ∆x = (β/(1-β)) * x
        assert(handler.actualDeltaWeth() == handler.expectedDeltaWeth());
    }
}
