//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "./library/ABDKMathQuad.sol";
import "./Tokenomics/CarbonCredit.sol";
import "./Tokenomics/CarbonCoinV2.sol";

contract IncentivePolicyMVPV2{
    
    int car_cost = 182; //g/km
    int bus_cost = 25; //g/km
    int heavy_rail_cost = 155; //g/km

    //1. 取消了新手期，换成了固定的target_allowance作为baseline, 并且前4周都不会改变
    //到第四周时，需要获取前四周的carbon_emission的平均值来update target_allowance, 之后每半年进行一次更新。
   
   //只能运行16个 variables
    struct Voter{
        int target_carbon_allowance; //当前的allowance, 如果为0，那么说明就是新来的
        int[] carbon_cost_per_week; //通过sensor来得到这周花费的碳消耗
        //int reputation_score;//不是确定值，需要用户输入，这部分只能用户知道，其他人不知道

        int currentWeek_carbonSaving; //该用户当前这个星期节省了多少碳？----需要交给第三方机构去验证
        int allCarbonSaving; //该用户总共节省了多少碳 (已经交给了第三方机构验证过)

        uint256 AllCarbonCoin; //用户拥有的carboncoin为多少

        CarbonCoinV2[] carboncoin; //有多少种carboncoin

        int decreasedAllowancePercentage_; //allowance_settlement_voting中的这个变量
        //int Locked_governanceToken; //锁住的token
        //先暂时设计成：由chairperson来执行,之后会通过时间来控制
        int isVoted; //表示这一周是否投票过?，比如到下周需要重新投票的时候，isVoted又会变成0,表示可以重新投票
        uint round;
        Travel_mode sensor_travel_mode; //出行方式(通过sensor得到的)
        Travel_mode expect_travel_mode; //期望的下周的出行方式(通过用户自己输入)
        //根据round指向每周该用户节省了多少碳排放量
        mapping(uint=>int) verifyCarbonSavingEachRound; //每round节省的碳量 (全局round)
        mapping(uint=>int) verifyCarbonSavingEachRoundOnlyForUser; //每周节省的碳量 (user自己能看到的自己的round)
        mapping(CarbonCoinV2 => uint256) TheNumberOfEachTypeCarbonCoin;//每种carbonCoin的数量有多少？
    }


    struct Travel_mode{
        int passenger_cars;
        int bus;
        int heavy_rail;
        int walking;
        int cycling;

    }

    //根据address来得到不同的Voter
    mapping(address => Voter) public voters;

    mapping(uint=> address[]) public EachRoundCarbonSavingUsers; //每周有哪些用户节省了碳排放

    mapping(CarbonCredit=>bool) public verifiedCarbonCredit; //验证该carboncredit是否有使用

    mapping(uint => bool) public getVerifiedRound; //哪些round已经被验证过，并且无法再使用对应的carboncoin了

    mapping(uint=>int) public getCarbonCoinAmountForSpecificRound; //由第三方验证成功，并且成功获得carbocoin

    mapping(address => int) public EachUserSaveCarbonForVerifiedSpecificRound; //当前验证的round每个用户节省了多少carbon
    
    mapping(address => bool) public verifyUniqueCarbonSavingUser;
    
    //每周所有用户节省了多少碳排放量
    int[] public verifyAllUserCarbonSaving; //每周需要验证所有用户节省的碳储量

    //每周节省的碳排放量通过第三方验证成了多少carbonCredit
    int[] public verifyAllUserCarbonCredit; //每周第三方认证成功的CarbonCredit数量


    Voter[] public voters_; //投票的人数
    //Voter[] public allUsers; //所有用户

    address[] public allUserAddress; //所有用户的钱包地址
    address[] public carbonSavingUsers; //本周节省了碳的用户的钱包地址

    address[] public EachCarbonSavingUserForVerifiedSpecificRound; //当前验证的round每个用户的地址

    int initialTargetAllowance = 182; //g/km
    int fresh_round = 4;

    //int[] decreasedAllowancePercentage; //存储每一个不同user的decreasedAllowancePercentage
    int votingUser; //总人数
    address chairperson; //主席
    uint round; //当前IncentivePoliciy开展了多少周

    uint256 allCarbonCreditAmounts; //总验证成功的carboncredit数量
    uint256 CurrentCarbonCredit; //新验证成功的carboncredit数量

    int THRESHOLD; //设置一个pool,当节省的carbon达到pool才需要给第三方进行验证

    int currentCarbonSavingValue;//当前节省了多少carbon,是否能够达到Threshold

    int verifiedCarbonSavingValueForSepecificRound;//交给第三方验证的CarbonSavingValue

    CarbonCoinV2 cc_1;


    //msg.sender: 调用该contract的人
    constructor() public {
        chairperson = msg.sender;
        round = 0;
        allCarbonCreditAmounts = 0;
        CurrentCarbonCredit = 0; 
        THRESHOLD = 50000;
        currentCarbonSavingValue = 0;
    }



    //返回THRESHOLD
    function getTHRESHOLD() view external returns (int){
        return THRESHOLD;
    }

    //设置THRESHOLD
    function setTHRESHOLD(int _THRESHOLD) external{
        THRESHOLD = _THRESHOLD;
    }

    
    //谁都可以加入还是需要审核？
    //刚加入dao的时候才需要执行这个function
    function initialNewUser() public{
        require(voters[msg.sender].target_carbon_allowance == 0,"you've already exist!");
        Voter storage sender = voters[msg.sender];
        sender.target_carbon_allowance = initialTargetAllowance;
        sender.round = 0; //新手
        sender.isVoted = 0;
        //sender.reputation_score = 1;
        sender.currentWeek_carbonSaving = 0;
        allUserAddress.push(msg.sender); //添加新用户
        votingUser += 1;
    }

    //通过sensor得到自己的每一种交通工具所消耗的km
    //需要前端获取用户的每个travel的值然后放到这里面
    function setTravelDataBySensor(Travel_mode memory _travel_mode) external {
        voters[msg.sender].sensor_travel_mode.passenger_cars = _travel_mode.passenger_cars;
        voters[msg.sender].sensor_travel_mode.bus = _travel_mode.bus;
        voters[msg.sender].sensor_travel_mode.heavy_rail = _travel_mode.heavy_rail;
        voters[msg.sender].sensor_travel_mode.walking = _travel_mode.walking;
        voters[msg.sender].sensor_travel_mode.cycling = _travel_mode.cycling;
    }

    //测试用的，之后会删除
    function TestExpectedDataByInput(Travel_mode memory _expect_mode) public {
        voters[msg.sender].expect_travel_mode.passenger_cars = _expect_mode.passenger_cars;
        voters[msg.sender].expect_travel_mode.bus = _expect_mode.bus;
        voters[msg.sender].expect_travel_mode.heavy_rail = _expect_mode.heavy_rail;
        voters[msg.sender].expect_travel_mode.walking = _expect_mode.walking;
        voters[msg.sender].expect_travel_mode.cycling = _expect_mode.cycling;
    }


    //之后的步骤，MVP阶段不涉及
    // function setExpectPassengerCars(int _passenger_cars) public {
    //     //还没有执行到 getDecreasedAllowancePercentage()
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.passenger_cars = _passenger_cars;
    // }

    // function setExpectBus(int _bus) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.bus = _bus;
    // }

    // function setExpectHeavyRail(int _heavy_rail) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.heavy_rail = _heavy_rail;
    // }

    // function setExpectWalking(int _walking) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.walking = _walking;
    // }

    // function setExpectCycling(int _cycling) public {
    //     require(voters[msg.sender].isVoted < 2, "you've already voted this week!");
    //     voters[msg.sender].expect_travel_mode.cycling = _cycling;
    // }


    //计算每个用户的carbon_emission
    function calculateCurrentCarbonCost() external{
        Voter storage sender = voters[msg.sender];
        //还没有初始化
        require(voters[msg.sender].target_carbon_allowance != 0,"you have not initialize!");
        require(voters[msg.sender].isVoted == 0, "you cannot operate this function");
        //得到总花费km数
        int sum = (sender.sensor_travel_mode.passenger_cars+
                    sender.sensor_travel_mode.bus+
                    sender.sensor_travel_mode.heavy_rail+
                    sender.sensor_travel_mode.walking+
                    sender.sensor_travel_mode.cycling);
        
        require(sum != 0, "your sensor is empty, try to contact the chairperson XXXXXX");

        bytes16 carbon_quota = 0;
        int carbon_cost = 0;
        bytes16 carbon_cost_per_week = 0;
        bytes16 residual_carbon_quota = 0;

        //target_allowance * 总km数
        carbon_quota = ABDKMathQuad.mul(
            ABDKMathQuad.fromInt(sender.target_carbon_allowance),
            ABDKMathQuad.fromInt(sum)
        );
        //每种出行方式所消耗的碳排放*对应出行方式的km数
        carbon_cost = (sender.sensor_travel_mode.passenger_cars*car_cost+
                        sender.sensor_travel_mode.bus*bus_cost+
                        sender.sensor_travel_mode.heavy_rail*heavy_rail_cost);
        //当前的碳排放量
        carbon_cost_per_week = ABDKMathQuad.div(ABDKMathQuad.fromInt(carbon_cost),ABDKMathQuad.fromInt(sum));

        //预计碳排放量 - 实际碳排量
        //为正 说明节省了碳排放量，可以发放carbon coin, 为负说明 超过了预计的碳排放量，不扣除 carbon coin
        residual_carbon_quota = ABDKMathQuad.div(ABDKMathQuad.sub(
        carbon_quota, ABDKMathQuad.fromInt(carbon_cost)),ABDKMathQuad.fromInt(1000));

        sender.carbon_cost_per_week.push(ABDKMathQuad.toInt(carbon_cost_per_week)); //添加该用户的这周的碳排放量

        //用户这周可能获取的carbonSaving（还未被第三方进行认证）
        if(residual_carbon_quota > 0){
            sender.currentWeek_carbonSaving = ABDKMathQuad.toInt(residual_carbon_quota); 
        }

        sender.verifyCarbonSavingEachRound[round] = sender.currentWeek_carbonSaving; //添加该round,该用户节省了多少碳排放量

        //添加该round,该用户节省了多少碳排放量,只有用户自己能看到
        sender.verifyCarbonSavingEachRoundOnlyForUser[sender.round] = sender.currentWeek_carbonSaving; 

        sender.isVoted++; //表示该用户执行过该方法
        sender.round++;
    }


    //每到每个星期五的23:59:59 来进行统计所有用户这周节省了多少碳
    //超出了原本碳计划的用户就不计算在内
    //需要倒计时功能 ---- 在前端去添加该功能，然后调用该函数
    function calculateEachUserCarbonSavings() external returns(int,uint){
        int currentWeekCarbonSavings = 0;
        for(uint i = 0; i < allUserAddress.length; i++){
            currentWeekCarbonSavings += voters[allUserAddress[i]].currentWeek_carbonSaving; //获取每个用户节省了多少碳
            carbonSavingUsers.push(allUserAddress[i]); //添加节省了carbon的用户的地址
        }
        EachRoundCarbonSavingUsers[round] = carbonSavingUsers; //该round有多少用户节省了碳
        verifyAllUserCarbonSaving[round] = currentWeekCarbonSavings; //该round节省了多少碳

        //需要判断当前累积的carbon值是否达到了threshold,到达了就可以提交给第三方验证
        if(currentCarbonSavingValue + currentWeekCarbonSavings >= THRESHOLD){
            verifiedCarbonSavingValueForSepecificRound = currentCarbonSavingValue + currentWeekCarbonSavings;
            verifyToThirdParty(round,verifiedCarbonSavingValueForSepecificRound); //可以给到第三方进行验证
            currentCarbonSavingValue = 0; //变为初始值
        }else{
            currentCarbonSavingValue += currentWeekCarbonSavings; //加上这周节省了多少碳
        }
        round++;
        return (currentWeekCarbonSavings,round); //获取当前周节省了多少碳,以及当前周是多少
    }


    //发送给guild member
    event verify(uint256 roundToVerifyThirdParty, int _carbonSavingValue, address sender);

    //直到多少round, carbon值已经达标，可以提交给第三方 提醒guild member
    function verifyToThirdParty(uint256 _roundToVerifyThirdParty, int carbonSaving)internal{
        //address硬编码，需要修改
        emit verify(_roundToVerifyThirdParty, carbonSaving, 0x060848d7a790ac7302b122a7Ba843CFA72829458);
    }


    //根据carboncredit的数量，mint出carboncoin, 再分给不同的用户
    //需要得到每周哪些用户节省了carbon, 并且节省了多少，来算比例
    //获取carboncredit的时间是不定的，所以获取carboncredit的时间与我们每周结算的时间不同
    function mintCarbonCoinForSpecificRound(CarbonCredit carbonCredit) external {
        require(msg.sender == chairperson, "only chairperson can use this function");
        int carboncoinAmount = 0;
        //需要先验证
        if(verifiedCarbonCredit[carbonCredit] == false){
            if(carbonCredit.verify(carbonCredit)){
                carboncoinAmount = 1000; //新mint出来的carboncoin
            }
            //注意，这里的round可能是几周一起得到的（因为有可能5周或者6周才能满足threshold,才能交给第三方验证）
            //举个例子，第一次验证时间可能为第四周，那第二次验证的时间可能为第9周
            getCarbonCoinAmountForSpecificRound[carbonCredit.getRound()] += carboncoinAmount; 
        }
        cc_1 = new CarbonCoinV2(carboncoinAmount,carbonCredit);
        cc_1.setCarbonCreditID(carbonCredit.getCarbonCreditID()); //ID一致
        verifiedCarbonCredit[carbonCredit] = true; //该carboncredit已经使用过，避免重复使用
    }



    //根据carboncredit mint出来的token数量，按照碳节省量的比例分发给每个用户
    //因为第三方验证的时间以及验证后的carboncredit数量不定，所以每一次就把验证后的carboncredit作为整体来进行上链以及mint carboncoin
    //每一次验证的时间可能是几周也可能是十几周
    //thisRound为给第三方验证的那个Round
    function distributeToEachUsers(uint thisRound) external{
        require(msg.sender == chairperson, "only chairperson can use this function");
        require(getVerifiedRound[thisRound] != true, "this round has been verified!");
        require(getCarbonCoinAmountForSpecificRound[thisRound] != 0, "this round doesn't have carboncoin to mint!");
        int carboncoinAmountThisRound = getCarbonCoinAmountForSpecificRound[thisRound]; //该轮获得的carboncoin

        uint256 lastVerifiedRound = thisRound;
        //检查上一次验证的轮数是多少？
        while(getCarbonCoinAmountForSpecificRound[lastVerifiedRound-1] == 0){
            lastVerifiedRound--;
        }
        
        //记录每一轮直到交给第三方验证的轮数，这期间每个用户省下了多少carbon
        for(uint256 i = lastVerifiedRound+1; lastVerifiedRound<= thisRound;i++){
            //int thisRoundCarbonSavings = verifyAllUserCarbonSaving[i]; // 该轮总共节省的碳量

            //该round哪些用户节省了carbon
            address[] memory thisRoundCarbonSavingUser = EachRoundCarbonSavingUsers[i];
            for(uint j = 0; j < thisRoundCarbonSavingUser.length; j++){
                //该轮有哪些用户省下了carbon, 并且carbon的值为多少
                int carbonSavings = voters[thisRoundCarbonSavingUser[j]].verifyCarbonSavingEachRound[i];
                //记录每一轮直到交给第三方验证的轮数，这期间每个用户省下了多少carbon
                EachUserSaveCarbonForVerifiedSpecificRound[thisRoundCarbonSavingUser[j]] += carbonSavings;
                //验证该address是否重复添加了
                if(!verifyUniqueCarbonSavingUser[thisRoundCarbonSavingUser[j]]){
                    EachCarbonSavingUserForVerifiedSpecificRound.push(thisRoundCarbonSavingUser[j]);
                }
                verifyUniqueCarbonSavingUser[thisRoundCarbonSavingUser[j]] = true;
            }
        }

        //根据carbon coin分配给每个用户
        for(uint i = 0; i < EachCarbonSavingUserForVerifiedSpecificRound.length; i++){
            int carbonSavings = EachUserSaveCarbonForVerifiedSpecificRound[EachCarbonSavingUserForVerifiedSpecificRound[i]];
            uint256 carboncoin = uint256((carboncoinAmountThisRound * carbonSavings) / verifiedCarbonSavingValueForSepecificRound);
            voters[EachCarbonSavingUserForVerifiedSpecificRound[i]].AllCarbonCoin += carboncoin; //分配给用户
            voters[EachCarbonSavingUserForVerifiedSpecificRound[i]].carboncoin.push(cc_1); //用户存储该carboncoin
            voters[EachCarbonSavingUserForVerifiedSpecificRound[i]].TheNumberOfEachTypeCarbonCoin[cc_1] = carboncoin; //每种carboncoin存储的数量为多少
        }

        getVerifiedRound[thisRound] = true; //该round已经被验证过
    }

    function burnTheRetringCarbonCoin(uint256 _CarbonCreditID) external returns (bool) {
        for(uint i = 0; i < allUserAddress.length; i++){
            CarbonCoinV2[] storage ccv2 = voters[allUserAddress[i]].carboncoin;
            for(uint j = 0; j < ccv2.length; j++){
                if(ccv2[j].getCarbonCreditID() == _CarbonCreditID){
                    uint256 carboncoinAmount = voters[allUserAddress[i]].TheNumberOfEachTypeCarbonCoin[ccv2[j]];
                    voters[allUserAddress[i]].AllCarbonCoin -= carboncoinAmount;
                    delete ccv2[j]; //删除该carbon coin
                }
            }

        }
        return true;
    }

    //用户买carboncredit
    function purchaseTheCarbonCredit(uint256 value, address _address) external{
        require(voters[_address].AllCarbonCoin > value, "you don't have enough money!");
        voters[_address].AllCarbonCoin -= value;
        CarbonCoinV2[] storage ccv2 = voters[_address].carboncoin;
        uint i = 0;
        while(i < ccv2.length && value > 0){
            uint256 amount = voters[_address].TheNumberOfEachTypeCarbonCoin[ccv2[i]]; //减去最优先过期的carboncoin
            //该carboncoin还有剩
            if(amount > value){
                amount -= value;
            //该carboncoin没有剩
            }else{
                value -= amount;
                delete ccv2[i];
            }
            i++;   
        }
        
    }

    
    //getAllowancePercentage,当前MVP阶段不考虑
    //如果反悔了需要撤销怎么办?-前端需要考虑
    // function getDecreasedAllowancePercentage() public{
    //     Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?

    //     //还没有初始化
    //     require(voters[msg.sender].target_carbon_allowance != 0,"you have not initialize!");
    //     require(voters[msg.sender].isVoted == 1, "you cannot operate this function");

    //      //得到下周期望的km
    //      //需要修改一下
    //     // require(sender.expect_travel_mode.passenger_cars != 0, "please input your passenger_cars");
    //     // require(sender.expect_travel_mode.motocycle != 0, "please input your motocycle");
    //     // require(sender.expect_travel_mode.bus != 0, "please input your bus");
    //     // require(sender.expect_travel_mode.heavy_rail != 0, "please input your heavy_rail");
    //     // require(sender.expect_travel_mode.walking != 0, "please input your walking");
    //     // require(sender.expect_travel_mode.cycling != 0, "please input your cycling");

    //     int sum = sender.expect_travel_mode.passenger_cars+
    //                 sender.expect_travel_mode.bus+
    //                 sender.expect_travel_mode.heavy_rail+
    //                 sender.expect_travel_mode.walking+
    //                 sender.expect_travel_mode.cycling;

    //     require(sum != 0, "your expect travel mode is empty, please go back to check input");

    //     //用户自己投票的下周的碳排放量
    //    bytes16 voting_carbon_allowance = ABDKMathQuad.div(ABDKMathQuad.fromInt(sender.expect_travel_mode.passenger_cars*car_cost+
    //                                 sender.expect_travel_mode.bus*bus_cost+
    //                                 sender.expect_travel_mode.heavy_rail*heavy_rail_cost),ABDKMathQuad.fromInt(100));

    //                 //得到下周的decreasedAllowancePercentage_是否下降或者上升
    //     sender.decreasedAllowancePercentage_ = ABDKMathQuad.toInt(
    //         ABDKMathQuad.mul(
    //             ABDKMathQuad.div(
    //                 ABDKMathQuad.sub(
    //                     ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //                     voting_carbon_allowance),
    //                 ABDKMathQuad.fromInt(sender.target_carbon_allowance)
    //             ), ABDKMathQuad.fromInt(100)
    //     ));

    //     //allowance-settlement-voting 位置的 decreasedAllowancePercentage
    //     //decreasedAllowancePercentage.push(sender.decreasedAllowancePercentage_); //添加当前用户的allowancePercentage
    //     voters_.push(sender);
    //     sender.isVoted++; //表示该用户执行过该方法
    // }


    //下一周建议的carbonAllowance,MVP不考虑
    // function ExpectCarbonAllowance() public{

    //     //还没有初始化
    //     require(voters[msg.sender].target_carbon_allowance != 0,"you have not initialize!");
    //     //这周已经投过票了
    //     require(voters[msg.sender].isVoted == 2, "you cannot operate this function");
    //     //如果没有计算allowance-settlement-voting 位置的 decreasedAllowancePercentage是没有办法进入该function的
    //     require(voters[msg.sender].decreasedAllowancePercentage_ != 0, "you have not get DecreasedAllowancePercentage!");

    //     Voter storage sender = voters[msg.sender]; //这里为什么必须存储sender?

    //     //计算achievement位置的 decreasedAllowancePercentage
    //     //每个用户weight的计算方法也是根据reputationScore来计算的
    //     bytes16 decreasedAllowancePercentage_ = 0;
    //     bytes16 sumReputationScore = 0;

    //     for(uint i = 0; i < voters_.length; i++){
    //         sumReputationScore = ABDKMathQuad.add(sumReputationScore,
    //         ABDKMathQuad.fromInt(voters_[i].reputation_score));
    //     }

    //     for(uint i = 0; i < voters_.length; i++){
    //             //算每个老手投票成员的权重
    //         decreasedAllowancePercentage_ = ABDKMathQuad.add(decreasedAllowancePercentage_,
    //             ABDKMathQuad.mul(
    //                 ABDKMathQuad.fromInt(voters_[i].reputation_score),
    //                 ABDKMathQuad.fromInt(voters_[i].decreasedAllowancePercentage_)
    //             )
    //         );
    //     }
        
    //     decreasedAllowancePercentage_ = ABDKMathQuad.div(decreasedAllowancePercentage_,sumReputationScore);

        
    //     bytes16 next_week_carbon_allowance = 0;
    //     bytes16 decreased_allowance = 0;
    //     bytes16 residual_allowance= 0;

    //      //并非第一次投票，那么需要target_carbon_allowance, 还有已经存在的governanceToken来计算这一周的碳消耗
    //     next_week_carbon_allowance = ABDKMathQuad.mul(
    //         ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //             ABDKMathQuad.sub(ABDKMathQuad.fromInt(1),
    //                 ABDKMathQuad.div(
    //                     decreasedAllowancePercentage_,
    //                     ABDKMathQuad.fromInt(100)
    //             )
    //         )
    //     );

    //     decreased_allowance = ABDKMathQuad.sub(
    //         ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //         next_week_carbon_allowance
    //     );

    //     residual_allowance = ABDKMathQuad.sub(
    //         ABDKMathQuad.fromInt(sender.target_carbon_allowance),
    //         ABDKMathQuad.fromInt(sender.carbon_cost_per_week)
    //     );

    //     //得到新的governanceToken
    //     sender.reputation_score += ABDKMathQuad.toInt(ABDKMathQuad.add(residual_allowance, decreased_allowance)); 
        
    //     sender.isVoted++; //表示该用户执行过该方法，执行到这这周就不能随便改动了。
    //     sender.round++; //这周投票结束

    // }


    //到周日的23:59:59重新开始新的一轮，需要在前端进行设计
    //新的一轮开始
    function theNewRound() external{
        require(msg.sender == chairperson, "only chairperson can use this function");
        //新一轮start, 这个时候需要用自己上一周所得到的target_carbon_allowance来进行计算
        //初始化需要计算的的所有值(reputation_score, target_allowance)
        for(uint i = 0; i < allUserAddress.length; i++){
            Voter storage v = voters[allUserAddress[i]];
            v.isVoted = 0; //设置为0
            v.currentWeek_carbonSaving = 0; //删除该用户这周节省的碳排放量
            //v.decreasedAllowancePercentage_ = 0; //设置为0
            delete v.sensor_travel_mode;
            delete v.expect_travel_mode;
            UpateUsersTargetAllowance(v); //看是否需要更新carbonAllowance
        }
        delete carbonSavingUsers; //删除这轮节省了碳的用户
    }


    //每四周，每半年进行target_allowance的一次更新
    function UpateUsersTargetAllowance(Voter storage _voter) internal{
        int updateCarbonAllowance = 0;
        if(_voter.round == 4){
            //获得该用户这四周的carbonEmission
            bytes16 fourWeeksSumCarbonEmissons = 0;
            for(uint i = 0; i < _voter.carbon_cost_per_week.length;i++){
                fourWeeksSumCarbonEmissons = ABDKMathQuad.add(fourWeeksSumCarbonEmissons,
                ABDKMathQuad.fromInt(_voter.carbon_cost_per_week[i]));
            }
            //获取新的carbonAllowance
            updateCarbonAllowance = ABDKMathQuad.toInt(
                ABDKMathQuad.div(fourWeeksSumCarbonEmissons,
                ABDKMathQuad.fromUInt(_voter.carbon_cost_per_week.length)));
            //清空
            delete _voter.carbon_cost_per_week;
            _voter.target_carbon_allowance = updateCarbonAllowance; //更新用户的targetAllowance

        }
        if(_voter.round%24 == 0){
            //半年更新一次
            bytes16 halfYearSumCarbonEmissons = 0;
            for(uint i = 0; i < _voter.carbon_cost_per_week.length;i++){
                halfYearSumCarbonEmissons = ABDKMathQuad.add(halfYearSumCarbonEmissons,
                ABDKMathQuad.fromInt(_voter.carbon_cost_per_week[i]));
            }
            //获取新的carbonAllowance
            updateCarbonAllowance = ABDKMathQuad.toInt(
                ABDKMathQuad.div(halfYearSumCarbonEmissons,
                ABDKMathQuad.fromUInt(_voter.carbon_cost_per_week.length)));
            //清空
            delete _voter.carbon_cost_per_week;
            _voter.target_carbon_allowance = updateCarbonAllowance; //更新用户的targetAllowance
        }
    }
    
    
}


    //测试数据：
    //user1: r1: [123,4,1,23,5,23], [65,5,5,10,3,12]
    //user2: r1: [45,21,23,112,23,2], [23,12,12,50,2,1]
    //user3: r1: [100,0,2,59,2,1], [51,0,2,25,12,10]

    //user1: r2: [100,23,2,11,20,90], [50,5,2,3,6,34]
    //user2: r2: [40,30,32,60,22,12], [20,10,10,50,4,6]
    //user3: r2: [98,2,2,60,2,3], [60,0,2,10,4,24]

    //user1: r3: [99,21,4,20,25,23], [75,7,5,5,4,4]
    //user2: r3: [43,20,33,59,23,21], [20,10,15,40,4,11]
    //user3: r3: [80,0,20,40,4,4], [56,0,15,15,4,10]

    //user1: r4: [100,23,2,11,20,90], [78,5,2,3,6,6]
    //user2: r4: [40,30,32,60,22,12], [20,10,10,50,4,6]
    //user3: r4: [98,2,2,60,2,3], [80,0,2,10,4,4]


   //1009:需要积累的一定数量的碳排放量才能交给第三方去认证