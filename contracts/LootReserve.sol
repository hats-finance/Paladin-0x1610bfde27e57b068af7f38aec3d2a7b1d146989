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
import "./libraries/Errors.sol";
import "./utils/Owner.sol";

/** @title Loot Reserve contract */
/// @author Paladin
/*
    Reserve holding all tokens (PAL & extra token) to be distributed
    through the Loot contract
*/

contract LootReserve is Owner {
    using SafeERC20 for IERC20;

    // Storage

    /** @notice PAL token contract */
    IERC20 public immutable pal;
    /** @notice Extra token contract */
    IERC20 public immutable extraToken;

    /** @notice Address of the Loot contract */
    address public  loot; // Gas savings this can be immutable and set while deployment to save gas.


    // Events

    /** @notice Event emitted when the contract is initialized */
    event Init(address loot);
    /** @notice Event emitted when the Max allowance is set for the Loot contract */
    event MaxAllowanceSet(address indexed token, address indexed spender);
    /** @notice Event emitted when the Reserve is canceled and token claimed back */
    event CancelReserve(uint256 retrievedPalAmount, uint256 retrievedExtraAmount);


    // Constructor & Init

    constructor(
        address _pal,
        address _extraToken
    ) payable{ // Gas savings
        pal = IERC20(_pal);
        extraToken = IERC20(_extraToken);
    }

    /**
    * @notice Initialize the contract
    * @dev Initialize the contract
    * @param _loot Address of the Loot contract
    */
    function init(address _loot) external payable onlyOwner {  // Gas savings
        if(loot != address(0)) revert Errors.CreatorAlreadySet();
        loot = _loot;

        pal.safeIncreaseAllowance(_loot, type(uint256).max);
        extraToken.safeIncreaseAllowance(_loot, type(uint256).max);

        emit MaxAllowanceSet(address(pal), _loot);
        emit MaxAllowanceSet(address(extraToken), _loot);

        emit Init(_loot);
    }


    // View functions

    /**
    * @notice Get this contract balances
    * @dev Get this contract PAL & extra token balances
    * @return palBalance (uint256) : PAL token balance
    * @return extraBalance (uint256) : extra token balance
    */
    function getBalances() external view returns(uint256 palBalance, uint256 extraBalance){
        palBalance = pal.balanceOf(address(this));
        extraBalance = extraToken.balanceOf(address(this));
    }

    /**
    * @notice Get this contract remaining allowances for the Loot contract
    * @dev Get this contract remaining allowances in PAL & extra token for the Loot contract
    * @return palAllowance (uint256) : PAL remaining allowance
    * @return extraAllowance (uint256) : extra remaining allowance
    */
    function getRemainingAllowances() external view returns(uint256 palAllowance, uint256 extraAllowance){
        address localLoot = loot;
        palAllowance = pal.allowance(address(this), localLoot);
        extraAllowance = extraToken.allowance(address(this), localLoot);
    }


    // Admin functions

    /**
    * @notice Resets the allowances for the Loot contract
    * @dev Resets the allowances for the Loot contract to max uint256
    */
    function resetMaxAllowance() external payable onlyOwner { // Gas savings
        address localLoot = loot;
        pal.approve(localLoot, type(uint256).max);
        extraToken.approve(localLoot, type(uint256).max);

        emit MaxAllowanceSet(address(pal), localLoot);
        emit MaxAllowanceSet(address(extraToken), localLoot);
    }

    /**
    * @notice Empty this contract and send all tokens to the owner
    * @dev Empty this contract and send all tokens to the owner
    */
    function emptyReserve() external payable onlyOwner { // Gas savings
        uint256 palBalance = pal.balanceOf(address(this));
        uint256 extraBalance = extraToken.balanceOf(address(this));

        pal.safeTransfer(owner(), palBalance);
        extraToken.safeTransfer(owner(), extraBalance);

        emit CancelReserve(palBalance, extraBalance);
    }

}