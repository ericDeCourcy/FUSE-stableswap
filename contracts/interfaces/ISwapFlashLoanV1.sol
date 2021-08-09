// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./ISwapV1.sol";

interface ISwapFlashLoanV1 is ISwapV1 {
    function flashLoan(
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes memory params
    ) external;
}
