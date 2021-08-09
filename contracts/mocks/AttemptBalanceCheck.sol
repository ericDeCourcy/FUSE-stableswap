pragma solidity 0.6.12;

import "../contracts-v3_4/token/ERC20/IERC20.sol";

contract attemptBalanceCheck {

    function attemptBalaceCheck(address _token, address _account) public returns (uint256)
    {
        return IERC20(_token).balanceOf(_account);
    }
}