// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.5.0 <0.8.0;

import './FullMath.sol';
import './FixedPoint128.sol';
import './LiquidityMath.sol';

/// @title Position
/// @notice Positions represent an owner address' liquidity between a lower and upper tick boundary
/// @dev Positions store additional state for tracking fees owed to the position
library Position {
    // info stored for each user's position
    /// 用户position的数据结构
    struct Info {
        // the amount of liquidity owned by this position
        uint128 liquidity; // 该用户提供的流动性数量，流动性数量 * fee per liquidity = 该用户得到的手续费
        // fee growth per unit of liquidity as of the last update to liquidity or fees owed
        // 交易的时候不会更新，只有mint和burn流动性的时候会更新
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        // the fees owed to the position owner in token0/token1
        uint128 tokensOwed0; // 该用户在 token0 中应得的手续费
        uint128 tokensOwed1; // 该用户在 token1 中应得的手续费
    }

    /// @notice Returns the Info struct of a position, given an owner and position boundaries
    /// @param self The mapping containing all user positions
    /// @param owner The address of the position owner
    /// @param tickLower The lower tick boundary of the position
    /// @param tickUpper The upper tick boundary of the position
    /// @return position The position info struct of the given owners' position
    function get(
        mapping(bytes32 => Info) storage self,
        address owner,
        int24 tickLower,
        int24 tickUpper
    ) internal view returns (Position.Info storage position) {
        // 根据owner，tickLower和tickUpper进行位置的哈希值查找并返回对应的Info结构
        position = self[keccak256(abi.encodePacked(owner, tickLower, tickUpper))];
    }

    /// @notice Credits accumulated fees to a user's position
    /// @param self The individual position to update
    /// @param liquidityDelta The change in pool liquidity as a result of the position update
    /// @param feeGrowthInside0X128 The all-time fee growth in token0, per unit of liquidity, inside the position's tick boundaries
    /// @param feeGrowthInside1X128 The all-time fee growth in token1, per unit of liquidity, inside the position's tick boundaries
    function update(
        Info storage self,
        int128 liquidityDelta,
        uint256 feeGrowthInside0X128,
        uint256 feeGrowthInside1X128
    ) internal {
        Info memory _self = self;

        uint128 liquidityNext;
        if (liquidityDelta == 0) {
            require(_self.liquidity > 0, 'NP'); // 不允许流动性为0的位置被更新
            liquidityNext = _self.liquidity;
        } else {
            // 计算新的流动性数量
            liquidityNext = LiquidityMath.addDelta(_self.liquidity, liquidityDelta);
        }

        // 计算累积的手续费
        uint128 tokensOwed0 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside0X128 - _self.feeGrowthInside0LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );
        uint128 tokensOwed1 =
            uint128(
                FullMath.mulDiv(
                    feeGrowthInside1X128 - _self.feeGrowthInside1LastX128,
                    _self.liquidity,
                    FixedPoint128.Q128
                )
            );

        // 更新位置的信息
        if (liquidityDelta != 0) self.liquidity = liquidityNext; // 更新流动性
        self.feeGrowthInside0LastX128 = feeGrowthInside0X128; // 更新token0的手续费增长
        self.feeGrowthInside1LastX128 = feeGrowthInside1X128; // 更新token1的手续费增长
        if (tokensOwed0 > 0 || tokensOwed1 > 0) {
            // 允许溢出，在达到 type(uint128).max fees 前必须先提取
            self.tokensOwed0 += tokensOwed0; // 累计用户在token0中应得的手续费
            self.tokensOwed1 += tokensOwed1; // 累计用户在token1中应得的手续费
        }
    }
}
