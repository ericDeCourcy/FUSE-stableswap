pragma solidity 0.6.12;

import "../contracts-v3_4/token/ERC20/ERC20Capped.sol";

contract MockERC20Mintable is ERC20Capped {

    uint256 public presetMintAmount;

    /*
    * @notice Sets decimals, name, symbol, cap, and "preset" mint amount for this mock token
    * @dev This token should never be used for storing real value as it is arbitrarily mintable
    * @param name_ The name of the token (suggested standard is "Fake-XYZ")
    * @param symbol_ The symbol for the token (suggested standard is "Fake-XYZ")
    * @param decimals_ The decimals of the token
    * @param cap_ The maximum token units which can exist
    * @param presetMintAmount_ The amount that is minted when calling mintPreset or mintPresetTo
    */
    constructor (string memory name_, string memory symbol_, uint8 decimals_, uint256 cap_, uint256 presetMintAmount_)
        public ERC20Capped(cap_)
        ERC20(name_, symbol_) 
    {
        _setupDecimals(decimals_);  //sets the stored value (`_decimals`) to whatever we want (`decimals_`)
        presetMintAmount = presetMintAmount_;

    } 


    /* 
    * @notice Mints the preset amount to msg.sender
    * @notice Will fail if cap is exceeded
    */
    function mintPreset() public {
        _mint(msg.sender, presetMintAmount);
    }

    /* 
    * @notice Mints an arbitrary amount to msg.sender
    * @notice Will fail if cap is exceeded
    * @param _mintAmount Amount to mint to msg.sender
    */
    function mintAmount(uint256 _mintAmount) public {
        _mint(msg.sender, _mintAmount);
    }
    
    /* 
    * @notice Mints an arbitrary amount to any user
    * @notice Will fail if cap is exceeded
    * @notice Will fail if attempting to mint to the zero address
    * @param _mintAmount Amount to mint to some user
    * @param _to Address to mint tokens to
    */
    function mintAmountTo(uint256 _mintAmount, address _to) public {
        _mint(_to, _mintAmount);
    }

    /* 
    * @notice Mints preset amount to any user
    * @notice Will fail if cap is exceeded
    * @notice Will fail if attempting to mint to the zero address
    * @param _to Address to mint tokens to
    */
    function mintPresetTo(address _to) public {
        _mint(_to, presetMintAmount);
    }

    /*
    * @notice The fallback function will simply call mintPreset. 
    *   This way, sending funds to the contract automatically mints some tokens
    */
    fallback() external {
        mintPreset();
    }
}