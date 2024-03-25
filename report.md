# **Paladin Audit Competition on Hats.finance** 


## Introduction to Hats.finance


Hats.finance builds autonomous security infrastructure for integration with major DeFi protocols to secure users' assets. 
It aims to be the decentralized choice for Web3 security, offering proactive security mechanisms like decentralized audit competitions and bug bounties. 
The protocol facilitates audit competitions to quickly secure smart contracts by having auditors compete, thereby reducing auditing costs and accelerating submissions. 
This aligns with their mission of fostering a robust, secure, and scalable Web3 ecosystem through decentralized security solutions​.

## About Hats Audit Competition


Hats Audit Competitions offer a unique and decentralized approach to enhancing the security of web3 projects. Leveraging the large collective expertise of hundreds of skilled auditors, these competitions foster a proactive bug hunting environment to fortify projects before their launch. Unlike traditional security assessments, Hats Audit Competitions operate on a time-based and results-driven model, ensuring that only successful auditors are rewarded for their contributions. This pay-for-results ethos not only allocates budgets more efficiently by paying exclusively for identified vulnerabilities but also retains funds if no issues are discovered. With a streamlined evaluation process, Hats prioritizes quality over quantity by rewarding the first submitter of a vulnerability, thus eliminating duplicate efforts and attracting top talent in web3 auditing. The process embodies Hats Finance's commitment to reducing fees, maintaining project control, and promoting high-quality security assessments, setting a new standard for decentralized security in the web3 space​​.

## Paladin Overview

Markets for Influence and Voting Rights across DeFi 

## Competition Details


- Type: A public audit competition hosted by Paladin
- Duration: 2 weeks
- Maximum Reward: $434,000,000,000,000,000
- Submissions: 74
- Total Payout: $389,992,400,000,000,000 distributed among 29 participants.

## Scope of Audit

## Project overview

