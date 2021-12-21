pragma solidity 0.6.12;

interface IStableSwapHolder {

    // this returns the pool which this holder is bound to
    function getPool() external view returns (address pool);

    function swap
    ( 
        uint indexIn, 
        uint indexOut, 
        uint dx,
        uint minDy,
        address to
    ) external;
}