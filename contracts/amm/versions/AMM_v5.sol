// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./lib/IERC20.sol";

/// @custom:version Bug 4 (Precision Loss): Removes 1e18 scaling

contract AMM {
    IERC20 public immutable t0;
    IERC20 public immutable t1;

    uint public r0;
    uint public r1;

    uint public supply;
    mapping(address => uint) public minted;

    uint private constant MINIMUM_LIQUIDITY = 1000;

    constructor(IERC20 _t0, IERC20 _t1) {
        require(address(_t0) != address(_t1));
        require(address(_t0) != address(0) && address(_t1) != address(0));
        t0 = _t0;
        t1 = _t1;
    }

    function deposit(uint x0, uint x1) public {
        require(x0 > 0 && x1 > 0);

        uint balance0Before = t0.balanceOf(address(this));
        uint balance1Before = t1.balanceOf(address(this));

        _safeTransferFrom(t0, msg.sender, address(this), x0);
        _safeTransferFrom(t1, msg.sender, address(this), x1);

        uint amount0 = t0.balanceOf(address(this)) - balance0Before;
        uint amount1 = t1.balanceOf(address(this)) - balance1Before;

        uint toMint;

        if (supply == 0) {
            uint liquidity = _sqrt(amount0 * amount1);
            require(liquidity > MINIMUM_LIQUIDITY);
            toMint = liquidity - MINIMUM_LIQUIDITY;

            minted[address(0)] += MINIMUM_LIQUIDITY;
            supply += MINIMUM_LIQUIDITY;
        } else {
            uint mint0 = (amount0 * supply) / r0;
            uint mint1 = (amount1 * supply) / r1;
            toMint = mint0 < mint1 ? mint0 : mint1;
        }

        require(toMint > 0, "Insufficient liquidity minted");

        minted[msg.sender] += toMint;
        supply += toMint;


        r0 += amount0;
        r1 += amount1;
        require(t0.balanceOf(address(this)) == r0);
        require(t1.balanceOf(address(this)) == r1);
    }

    function redeem(uint x) public {
        require(supply > 0);
        require(minted[msg.sender] >= x);
        require(x < supply);
        require(x > 0);

        uint balance0 = t0.balanceOf(address(this));
        uint balance1 = t1.balanceOf(address(this));

        uint amount0 = (x * balance0) / supply;
        uint amount1 = (x * balance1) / supply;

        require(amount0 > 0 && amount1 > 0);

        minted[msg.sender] -= x;
        supply -= x;

        _safeTransfer(t0, msg.sender, amount0);
        _safeTransfer(t1, msg.sender, amount1);

        r0 -= amount0;
        r1 -= amount1;
        require(t0.balanceOf(address(this)) == r0);
        require(t1.balanceOf(address(this)) == r1);
    }

    function swap(address t, uint x_in, uint x_out_min) public {
        require(t == address(t0) || t == address(t1), "Invalid token");
        require(x_in > 0, "Zero amount in");

        bool is_t0 = t == address(t0);
        IERC20 t_in = is_t0 ? t0 : t1;
        IERC20 t_out = is_t0 ? t1 : t0;

        uint balanceInBefore = t_in.balanceOf(address(this));

        _safeTransferFrom(t_in, msg.sender, address(this), x_in);

        uint amountIn = t_in.balanceOf(address(this)) - balanceInBefore;

        uint balanceIn = t_in.balanceOf(address(this));
        uint balanceOut = t_out.balanceOf(address(this));

        uint reserveIn = balanceIn - amountIn;
        uint reserveOut = balanceOut;

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = (reserveIn * 1000) + amountInWithFee;
        uint x_out = numerator / denominator;

        require(x_out >= x_out_min);

        _safeTransfer(t_out, msg.sender, x_out);
        
        if (is_t0) {
            r0 += amountIn;
            r1 -= x_out;
        } else {
            r0 -= x_out;
            r1 += amountIn;
        }
        require(t0.balanceOf(address(this)) == r0);
        require(t1.balanceOf(address(this)) == r1);
    }

    function price(address token) external view returns (uint) {
        if (token == address(t0)) {
            require(r0 > 0);
            return r1 / r0;
        } else if (token == address(t1)) {
            require(r1 > 0);
            return r0 / r1;
        }
        revert("Invalid token");
    }

    // --- INTERNAL HELPERS ---

    function _safeTransfer(IERC20 token, address to, uint value) private {
        require(token.transfer(to, value));
    }

    function _safeTransferFrom(IERC20 token, address from, address to, uint value) private {
        require(token.transferFrom(from, to, value));
    }

    function _sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