Vote Flywheel is the 2nd part of the Paladin tokenomics, built upon Quest V2.  
This system allcoates PAL & an extra reward token, bundled as Loot, to be distributed to Quest voters as extra rewards.  
hPAL locks are the based voting power used in Vote Flywheel, and the Locks are converted into a decreasing balance called HolyPalPower (similar to a veToken), allowing to vote on Loot allocation & boosting Loot claim for voters.  
The PAL & extra token are distributed into the system each week (via the LootBudget contract), and is allocated between gauge listed in the LootVoteController contract (gauges listed come from the Curve, Balancer, Bunni, ... ecosystems, having Quests created for voting incentives). The allocation is split based on the votes received on each gauge, and divided for each Quest if the gauge has multiple Quests for the same period.  
The Loot is then distributed to users based on their amount of rewards from Quests, and boosted based on the hPalPower of the user. The Loot need to be created by the user, and can be claimed any time, but need to be vest for a given time to receive the full PAL amount.  
The HPalPower boosting can be delegated using the veBoost logic.  
Each week, all budget that was not allocated (because no Quests were created on the gauge, or the gauge cap over exceeded, or the users didn't have enough boosting power to receive all rewards, or PAL was slashed from the Loot vesting) is pushed back into the pending budget for future period, increasing the amount to allocate.  

## Audit competition scope

### Files in scope

|File|SLOC|Coverage|
|:-|:-:|:-:|
|HolyPalPower.sol | 211 | 94.305% |
|Loot.sol | 309 | 95.3125% |
|LootBudget.sol | 116 | 76.9975% |
|LootCreator.sol | 463 | 89.6% |
|LootGauge.sol | 93 | 92.8575% |
|LootReserve.sol | 100 | 100.00% |
|LootVoteController.sol | 668 | 98.17% |
|MultiMerkleDistributorV2.sol | 358 | 98.4375% |
|BoostV2.vy | 413 | -% |
|DelegationProxy.vy | 134 | -% |
|Total: | 2865 | 94.935% |

## Smart contracts

### HolyPalPower

Converts the hPAL Locks into a decreasing balance, similar to a veToken, with a Point structure (bias & slope). Allows to fetch past total locked supply and users past Locks

### Loot

Contract hosting the Loot reward logic. A Loot is a struct holding the data for PAL & extra rewards allocated to an user based on distribution, user voting rewards from Quest and boosting power from their hPAL locks. The PAL rewards in the Loot are vested for a given duration, and can be claimed beforehand but are slashed based on the reamining duration of the vesting. The extra rewards are not vested and not slashed.

### LootBudget

Contract holding the PAL & extra token budget for the Loot system and managing the periodical allocation to the LootReserve. This is to be later replaced by the LootGauge contract.

### LootCreator

Contract handling the Budget for gauges & Quests and the Loot creation. The budget allocated to each Quest for each period is based on the weight of a gauge received through votes on the LootVoteController, and the number of Quest on each gauge. All unallocated budget is pushed back to the pending budget for the next period. The rewards allocated to Quest voters are allocated by this contract (which creates the Loot), based on the Quest allocation, the user voting rewards and the user boosting power. All rewards not allocated to an user for its Loot (by lack of boosting power) are pushed back to the pending budget for the next period.
Each period budget is pulled from the LootBudget or the LootGauge.

### LootGauge

Contract meant to manage PAL & extra rewards budgets from a future budgeting system to be introduced later in the Paladin ecosystem. The budget received by this contract is then allocated to the LootCreator (and sent to the Loot REserve contract) 

### LootReserve

Contract holding all PAL & extra rewards allocated to the Loot system. The tokens are then sent to users when claiming Loot rewards.

### LootVoteController

Contract handling the vote logic for repartition of the global Loot budget between all the listed gauges for the Quest system. User voting power is based on their hPAL locks, transformed into a bias via the HolyPalPower contract. Votes are sticky, meaning users do not need to cast them every period, but can set their vote and update it periods later. Before an user can change its votes, a vote cooldown need to be respected.

### MultiMerkleDistributorV2

Updated version of the MultiMerkleDistributor used in Quest, distributing the voting rewards to voters. Modified to handle Loot triggers for Loot creations based on the rewards claimed by users, and the total rewards in each Quest periods.

### BoostV2

Modified version of the BoostV2 contract by Curve, allowing to delegate boosting power. Modified to handle the HolyPalPower contract, and to have checkpoints for past delegations of boosting power.

### DelegationProxy

Modified version of the DelegationProxy contract by Curve, to match the chnages in the BoostV2 contract & fallbacks to the hPAL contract if delegation is not active.

## High severity issues


- **Insufficient Validation in LootCreator Allows Indefinite Creation of Valid Loots**

  The issue pertains to the "LootCreator" contract which manages and distributes loots, allowing users to claim accumulated rewards. An underlying problem lies in its insufficient validation, enabling indefinite creation of valid loots. This loophole is exploited when a malicious user recreates any past loot, specifically their own, ensuing in the draining of PAL and extra tokens from the reserve. Further, it offsets the "pengingBudget" variable, adversely affecting future calculations no matter the age of the recreated loot. A proposed fix includes the setting of the "userQuestPeriodRewards" to zero when the loot for a specific user, quest, gauge, distributor, and period is created. This would halt further attempts to duplicate a loot. In the comments, a fix was implemented utilizing a new mapping that tracks creation alongside maintaining the "userQuestPeriodRewards" dataset. They highlight that there is only one claim per user per period and even if two claims happened, they would sum up, reflecting both claims in the loot to create.


  **Link**: [Issue #27](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/27)

## Medium severity issues


- **Issue in UpdateVestingDuration Function Potentially Leading to Unexpected User Slash**

  The issue stemmed from the function `updateVestingDuration` which is controlled by the owner. A scenario was highlighted where users could potentially be deprived of their benefits due to the dynamic ordering of transactions within blocks. During the occurrence where a user queues a transaction for a claim past the vesting period expecting full rewards, if the owner simultaneously queues a transaction to extend the vesting duration, these user(s) might be deprived of their expected rewards due to the unpredictable execution of these transactions (like unstable network conditions). Though the unclaimed funds are not lost, the users cannot recover the funds in full. A proposed fix is to include the `vestingDuration` during loot creation as part of the struct guaranteeing the user that the duration won't change adversely. The issue was eventually fixed in the provided pull request.


  **Link**: [Issue #5](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/5)


- **'_clearExpiredProxies' Function Array Handling Issue Causing Uncleared Proxies and Reverts**

  The issue pertains to the function '_clearExpiredProxies' in the code that's designed to clear past proxies for a user and liberate their blocked power. However, due to flawed array handling, some proxies might remain uncleared or the function might constantly revert. Two potential attack scenarios include skipping over proxies that have been moved up in the array during index swapping and encountering an out of bounds error during array length caching. It's suggested to fix these issues by not incrementing an index 'i' when an expired element is found and to cache the length of the storage variable instead of the memory variable. The issue has been rectified in a recent commit.


  **Link**: [Issue #11](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/11)


- **BoostV2 Contract Issue: Hardcoded ChainID May Lead to Replay Attacks After Hard Fork**

  The issue pertains to a contract, `BoostV2.vy`, implemented in Vyper language. It uses EIP 712-signed approvals through a 'permit()' function which includes a domain separator and a chainID. However, the chainID is fixed at the time of contract initialization and the domain separator is marked as immutable. Because of this, if the chain undergoes a hard fork and the chain id changes, the domain separator will be inaccurately calculated and cause potential replay attacks. To mitigate this issue, it is recommended that the domain separator should be dynamically recalculated using the chainId opcode each time it is requested, adhering to EIP712 best practices. To aid in correction, checking OpenZeppelin's EIP712.sol was suggested. A pull request was made to rectify the problem.


  **Link**: [Issue #16](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/16)


- **Issue on Griefing Users with Gas Fees and Blocking Multi Claims in MultiMerkleDistributorV2 Contract**

  The issue revolves around a potential exploit in the `MultiMerkleDistributorV2.sol` claim functions, where anyone can claim rewards on behalf of account owners, resulting in increased gas fees and reverting transactions for users. This issue occurs when an attacker front-runs the `multiClaim()` and `claimQuest()` calls, creating a clone of the last claim from the user, which causes the user to incur costs for previous claims, but the function still fails. This attack effectively disables any multi-claim functionality and forces users to use a single claim for each of their quest reward claims. Proposed solutions include disallowing arbitrary `account` address claims on `multiClaim()` and `claimQuest()` functions and only allowing the `msg.sender` to claim, or completely removing `multiClaim()` and `claimQuest()`, handling multiple claim loops on the front-end instead.


  **Link**: [Issue #18](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/18)


- **Issue with 'totalQuestPeriodRewards' Update in MultiMerkleDistributorV2 and LootCreator**

  The issue involves a potential miscalculation in quest allocation and loot creation due to the 'totalQuestPeriodRewards' value in 'LootCreator'. This value can only be set once via 'notifyDistributedQuestPeriod', a function of 'MultiMerkleDistributorV2'. This can become problematic when there are any changes to 'questRewardsPerPeriod' after LootCreator is notified, which causes it to use outdated data. The stale data can potentially lead to inaccurate reward calculations, and subsequently, economic losses. It's recommended to introduce an additional notify function from 'fixQuestPeriod' and 'emergencyUpdateQuestPeriod' to update 'totalQuestPeriodRewards'. The issue was addressed by the developers with some updates made to the supposed fix.


  **Link**: [Issue #23](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/23)


- **Second Claim Overwrites Previous One in UserQuestPeriodRewards**

  The issue highlights a problem where the `userQuestPeriodRewards` is overwritten during a second claim by a user, instead of incrementing the existing reward. This is due to the `notifyQuestClaim` function using an assignment operator (`=`), resulting in the first claim value being overwritten by the second claim. As a result, users receive fewer rewards than they should. This issue arises when an `emergencyUpdateQuestPeriod` occurs, potentially allowing multiple claims for a user. The proposed solution is to use the addition assignment operator (`+=`) instead of the assignment operator (`=`) in the `notifyQuestClaim` function to update the `userQuestPeriodRewards`, thereby preserving past rewards. The issue has been fixed in updates.


  **Link**: [Issue #29](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/29)


- **Decimals Conversion Issue in Quest Allocation Calculation within Distributor Contract**

  The Github issue pertains to the Distributor contract in the Quest Board, where the preferred QuestID and reward token can be added. The USDC token uses 6 decimals, unlike the DAI's 18 decimals. There's an issue with conversion when `updateQuestPeriod` is executed, causing potential computational errors. This arises due to the different decimal bases when processing the quest rewards. The discrepancy in the expected and actual values can lead to the malfunctioning of the reward allocation system. The solution proposed is to perform a conversion factor based on the difference in decimals. However, others suggested the conversion should be made only on the view function, arguing that any internal issues wouldn't affect the system, but better practices should be pursued.


  **Link**: [Issue #37](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/37)


- **Reward Duplication Issue When Gauge Weight Exceeds Cap in MultiMerkleDistributorV2**

  The Github issue highlights a bug which could result in reward duplication when a gauge's weight surpasses its cap. A functions call progression is outlined where 'updateQuestPeriod' function in 'MultiMerkleDistributorV2' calls the 'notifyDistributedQuestPeriod' function, influencing 'LootCreator'. The issue arises in the 'notifyDistributedQuestPeriod' function, where if a gauge's weight surpasses its cap, the excess amount is added to the pending budget for future periods, however, this excess isn't accounted as part of the allocated budget. An example is when a gauge's weight is 30% and the cap is 10%, hence 20% is added to the 'pending budget' with only 10% noted as allocated. A potential fix suggested includes marking the excess amounts as allocated as well in the function call to avoid duplication. This fix was implemented in a subsequent update.


  **Link**: [Issue #47](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/47)


- **Potential Vulnerabilities in `_updatePeriod` Function of LootCreator: Reward Claiming Issues and Suggested Solutions**

  The issue lies within the `_updatePeriod` function in the `LootCreator` of the software. An initialized variable `nextBudgetUpdatePeriod` may not always be up to date, leading to possible vulnerabilities. This issue arises when the `distributor` notifies the `LootCreator`, which then calls upon the `_updatePeriod` function. The unguaranteed updating of `nextBudgetUpdatePeriod` could cause misallocation of rewards whereby they may later become unobtainable. Furthermore, the `_createLoot` function may operate incorrectly due to an inconsistent update of `periodBlockCheckpoint[period]`. One proposed solution to the issue is modifying the `_updatePeriod` function to accommodate the possible lack of updates. Another solution is making `_findBlockNumberForTimestamp` public and using it in the `LootCreator`. Changes are still being tested for their effectiveness.


  **Link**: [Issue #51](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/51)


- **Issue Changing LootCreator in MultiMerkleDistributorV2, Leads to Division by Zero Error**

  The issue pertains to a function within the `MultiMerkleDistributorV2` called `lootCreator`, which can be changed via `setLootCreator`. The problem arises when a user attempts to claim from a past period after the `lootCreator` has been changed. The new `lootCreator` lacks information on past `totalQuestPeriodRewards` that was present in the old `lootCreator`, causing a division by zero when users want to 'createLoot' for a past period after `lootCreator` has changed. For this, it is recommended to introduce a proxy for `LootCreator` to eliminate the feature of changing the `lootCreator` address, effectively retaining the past state `totalQuestPeriodRewards`.


  **Link**: [Issue #56](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/56)


- **Unbounded Proxy Length in LootVoteController Could Lead to High Gas Costs and Denial of Service**

  The issue concerns the 'LootVoteController.sol' in which the proxy length is unbounded. This could result in a problem when the length of proxy is looped in 'LootVoteController::_clearExpiredProxies'. Every time a new proxy is added using 'LootVoteController::setVoterProxy', it adds to the 'currentUserProxyVoters' array. If a significant number of proxies accumulate, iterating over them could become very costly in terms of gas usage, going over the block gas limit. This would prevent future transactions from being executed, thus causing a denial-of-service (DoS) condition. The issue comes equipped with a Proof of Concept for easier understandability. The proposed solution involves setting an upper limit to the number of proxies an approved manager can add and allow users to disapprove previous approved managers in case they try malicious acts.


  **Link**: [Issue #64](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/64)

## Low severity issues


- **Contracts require redeployment if address remains zero: Implement zero address checks**

  The issue pertains to the omission of zero address checks in contract constructors, which could inadvertently lead to deployment error. Accordingly, if any of the addresses remain zero upon deployment, contracts would need to be redeployed. The user suggests implementing zero address checks to prevent accidents. A fix has been applied and another concern about vyper contracts' `__init__()` calls was raised.


  **Link**: [Issue #1](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/1)


- **Limit Unbounded Values in LootBudget.sol to Avoid Bad Configurations**

  The issue points out the absence of boundaries for expected `uint256` values in two functions, `updatePalWeeklyBudget()` and `updateExtraWeeklyBudget()`, of the `contracts/LootBudget.sol` script. This could potentially lead to bad configurations related to weekly budgets. The recommended solution is to set reasonable lower and upper bounds for the weekly extra tokens and pal budget. A suggestion was made to also allow changing the upper limit through a separate function to maintain flexibility. The fix was accepted and implemented.


  **Link**: [Issue #7](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/7)


- **LootVoteController Lacks Function To Revoke Proxy Manager Approval**

  The issue involves the `LootVoteController` in GitHub, which includes an `approveProxyManager` function but lacks an unapprove feature. This omission makes it impossible for users to revoke a proxy manager if needed, an issue highlighted with an example in which a previous proxy was compromised. A change in the code that includes both approve and revoke provisions within a single function is recommended and has been demonstrated in a proof of concept. This suggested solution has been implemented and fixed.


  **Link**: [Issue #12](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/12)


- **Lack of Specific Error Information in Loot::claimMultipleLoot() Function**

  The issue is regarding the `Loot::claimMultipleLoot()` function which reverts in case a loot is claimed or vesting hasn't started but doesn't inform which id caused the revert. This leads the user to remove ids or make some calls to the contract to identify the problem. The proposed solution is to include the loot `id` as a parameter for the custom errors. The issue has been corrected in a recent commit.


  **Link**: [Issue #15](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/15)


- **Unbounded For Loop Causes High Gas Consumption in Functions**

  The issue pertains to substantial user gas fee losses due to several functions in the codebase employing an unbounded for loop with an array input. When long inputs are provided, these functions can consume the entire block gas limit, causing expensive reverting transactions. It's recommended to set a maximum allowed length for these functions to prevent high gas consumption. The issue has been fixed with the implementation of length checks.


  **Link**: [Issue #17](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/17)


- **Issue with LootVoteController's Loop Duration Exceeding Lock Period**

  The issue raises a concern about the 'LootVoteController' in which a loop runs 100 times to update gauge weight and total weight for all past non-updated periods. This loop is equivalent to almost two years, causing problems for assets locked for a maximum of 2 years. Since the update gauge and total will not reach the current time, it fails to update the correct gauge and total weight. The issue has since been fixed.


  **Link**: [Issue #21](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/21)


- **False Assumption in MultiMerkleDistributorV2 Leads to Manipulation and Loss of Rewards**

  The issue focuses on the MultiMerkleDistributorV2 contract where some functions check if a period is listed for a Quest or not by assessing if `questRewardsPerPeriod[questID][period]==0`. It's wrongly assumed that when the value is zero, the period isn't listed. However, the value can also become zero when all rewards are claimed. This false assumption can result in users potentially losing rewards. The recommendation is to use an extra mapping to track the created quest periods correctly.


  **Link**: [Issue #33](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/33)


- **Issue with LootReserve's resetMaxAllowance function and USDT approval**

  The issue is focused on the `LootReserve` where `pal` and `extraToken` are immutable. Within the test files, `extraToken` uses DAI, an algorithmic stable coin. The user suggests that there is potential for `extraToken` to be the USDT stable coin, pointing to the `resetMaxAllowance()` function which approves `extraToken` to `uint256 max`. They stress that the known issue with USDT is it needs to set approve to zero first and recommend considering approval to zero first.


  **Link**: [Issue #36](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/36)


- **Inconsistency in Updating LootCreator Across Multiple Contracts**

  The issue relates to the `LootCreator` function in some contracts, which may change in the future. While some contracts allow for the updating of `LootCreator`, others including `LootGauge` and `LootBudget` do not, as `lootCreator` is immutable in these. A proposed solution involves incorporating an update function. A fix has been implemented in a commit on GitHub.


  **Link**: [Issue #52](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/52)


- **Issue with _createLoot Function in LootCreator When Distributor Removed**

  The issue revolves around the `_createLoot` function in LootCreator.sol. If a distributor is removed, users can't create past loot which could pose problems if a user  waits for a batch creation using `createMultipleLoots`. The suggested fix is to add a condition check, `totalQuestPeriodRewards` not being 0, to ensure users can still create loot from a removed distributor.


  **Link**: [Issue #59](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/59)


- **Issue with CreateLoot Function's Division by Zero Error in LootCreator.solar**

  The issue pertains to the `_createLoot` function in the LootCreator.sol file, specifically the `_getQuestAllocationForPeriod` checking. A problem arises if `nbQuestForGauge == 0 || questTotalRewards == 0` as it returns `Allocation(0, 0)`. This zero allocation isn't utilized for short-circuit return flow. If allocation is zero, the code can revert due to divide by zero on Line 484. The issuer suggests adding an immediate return when Allocation is 0, saving potential gas consumption, aligning with other return scenarios in the code-block. The issue has been fixed.


  **Link**: [Issue #60](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/60)


- **Issue in Gauge Voting Leads to Incorrect Updates and Impacts Future Calculations**

  An inconsistency in update handling occurs when a user's vote 'lock end time' synchronizes with the start of an upcoming period, leading to an incorrect update. This discrepancy will permanently influence subsequent 'gauge' weight calculations, causing users who vote on this 'gauge' to continually receive lower-than-expected rewards, given that the 'gauge' weight is lower than the actual value. A simple proposed solution is to modify the check `
if(vars.userLockEnd < vars.nextPeriod)` to `if(vars.userLockEnd <= vars.nextPeriod)`.


  **Link**: [Issue #62](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/62)


- **LootVoteController.updateDistributor Assigns Duplicate Distributor to Quest Board**

  The issue concerns the `updateDistributor` function in the `LootVoteController` contract, which assigns a new distributor to a quest board without verifying if the distributor is previously assigned to another board. The proposed solution suggests checking if a distributor is already assigned before the assignment, thus preventing the same distributor from being linked to multiple boards. The issue has been resolved in a specific commit.


  **Link**: [Issue #66](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/66)


- **DelegationProxy: Implement Two-Step Ownership Transfer Mechanism for Future Admins**

  The issue involves a flaw in DelegationProxy contract which lets an owner change ownership and emergency admin in two steps but doesn't satisfy the two-step-ownership-transfer mechanism. This can cause problems if the new admin accounts set by the owner are invalid, inactive or uncontrolled. The recommended solution is to implement a two-step-ownership-transfer mechanism in which future admins claim their role before the owner sets these addresses as current admins.


  **Link**: [Issue #69](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/69)


- **Missing Valid Range Check in addNewGauge and updateGaugeCap Functions**

  The problem lies with the 'addNewGauge' and 'updateGaugeCap' functions as they miss out on checking the valid range of the gauge. The maximum cap is '1e18' (100%) and isn't verified within these functions. Defaults return when the cap is marked as '0', but this isn't defined as the lower limit. Incorrect inputs can lead to miscalculations in 'gaugeBudgetPerPeriod'. For preventing such errors, validations within acceptable ranges are suggested. The issue was resolved in a later commit.


  **Link**: [Issue #71](https://github.com/hats-finance/Paladin-0x1610bfde27e57b068af7f38aec3d2a7b1d146989/issues/71)



## Conclusion

The Paladin audit of Hats.finance reveals several weaknesses in the code that open the platform to potential manipulation and exploitation. These include issues with logic validation in the LootCreator contract, concerns about potential for unexpected user slash in the updateVestingDuration function, and unbounded values in the LootBudget.sol that might cause bad configurations. However, it was also noted that Hats.finance has taken precaution to include corrective measures, demonstrated by steps to rectify these issues. Although certain risks were identified, the hats.finance team was proactive in resolving the identified issues, and remedies for all the issues have been provided, analysed and assessed. The project appears to be committed to maintaining security and efficiency of their system.

## Disclaimer


This report does not assert that the audited contracts are completely secure. Continuous review and comprehensive testing are advised before deploying critical smart contracts./n/n
The Paladin audit competition illustrates the collaborative effort in identifying and rectifying potential vulnerabilities, enhancing the overall security and functionality of the platform.


Hats.finance does not provide any guarantee or warranty regarding the security of this project. All smart contract software should be used at the sole risk and responsibility of users.

