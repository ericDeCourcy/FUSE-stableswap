pragma solidity 0.6.12;

import "../contracts-v3_4/token/ERC20/IERC20.sol";
interface IMockMintableERC20 is IERC20 {

    function mintPreset() external;

    function mintAmount(uint256 _mintAmount) external;

    function mintAmountTo(uint256 _mintAmount, address _to) external;

    function mintPresetTo(address _to) external;

}