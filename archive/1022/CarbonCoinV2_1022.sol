//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CarbonCredit.sol";
import "../IncentivePolicyMVPV2.sol";

//carbon coin 可能也会有使用期限，并且和carbon credit进行挂钩
//carbon coin不需要与ERC20挂钩，他需要与carbon credit进行挂钩，当carbon credit过期时，对应的carbon coin也会过期
contract CarbonCoinV2 {
    //decimal为18
    
    //不会修改
    address public immutable i_owner; //谁deploy这个contract,谁就是owner

    CarbonCredit belongedCarbonCredit; //所对应的carboncredit

    int number;

    uint256 CarbonCreditID; //链上的Carboncredit_ID和CarbonCoin_ID对应

    //name为SoCarbonTest, Symbol为SCRBT
    //所属的carboncredit上链address
    constructor(int _number,CarbonCredit _belongedCarbonCredit){
        i_owner = msg.sender; //谁 deploy the contract
        belongedCarbonCredit = _belongedCarbonCredit; //所属carboncredit
        number = _number; //用户可以获取多少个coin
    }

    //设置对应CarbonCreditID
    function getCarbonCreditID() view external returns(uint256){
        return CarbonCreditID;
    }

    //设置对应CarbonCreditID
    function setCarbonCreditID(uint256 _ID) external {
        CarbonCreditID = _ID;
    }

    //返回当前carbon coin 有效时间
    function getLimitTime(CarbonCredit _belongedCarbonCredit) external returns(uint256){
        uint256 CarbonCreditCreatTimeStamp = _belongedCarbonCredit.CreateCarbonCreditTimeStamp();
        return block.timestamp - CarbonCreditCreatTimeStamp;
    }


}