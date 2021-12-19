// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ISwapV3.sol";

interface ISwapFlashLoanV3 is ISwapV3 {
    function flashLoan(
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes memory params
    ) external;
}