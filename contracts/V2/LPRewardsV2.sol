pragma solidity 0.6.12;

import "../contracts-v3_4/math/Math.sol";
import "../contracts-v3_4/math/SafeMath.sol";
import "../contracts-upgradeable-v3_4/access/OwnableUpgradeable.sol";
import "../contracts-v3_4/token/ERC20/IERC20.sol";

contract LPRewardsV2 is OwnableUpgradeable{
    using SafeMath for uint256;

    struct Reward {
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    // given a type of token being disbursed, return it's `Reward` object
    mapping(address => Reward) rewards;

    // userRewardPerTokenPaid[user][rewardToken] = amount paid to user for that rewardToken
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    
    // userRewardPerTokenEarned[user][rewardToken] = amount of rewards which can be directly transferred to a user 
    // this replaces "rewards[account]" in synthetix's Unipool implementation 
    mapping(address => mapping(address => uint256)) public userRewardPerTokenEarned;

    mapping(uint256 => address) public indexToRewardAddress;
    mapping(address => uint256) public rewardAddressToIndex;

    event RewardAdded(uint256 reward, address indexed rewardToken);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, address indexed rewardToken, uint256 reward);
    event DefaultDurationChanged(uint256 duration);

    address LPToken;

    // Defines the duration for any new rewards distribution.
    // Will only affect a rewards distribution when notifyRewardAmount is called
    uint256 newRewardDuration;

    bool initialized = false;

    uint256 numRewardTokens;


    function initialize(address _lpToken, address owner) external initializer returns(bool) 
    {
        __Ownable_init_unchained();
        
        LPToken = _lpToken;     // stores global address for lpToken
        return true;
    }

    // @notice Updates all reward token accruals for a given account
    // @dev This should be called by the SwapV2 contract whenever LPToken balance changes occur
    function updateAllRewards(address _account) external {
        for(uint x = 0; x < numRewardTokens; x++ )
        {
            _updateReward(_account, indexToRewardAddress[x]);
        }
    }

    function _updateReward(address _account, address _rewardToken) public {
        rewards[_rewardToken].rewardPerTokenStored = rewardPerToken(_rewardToken);
        rewards[_rewardToken].lastUpdateTime = lastTimeRewardApplicable(_rewardToken); //TODO: what if this token has never been added? Will these setters be ok?

        // TODO-POSTV2: will this shortcut be safe? 
        // if account != 0, and userRewardPerTokenPaid == rewardPerToken then return early
            // avoids calling `earned` and avoids setting two storage slots

        if (_account != address(0)) {
            userRewardPerTokenEarned[_account][_rewardToken] = earned(_account, _rewardToken); 
            userRewardPerTokenPaid[_account][_rewardToken] = rewards[_rewardToken].rewardPerTokenStored;
        }
    }

    // updates an account's accrued rewards for a rewardToken
    modifier updateReward(address _account, address _rewardToken) {
        _updateReward(_account, _rewardToken);
        _;
    }

    function lastTimeRewardApplicable(address _rewardToken) public view returns (uint256) {
        return Math.min(block.timestamp, rewards[_rewardToken].periodFinish);
    }

    function rewardPerToken(address _rewardToken) public view returns (uint256) {
        if (IERC20(LPToken).totalSupply() == 0) {   
            return rewards[_rewardToken].rewardPerTokenStored;
        }
        return
            rewards[_rewardToken].rewardPerTokenStored.add(
                lastTimeRewardApplicable(_rewardToken)
                    .sub(rewards[_rewardToken].lastUpdateTime)
                    .mul(rewards[_rewardToken].rewardRate)
                    .mul(1e18)                          
                    .div(IERC20(LPToken).totalSupply())     
            );
    }

    // Returns the amount of reward tokens which would be transferred to the user if calling getReward
    function earned(address _account, address _rewardToken) public view returns (uint256) {
        return
            IERC20(LPToken).balanceOf(_account)
                .mul(rewardPerToken(_rewardToken).sub(userRewardPerTokenPaid[_account][_rewardToken]))
                .div(1e18)
                .add(userRewardPerTokenEarned[_account][_rewardToken]);  
    }

    function getReward(address _rewardToken) 
        public 
        updateReward(msg.sender, _rewardToken) 
        returns(uint256 rewardAmountPaid)
    { 
        return _getReward(_rewardToken, msg.sender);
    }

    function getRewardFor(address _rewardToken, address _user)
        public
        updateReward(_user, _rewardToken)
        returns(uint256 rewardAmountPaid)
    {
        return _getReward(_rewardToken, _user);
    }

    function _getReward(address _rewardToken, address _user)
        internal
        returns(uint256 rewardAmountPaid)
    {
        uint256 reward = userRewardPerTokenEarned[_user][_rewardToken]; //This will always be up to date because updateReward will set it to result of function earned
        
        if (reward > 0) 
        {
            userRewardPerTokenEarned[_user][_rewardToken] = 0;
            IERC20(_rewardToken).transfer(_user, reward);   
            emit RewardPaid(_user, _rewardToken, reward);
        }

        return reward;
    }
    
    

    // @dev Add more funds to a reward distribution or start a new one
    // @param _reward Amount of reward
    function notifyRewardAmount(uint256 _reward, address _rewardToken)
        external
        onlyOwner 
        updateReward(address(0), _rewardToken)
        returns(uint256 periodFinish, uint256 rewardRate)
    {
        if (block.timestamp >= rewards[_rewardToken].periodFinish) 
        {        // if starting new rewards or reviving a finished rewards distribution
            rewards[_rewardToken].rewardRate = _reward.div(newRewardDuration);

            // in case we are adding a new token...
            // numRewardTokens == 0 only if we have no rewards tokens
            // otherwise, if rewardAddressToIndex == 0 AND indexToRewardAddress[0] != _rewardToken, the mismatch indicates
            //      that rewardAddressToIndex has not been initialized and this token is also new
            if(numRewardTokens == 0 || (rewardAddressToIndex[_rewardToken] == 0 && indexToRewardAddress[0] != _rewardToken))
            {
                rewardAddressToIndex[_rewardToken] = numRewardTokens;  
                indexToRewardAddress[numRewardTokens] = _rewardToken;
                numRewardTokens++;
            }
        } 
        else 
        {
            uint256 remainingTime = rewards[_rewardToken].periodFinish.sub(block.timestamp);
            uint256 leftoverRewards = remainingTime.mul(rewards[_rewardToken].rewardRate);
            rewards[_rewardToken].rewardRate = _reward.add(leftoverRewards).div(newRewardDuration);
        }
        rewards[_rewardToken].lastUpdateTime = block.timestamp;
        rewards[_rewardToken].periodFinish = block.timestamp.add(newRewardDuration);

        IERC20(_rewardToken).transferFrom(msg.sender, address(this), _reward);

        emit RewardAdded(_reward, _rewardToken);

        return(rewards[_rewardToken].periodFinish, rewards[_rewardToken].rewardRate);
    }

    // @notice Change the reward duration. This will only take effect next time you call notifyRewardAmount. 
    //      Thus, this should be typcially called immediately before calling notifyRewardAmount.
    // @dev By having default duration only matter when calling notifyRewardAmount, we can change reward distributions independently.
    //      This allows us to effect reward amount and reward rate atomically by calling notifyRewardAmount
    // @param _duration The new value for newRewardDuration in seconds
    function setNewRewardDuration(uint256 _duration)
        external
        onlyOwner
        // we don't need to call update reward because this will not affect any active rewards
    {
        require(_duration > 0, "_duration must be greater than 0");     //TODO-POSTV2: consider if there are cases where duration==0 might be useful
        newRewardDuration = _duration;

        emit DefaultDurationChanged(_duration);
    }


    // helpful getters...
    function getRewardsInfo(address _rewardToken) 
        public 
        view
        returns(
            uint256 periodFinish,
            uint256 rewardRate,
            uint256 lastUpdateTime,
            uint256 rewardPerTokenStored
        )
    {
        return(
            rewards[_rewardToken].periodFinish,
            rewards[_rewardToken].rewardRate,
            rewards[_rewardToken].lastUpdateTime,
            rewards[_rewardToken].rewardPerTokenStored
        );
    } 

    function getRewardPerTokenEarned( address _user, address _rewardToken)
        public 
        view
        returns(uint256)
    {
        return userRewardPerTokenEarned[_user][_rewardToken];
    }

    function getRewardPerTokenPaid(address _user, address _rewardToken)
    public 
        view
        returns(uint256)
    {
        return userRewardPerTokenPaid[_user][_rewardToken];
    }
}