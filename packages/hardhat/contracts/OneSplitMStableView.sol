// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./libraries/DisableFlags.sol";
import "./OneSplitViewWrapBase.sol";

abstract contract OneSplitMStableView is OneSplitViewWrapBase {
    using DisableFlags for uint256;

    function getExpectedReturnWithGas(
        IERC20 fromToken,
        IERC20 destToken,
        uint256 amount,
        uint256 parts,
        uint256 flags,
        uint256 destTokenEthPriceTimesGasPrice
    ) virtual override
        public
        view
        returns(
            uint256 returnAmount,
            uint256 estimateGasAmount,
            uint256[] memory distribution
        )
    {
        if (fromToken == destToken) {
            return (amount, 0, new uint256[](DEXES_COUNT));
        }

        if (flags.check(FLAG_DISABLE_ALL_WRAP_SOURCES) == flags.check(FLAG_DISABLE_MSTABLE_MUSD)) {
            if (fromToken == IERC20(musd)) {
                {
                    (bool valid1,, uint256 res1,) = musd_helper.getRedeemValidity(musd, amount, destToken);
                    if (valid1) {
                        return (res1, 300_000, new uint256[](DEXES_COUNT));
                    }
                }

                (bool valid,, address token) = musd_helper.suggestRedeemAsset(musd);
                if (valid) {
                    (,, returnAmount,) = musd_helper.getRedeemValidity(musd, amount, IERC20(token));
                    if (IERC20(token) != destToken) {
                        (returnAmount, estimateGasAmount, distribution) = super.getExpectedReturnWithGas(
                            IERC20(token),
                            destToken,
                            returnAmount,
                            parts,
                            flags,
                            destTokenEthPriceTimesGasPrice
                        );
                    } else {
                        distribution = new uint256[](DEXES_COUNT);
                    }

                    return (returnAmount, estimateGasAmount + 300_000, distribution);
                }
            }

            if (destToken == IERC20(musd)) {
                if (fromToken == usdc || fromToken == dai || fromToken == usdt || fromToken == tusd) {
                    (,, returnAmount) = musd.getSwapOutput(fromToken, destToken, amount);
                    return (returnAmount, 300_000, new uint256[](DEXES_COUNT));
                }
                else {
                    IERC20 _destToken = destToken;
                    (bool valid,, address token) = musd_helper.suggestMintAsset(_destToken);
                    if (valid) {
                        if (IERC20(token) != fromToken) {
                            (returnAmount, estimateGasAmount, distribution) = super.getExpectedReturnWithGas(
                                fromToken,
                                IERC20(token),
                                amount,
                                parts,
                                flags,
                                _scaleDestTokenEthPriceTimesGasPrice(
                                    _destToken,
                                    IERC20(token),
                                    destTokenEthPriceTimesGasPrice
                                )
                            );
                        } else {
                            returnAmount = amount;
                        }
                        (,, returnAmount) = musd.getSwapOutput(IERC20(token), _destToken, returnAmount);
                        return (returnAmount, estimateGasAmount + 300_000, distribution);
                    }
                }
            }
        }

        return super.getExpectedReturnWithGas(
            fromToken,
            destToken,
            amount,
            parts,
            flags,
            destTokenEthPriceTimesGasPrice
        );
    }
}
