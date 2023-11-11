//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CarbonCredit.sol";
import "../IncentivePolicyMVPV3.sol";

//carbon coin 可能也会有使用期限，并且和carbon credit进行挂钩
//carbon coin不需要与ERC20挂钩，他需要与carbon credit进行挂钩，当carbon credit过期时，对应的carbon coin也会过期
contract CarbonCoinV2 {
    //decimal为18
    
    //不会修改
    address public immutable i_owner; //谁deploy这个contract,谁就是owner

    CarbonCredit belongedCarbonCredit; //所对应的carboncredit

    int number;

    uint256 CarbonCreditID; //链上的Carboncredit_ID和CarbonCoin_ID对应

    uint256 carbonCoinTimeStamp; //CarbonCoin创建时间

    uint256 carbonCoinRetireTimeStamp; //CarbonCoin退休时间

    uint256 AVALIABLE_TIME; //有效时间

    uint256 public round; //第几轮的carbon credit mint出来的carboncoin

    //name为SoCarbonTest, Symbol为SCRBT
    //所属的carboncredit上链address
    constructor(int _number,CarbonCredit _belongedCarbonCredit){
        i_owner = 0x060848d7a790ac7302b122a7Ba843CFA72829458; //之后改成guildMembers的地址
        belongedCarbonCredit = _belongedCarbonCredit; //所属carboncredit
        number = _number; //用户可以获取多少个coin
        AVALIABLE_TIME = _belongedCarbonCredit.getAVALIABLE_TIME(); //对应的CarbonCredit有效时长
        carbonCoinTimeStamp = _belongedCarbonCredit.getCarbonCreditTimeStamp(); //直接和carboncredit创建时间联动
        round = _belongedCarbonCredit.getRound(); //1025-看一下这个还有没有问题
        CarbonCreditID = _belongedCarbonCredit.getCarbonCreditID(); //设置ID值
        carbonCoinRetireTimeStamp = _belongedCarbonCredit.getCarbonCreditRetireTimeStamp(); //设置过期时间
    }


    //返回mint出来的数量
    function getNumber()view external returns(int){
        return number;
    }


    //返回有效时期
    function getAVALIABLE_TIME()view external returns(uint256){
        return AVALIABLE_TIME;
    }

    //设置有效时期
    function setAVALIABLE_TIME(uint256 _AVALIABLE_TIME) external {
        AVALIABLE_TIME = _AVALIABLE_TIME;
    }


    //设置对应CarbonCreditID
    function getCarbonCreditID() view external returns(uint256){
        return CarbonCreditID;
    }

    //设置对应CarbonCreditID
    function setCarbonCreditID(uint256 _ID) external {
        CarbonCreditID = _ID;
    }

    //获取carbon_coin 初始时间
    //直接和carboncredit创建时间联动
    function getCarbonCoinTimeStamp() view external returns(uint256){
        return carbonCoinTimeStamp;
    } 

    //获取carbon_coin退休时间
    //直接和carboncredit创建时间联动
    function setCarbonCoinRetireTimeStamp(uint256 _RetireTimeStamp) external{
        carbonCoinRetireTimeStamp =  _RetireTimeStamp;//创建时间+有效时间 = 过期时间
    } 
    
    //获取carbon_coin 退休时间
    //直接和carboncredit创建时间联动
    function getRetireTimeStamp() view external returns(uint256){
        return carbonCoinRetireTimeStamp;
    } 


}