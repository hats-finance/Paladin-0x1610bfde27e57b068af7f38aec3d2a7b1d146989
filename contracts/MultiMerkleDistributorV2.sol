//██████╗  █████╗ ██╗      █████╗ ██████╗ ██╗███╗   ██╗
//██╔══██╗██╔══██╗██║     ██╔══██╗██╔══██╗██║████╗  ██║
//██████╔╝███████║██║     ███████║██║  ██║██║██╔██╗ ██║
//██╔═══╝ ██╔══██║██║     ██╔══██║██║  ██║██║██║╚██╗██║
//██║     ██║  ██║███████╗██║  ██║██████╔╝██║██║ ╚████║
//╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝╚═╝  ╚═══╝
 

//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "./utils/Owner.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libraries/Errors.sol";
import {ILootCreator} from "./interfaces/ILootCreator.sol";

/** @title Quest Multi Merkle Distributor V2 */
/// @author Paladin
/*
    Contract holds ERC20 rewards from Quests
    Can handle multiple MerkleRoots
    V2 to handle LOOT triggers
*/

contract MultiMerkleDistributorV2 is Owner, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /** @notice Seconds in a Week */
    uint256 private constant WEEK = 604800;

    /** @notice Mapping listing the reward token associated to each Quest ID */
    // QuestID => reward token
    mapping(uint256 => address) public questRewardToken;

    /** @notice Mapping of tokens this contract is or was distributing */
    // token address => boolean
    mapping(address => bool) public rewardTokens;

    // Periods: timestamp => start of a week, used as a voting period 
    // in the Curve GaugeController though the timestamp / WEEK *  WEEK logic.
    // Handled through the QuestManager contract.
    // Those can be fetched through this contract when they are closed, or through the QuestManager contract.

    /** @notice List of Closed QuestPeriods by Quest ID */
    // QuestID => array of periods
    mapping(uint256 => uint256[]) public questClosedPeriods;

    /** @notice Merkle Root for each period of a Quest (indexed by Quest ID) */
    // QuestID => period => merkleRoot
    mapping(uint256 => mapping(uint256 => bytes32)) public questMerkleRootPerPeriod;

    /** @notice Amount of rewards for each period of a Quest (indexed by Quest ID) */
    // QuestID => period => totalRewardsAmount
    mapping(uint256 => mapping(uint256 => uint256)) public questRewardsPerPeriod;

    /** @notice BitMap of claims for each period of a Quest */
    // QuestID => period => claimedBitMap
    // This is a packed array of booleans.
    mapping(uint256 => mapping(uint256 => mapping(uint256 => uint256))) private questPeriodClaimedBitMap;

    /** @notice Address of the QuestBoard contract */
    address public immutable questBoard;

    /** @notice Address of the Loot Creator contract */
    address public lootCreator;


    // Events

    /** @notice Event emitted when a user Claims */
    event Claimed(
        uint256 indexed questID,
        uint256 indexed period,
        uint256 index,
        uint256 amount,
        address rewardToken,
        address indexed account
    );
    /** @notice Event emitted when a New Quest is added */
    event NewQuest(uint256 indexed questID, address rewardToken);
    /** @notice Event emitted when a Period of a Quest is updated (when the Merkle Root is added) */
    event QuestPeriodUpdated(uint256 indexed questID, uint256 indexed period, bytes32 merkleRoot);
    /** @notice Event emitted when the Loot Creator address is updated */
    event LootCreatorUpdated(address indexed oldCreator, address indexed newCreator);


    // Modifier

    /** @notice Check the caller is either the admin or the QuestBoard contract */
    modifier onlyAllowed(){
        if(msg.sender != questBoard && msg.sender != owner()) revert Errors.CallerNotAllowed();
        _;
    }


    // Constructor

    constructor(address _questBoard){
        if(_questBoard == address(0)) revert Errors.AddressZero();

        questBoard = _questBoard;
    }

    // Functions
   
    /**
    * @notice Checks if the rewards were claimed for a user on a given period
    * @dev Checks if the rewards were claimed for a user (based on the index) on a given period
    * @param questID ID of the Quest
    * @param period Amount of underlying to borrow
    * @param index Index of the claim
    * @return bool : true if already claimed
    */
    function isClaimed(uint256 questID, uint256 period, uint256 index) public view returns (bool) {
        uint256 claimedWordIndex = index >> 8;
        uint256 claimedBitIndex = index & 0xff;
        uint256 claimedWord = questPeriodClaimedBitMap[questID][period][claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask != 0;
    }
   
    /**
    * @dev Sets the rewards as claimed for the index on the given period
    * @param questID ID of the Quest
    * @param period Timestamp of the period
    * @param index Index of the claim
    */
    function _setClaimed(uint256 questID, uint256 period, uint256 index) private {
        uint256 claimedWordIndex = index >> 8;
        uint256 claimedBitIndex = index & 0xff;
        questPeriodClaimedBitMap[questID][period][claimedWordIndex] |= (1 << claimedBitIndex);
    }

    //Basic Claim   
    /**
    * @notice Claims the reward for a user for a given period of a Quest
    * @dev Claims the reward for a user for a given period of a Quest if the correct proof was given
    * @param questID ID of the Quest
    * @param period Timestamp of the period
    * @param index Index in the Merkle Tree
    * @param account Address of the user claiming the rewards
    * @param amount Amount of rewards to claim
    * @param merkleProof Proof to claim the rewards
    */
    function claim(uint256 questID, uint256 period, uint256 index, address account, uint256 amount, bytes32[] calldata merkleProof) public nonReentrant {
        if(account == address(0)) revert Errors.AddressZero();
        if(questMerkleRootPerPeriod[questID][period] == 0) revert Errors.MerkleRootNotUpdated();
        if(isClaimed(questID, period, index)) revert Errors.AlreadyClaimed();

        // Check that the given parameters match the given Proof
        bytes32 node = keccak256(abi.encodePacked(questID, period, index, account, amount));
        if(!MerkleProof.verify(merkleProof, questMerkleRootPerPeriod[questID][period], node)) revert Errors.InvalidProof();

        // Set the rewards as claimed for that period
        // And transfer the rewards to the user
        address rewardToken = questRewardToken[questID];
        _setClaimed(questID, period, index);
        questRewardsPerPeriod[questID][period] -= amount;
        IERC20(rewardToken).safeTransfer(account, amount);

        _triggerCreateLoot(account, questID, period, amount);

        emit Claimed(questID, period, index, amount, rewardToken, account);
    }


    //Struct ClaimParams
    struct ClaimParams {
        uint256 questID;
        uint256 period;
        uint256 index;
        uint256 amount;
        bytes32[] merkleProof;
    }


    //Multi Claim   
    /**
    * @notice Claims multiple rewards for a given list
    * @dev Calls the claim() method for each entry in the claims array
    * @param account Address of the user claiming the rewards
    * @param claims List of ClaimParams struct data to claim
    */
    function multiClaim(address account, ClaimParams[] calldata claims) external {
        uint256 length = claims.length;
        
        if(length == 0) revert Errors.EmptyParameters();

        for(uint256 i; i < length;){
            claim(claims[i].questID, claims[i].period, claims[i].index, account, claims[i].amount, claims[i].merkleProof);

            unchecked{ ++i; }
        }
    }


    //FullQuest Claim (form of Multi Claim but for only one Quest => only one ERC20 transfer)
    //Only works for the given periods (in ClaimParams) for the Quest. Any omitted period will be skipped   
    /**
    * @notice Claims the reward for all the given periods of a Quest, and transfer all the rewards at once
    * @dev Sums up all the rewards for given periods of a Quest, and executes only one transfer
    * @param account Address of the user claiming the rewards
    * @param questID ID of the Quest
    * @param claims List of ClaimParams struct data to claim
    */
    function claimQuest(address account, uint256 questID, ClaimParams[] calldata claims) external nonReentrant {
        if(account == address(0)) revert Errors.AddressZero();
        uint256 length = claims.length;

        if(length == 0) revert Errors.EmptyParameters();

        // Total amount claimable, to transfer at once
        uint256 totalClaimAmount;
        address rewardToken = questRewardToken[questID];

        for(uint256 i; i < length;){
            if(claims[i].questID != questID) revert Errors.IncorrectQuestID();
            if(questMerkleRootPerPeriod[questID][claims[i].period] == 0) revert Errors.MerkleRootNotUpdated();
            if(isClaimed(questID, claims[i].period, claims[i].index)) revert Errors.AlreadyClaimed();

            // For each period given, if the proof matches the given parameters, 
            // set as claimed and add to the to total to transfer
            bytes32 node = keccak256(abi.encodePacked(questID, claims[i].period, claims[i].index, account, claims[i].amount));
            if(!MerkleProof.verify(claims[i].merkleProof, questMerkleRootPerPeriod[questID][claims[i].period], node)) revert Errors.InvalidProof();

            _setClaimed(questID, claims[i].period, claims[i].index);
            questRewardsPerPeriod[questID][claims[i].period] -= claims[i].amount;
            totalClaimAmount += claims[i].amount;

            // Trigger Loot hook to store claim data for later Loot creation
            _triggerCreateLoot(
                account,
                questID,
                claims[i].period,
                claims[i].amount
            );

            emit Claimed(questID, claims[i].period, claims[i].index, claims[i].amount, rewardToken, account);

            unchecked{ ++i; }
        }

        // Transfer the total claimed amount
        IERC20(rewardToken).safeTransfer(account, totalClaimAmount);
    }

   
    /**
    * @notice Returns all current Closed periods for the given Quest ID
    * @dev Returns all current Closed periods for the given Quest ID
    * @param questID ID of the Quest
    * @return uint256[] : List of closed periods
    */
    function getClosedPeriodsByQuests(uint256 questID) external view returns (uint256[] memory) {
        return questClosedPeriods[questID];
    }

    /**
    * @notice Triggers the notification of a Quest Claim to the Loot Creator contract
    * @dev Triggers the notification of a Quest Claim to the Loot Creator contract
    * @param user Address of the user
    * @param questID ID of the Quest
    * @param questID Timestamp of the period
    * @param claimedAmount Amount of rewards claimed
    */
    function _triggerCreateLoot(address user, uint256 questID, uint256 period, uint256 claimedAmount) internal {
        if(lootCreator != address(0)) {
            ILootCreator(lootCreator).notifyQuestClaim(
                user,
                questID,
                period,
                claimedAmount
            );
        }
    }



    // Manager functions
   
    /**
    * @notice Adds a new Quest to the listing
    * @dev Adds a new Quest ID and the associated reward token
    * @param questID ID of the Quest
    * @param token Address of the ERC20 reward token
    * @return bool : success
    */
    function addQuest(uint256 questID, address token) external returns(bool) {
        if(msg.sender != questBoard) revert Errors.CallerNotAllowed();
        if(questRewardToken[questID] != address(0)) revert Errors.QuestAlreadyListed();
        if(token == address(0)) revert Errors.TokenNotWhitelisted();

        // Add a new Quest using the QuestID, and list the reward token for that Quest
        questRewardToken[questID] = token;

        if(!rewardTokens[token]) rewardTokens[token] = true;

        emit NewQuest(questID, token);

        return true;
    }

    /**
    * @notice Adds a new period & the rewards of this period for a Quest
    * @dev Adds a new period & the rewards of this period for a Quest
    * @param questID ID of the Quest
    * @param period Timestamp of the period
    * @param totalRewardAmount Total amount of rewards to distribute for the period
    * @return bool : success
    */
    function addQuestPeriod(uint256 questID, uint256 period, uint256 totalRewardAmount) external returns(bool) {
        period = (period / WEEK) * WEEK;
        if(msg.sender != questBoard) revert Errors.CallerNotAllowed();
        if(questRewardToken[questID] == address(0)) revert Errors.QuestNotListed();
        if(questRewardsPerPeriod[questID][period] != 0) revert Errors.PeriodAlreadyUpdated();
        if(period == 0) revert Errors.IncorrectPeriod();
        if(totalRewardAmount == 0) revert Errors.NullAmount();

        questRewardsPerPeriod[questID][period] = totalRewardAmount;

        return true;
    }


    function fixQuestPeriod(uint256 questID, uint256 period, uint256 newTotalRewardAmount) external returns(bool) {
        if(msg.sender != questBoard) revert Errors.CallerNotAllowed();
        period = (period / WEEK) * WEEK;
        if(questRewardToken[questID] == address(0)) revert Errors.QuestNotListed();
        if(period == 0) revert Errors.IncorrectPeriod();
        if(questRewardsPerPeriod[questID][period] == 0) revert Errors.PeriodNotListed();

        uint256 previousTotalRewardAmount = questRewardsPerPeriod[questID][period];

        questRewardsPerPeriod[questID][period] = newTotalRewardAmount;

        if(previousTotalRewardAmount > newTotalRewardAmount){
            // Send back the extra amount of reward token that was incorrectly sent
            // In the case of missing reward token, the Board will send them to this contract

            uint256 extraAmount = previousTotalRewardAmount - newTotalRewardAmount;
            IERC20(questRewardToken[questID]).safeTransfer(questBoard, extraAmount);
        }

        return true;
    }
   
    /**
    * @notice Updates the period of a Quest by adding the Merkle Root
    * @dev Add the Merkle Root for the eriod of the given Quest
    * @param questID ID of the Quest
    * @param period timestamp of the period
    * @param totalAmount sum of all rewards for the Merkle Tree
    * @param merkleRoot MerkleRoot to add
    * @return bool: success
    */
    function updateQuestPeriod(uint256 questID, uint256 period, uint256 totalAmount, bytes32 merkleRoot) external onlyAllowed returns(bool) {
        period = (period / WEEK) * WEEK;
        if(questRewardToken[questID] == address(0)) revert Errors.QuestNotListed();
        if(period == 0) revert Errors.IncorrectPeriod();
        if(questRewardsPerPeriod[questID][period] == 0) revert Errors.PeriodNotListed();
        if(questMerkleRootPerPeriod[questID][period] != 0) revert Errors.PeriodAlreadyUpdated();
        if(merkleRoot == 0) revert Errors.EmptyMerkleRoot();

        // Add a new Closed Period for the Quest
        questClosedPeriods[questID].push(period);

        if(totalAmount != questRewardsPerPeriod[questID][period]) revert Errors.IncorrectRewardAmount();

        // Add the new MerkleRoot for that Closed Period
        questMerkleRootPerPeriod[questID][period] = merkleRoot;

        // If a Loot Creator is set, notify it of the new Quest Period distributed
        if(lootCreator != address(0)) {
            ILootCreator(lootCreator).notifyDistributedQuestPeriod(questID, period, totalAmount);
        }

        emit QuestPeriodUpdated(questID, period, merkleRoot);

        return true;
    }


    //  Admin functions

    /**
    * @notice Sets the address for the Loot Creator
    * @dev Sets the address for the Loot Creator
    * @param _lootCreator Address of the Loot Creator
    */
    function setLootCreator(address _lootCreator) external onlyOwner {
        address oldCreator = lootCreator;
        lootCreator = _lootCreator;

        emit LootCreatorUpdated(oldCreator, _lootCreator);
    }
   
    /**
    * @notice Recovers ERC2O tokens sent by mistake to the contract
    * @dev Recovers ERC2O tokens sent by mistake to the contract
    * @param token Address of the EC2O token
    * @return bool: success
    */
    function recoverERC20(address token) external onlyOwner nonReentrant returns(bool) {
        if(rewardTokens[token]) revert Errors.CannotRecoverToken();
        uint256 amount = IERC20(token).balanceOf(address(this));
        if(amount == 0) revert Errors.NullAmount();
        IERC20(token).safeTransfer(owner(), amount);

        return true;
    }

    // 
    /**
    * @notice Allows to update the MerkleRoot for a given period of a Quest if the current Root is incorrect
    * @dev Updates the MerkleRoot for the period of the Quest
    * @param questID ID of the Quest
    * @param period Timestamp of the period
    * @param merkleRoot New MerkleRoot to add
    * @return bool : success
    */
    function emergencyUpdateQuestPeriod(uint256 questID, uint256 period, uint256 addedRewardAmount, bytes32 merkleRoot) external onlyOwner returns(bool) {
        // In case the given MerkleRoot was incorrect:
        // Process:
        // 1 - block claims for the Quest period by using this method to set an incorrect MerkleRoot, where no proof matches the root
        // 2 - prepare a new Merkle Tree, taking in account user previous claims on that period, and missing/overpaid rewards
        //      a - for all new claims to be added, set them after the last index of the previous Merkle Tree
        //      b - for users that did not claim, keep the same index, and adjust the amount to claim if needed
        //      c - for indexes that were claimed, place an empty node in the Merkle Tree (with an amount at 0 & the address 0xdead as the account)
        // 3 - update the Quest period with the correct MerkleRoot
        // (no need to change the Bitmap, as the new MerkleTree will account for the indexes already claimed)

        period = (period / WEEK) * WEEK;
        if(questRewardToken[questID] == address(0)) revert Errors.QuestNotListed();
        if(period == 0) revert Errors.IncorrectPeriod();
        if(questMerkleRootPerPeriod[questID][period] == 0) revert Errors.PeriodNotClosed();
        if(merkleRoot == 0) revert Errors.EmptyMerkleRoot();

        questMerkleRootPerPeriod[questID][period] = merkleRoot;

        questRewardsPerPeriod[questID][period] += addedRewardAmount;

        emit QuestPeriodUpdated(questID, period, merkleRoot);

        return true;
    }

}