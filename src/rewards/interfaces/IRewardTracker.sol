// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IRewardTracker {
    error RewardTracker_ActionDisbaled();
    error RewardTracker_InvalidAmount();
    error RewardTracker_ZeroAddress();
    error RewardTracker_AlreadyInitialized();
    error RewardTracker_Forbidden();
    error RewardTracker_InvalidDepositToken();
    error RewardTracker_AmountExceedsStake();
    error RewardTracker_AmountExceedsBalance();
    error RewardTracker_FailedToRemoveDepositToken();
    error RewardTracker_PositionAlreadyExists();
    error RewardTracker_InvalidTier();

    event Claim(address indexed receiver, uint256 indexed wethAmount, uint256 indexed usdcAmount);

    struct StakeData {
        uint256 depositBalance;
        uint256 stakedAmount;
        uint256 averageStakedAmount;
        uint256 claimableWethReward;
        uint256 claimableUsdcReward;
        uint256 prevCumulativeWethPerToken;
        uint256 prevCumulativeUsdcPerToken;
        uint256 cumulativeWethRewards;
        uint256 cumulativeUsdcRewards;
    }

    struct LockData {
        uint256 depositAmount;
        uint40 lockedAt;
        uint40 unlockDate;
        address owner;
    }

    function claim(address _receiver) external returns (uint256 wethAmount, uint256 usdcAmount);
    function claimable(address _account) external view returns (uint256 wethAmount, uint256 usdcAmount);
    function getStakeData(address _account) external view returns (StakeData memory);
    function initialize(address _distributor, address _marketFactory, address _positionManager, address _router)
        external;
    function stakeForAccount(address _fundingAccount, address _account, uint256 _amount, uint40 _stakeDuration)
        external;
    function unstakeForAccount(address _account, uint256 _amount, address _receiver) external;
}
