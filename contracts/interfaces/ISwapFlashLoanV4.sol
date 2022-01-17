// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ISwapV4.sol";

interface ISwapFlashLoanV4 is ISwapV4 {
    function flashLoan(
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes memory params
    ) external;
}