//把第三方得到的碳信用 通过 smart contract上链, 该contract只能organization的人操作上链
//（是否有API可以直接验证该carbon credit的一些参数是否正确）

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./CarbonCoinV2.sol";

import "../IncentivePolicyMVPV2.sol";

contract CarbonCredit{
    //把CarbonCredit上链

    uint256 ID; //ID

    address carbonCreditOwner; //谁持有该CarbonCredit

    //address CarbonCreditCreater; //谁创建了该CarbonCredit

    uint createTimestamp; //多久创建的该CarbonCredit

    uint retireTimestamp; //多久退休

    uint256 number; //carboncredit的数量

    uint256 public round; //第几轮的carbon credit

    bool isBurn; //该carboncredit是否burn

    bool isUsed; //该Carboncredit是否使用过

    uint256 AVALIABLE_TIME; //有效时间

    uint256[] IDByThirdParty; //第三方认证的唯一编码的carboncredit

    uint256 price; //CarbonCreditPrice;

    constructor(){
        carbonCreditOwner = 0x060848d7a790ac7302b122a7Ba843CFA72829458; //之后改成guildMembers的地址
        AVALIABLE_TIME = 365 days;
    }


    //返价格
    function getPrice()view external returns(uint256){
        return price;
    }

    //设置数量
    //因为第三方验证的时间以及验证后的carboncredit数量不定，所以每一次就把验证后的carboncredit作为整体来进行上链以及mint carboncoin
    //carbon credit有可能为小数
    function setPrice(uint256 _price) external {
        price = _price;
    }

    //返回数量
    function getNumber()view external returns(uint256){
        return number;
    }

    //设置数量
    //因为第三方验证的时间以及验证后的carboncredit数量不定，所以每一次就把验证后的carboncredit作为整体来进行上链以及mint carboncoin
    //carbon credit有可能为小数
    function setNumber(uint256 _number) external {
        number = _number;
    }

    //返回有效时期
    function getAVALIABLE_TIME()view external returns(uint256){
        return AVALIABLE_TIME;
    }

    //设置有效时期
    function setAVALIABLE_TIME(uint256 _AVALIABLE_TIME) external {
        AVALIABLE_TIME = _AVALIABLE_TIME;
    }


    function getCarbonCreditID() view external returns(uint256){
        return ID;
    }

    function setCarbonCreditID(uint256 _ID) external {
        ID = _ID;
    }

    function getCarbonCreditOwner() view external returns(address){
        return carbonCreditOwner;
    }

    function setCarbonCreditOwner(address _carbonCreditOwner) external {
        carbonCreditOwner = _carbonCreditOwner;
    }

    //是第几轮得到的carbon credit
    function getRound() view external returns(uint256){
        return round;
    }

    //是第几轮得到的carbon credit
    function setRound(uint256 _round) external {
        round = _round;
    }

    function getIsBurn() view external returns(bool){
        return isBurn;
    }

    function setIsBurn(bool _isBurn) external {
        isBurn = _isBurn;
    }

    function getIsUsed() view external returns(bool){
        return isUsed;
    }

    function setIsUsed(bool _isUsed) external {
        isUsed = _isUsed;
    }


    //创建该carboncredit的timestamp
    function CreateCarbonCreditTimeStamp() external returns(uint256){
        createTimestamp = block.timestamp;
        return createTimestamp;
    }



    //需要检测该carboncredit是否过期
    //1009:这个地方可能会做修改,对应mint出来的carbon coin会burn掉
    //如何进行burn掉对应的carboncoin--需要修改
    function burnTheRetringCarbonCredit(IncentivePolicyMVPV2 IPAddress) public returns(bool){
        //有效期限是有限的，但未定
        require(block.timestamp - createTimestamp > AVALIABLE_TIME,"the carbon credit is not retired!");
        bool flag = IPAddress.burnTheRetringCarbonCoin(ID);
        if(flag){
          isBurn = true;
        }else{
            //输出一些原因
        }
        return true; //表示burn成功
    }


    //用户买carbon credit, owner发生改变
    //查看是否过期
    //问题：价格怎么去定？
    function transferToCarbonCredit(uint256 value, IncentivePolicyMVPV2 IPAddress) external {
        require(!isBurn,"this Carbon Credit is burned!"); //查看该carboncredit是否过期
        //判断当前carbon credit是否过期？过期就直接burn掉
        burnTheRetringCarbonCredit(IPAddress);
        //msg.sender 花费 value个token 从 carbonCreditOwner 手里买 carbon credit
        IPAddress.purchaseTheCarbonCredit(value,msg.sender);
        carbonCreditOwner = msg.sender; //owner转换
    }



    //1. 需要检测 该carboncredit是否过期？
    //2. 需要检测 该carboncredit是否已经使用过？
    function verify(CarbonCredit carboncredit) external returns(bool){
        //uint carboncreditCreateTimeStamp = carboncredit.CreateCarbonCreditTimeStamp(); //获取创建该carboncredit的timestamp
        //先判断是否使用or过期
        require(!carboncredit.getIsUsed(),"this Carbon Credit is Used!");
        require(!carboncredit.getIsBurn(),"this Carbon Credit is burned!");
        //判断当前carbon credit是否过期？
        carboncredit.setIsUsed(true); //该carboncredit已经使用过
        return true; //返回1000个carbon_coin
    }

    //1. 当carboncredit过期，搜索所有用户的carbon_coin是否存在对应的carbon_credit,有就全部burn掉
}