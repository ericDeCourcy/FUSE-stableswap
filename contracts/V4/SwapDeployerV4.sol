// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../contracts-v3_4/access/Ownable.sol";
import "../contracts-v3_4/proxy/Clones.sol";
import "../interfaces/ISwapFlashLoanV4.sol";

contract SwapDeployerV4 is Ownable {
    event NewSwapPool(
        address indexed deployer,
        address swapAddress,
        IERC20[] pooledTokens
    );

    constructor() public Ownable() {}

    function deploy(
        address swapFlashLoanAddress,
        IERC20[] memory _pooledTokens,
        uint8[] memory decimals,
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _a,
        uint256 _fee,
        uint256 _adminFee,
        address lpTokenTargetAddress,
        address lpRewardsTargetAddress
    ) external returns (address) {
        address swapClone = Clones.clone(swapFlashLoanAddress);
        ISwapFlashLoanV4(swapClone).initialize(
            _pooledTokens,
            decimals,
            lpTokenName,
            lpTokenSymbol,
            _a,
            _fee,
            _adminFee,
            lpTokenTargetAddress,
            lpRewardsTargetAddress
        );
        Ownable(swapClone).transferOwnership(owner());
        emit NewSwapPool(msg.sender, swapClone, _pooledTokens);
        return swapClone;
    }
}
