//SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/Context.sol";
// import "../IncentivePolicyMVPV4.sol";

//carbon coin 可能也会有使用期限，并且和carbon credit进行挂钩
contract SoGreenTest is ERC20,ERC20Burnable{
    //decimal为18
    
    //不会修改
    address public immutable i_owner; //谁deploy这个contract,谁就是owner
    uint256 public immutable startTime; //该合约创建的时间
    uint256 public lockTime; //锁住的时间

    //不同的part
    //address DEVELOPMENT = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
    address DEVELOPMENT = 0x1434fdD85AFe8d6C3F8c5B975fd028E83d4BCc3b; //metamask account1
    address MARKET_PARTNERSHIP = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
    address RESEARCH = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
    address TEAM = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
    address COMMUNITY = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
    address INVESTMENT = 0x17F6AD8Ef982297579C203069C1DbfFE4348c372;
    address RESERVE = 0x5c6B0f7Bf3E7ce046039Bd8FABdfD3f9F5021678;
    address LIQUIDITY = 0x03C6FcED478cBbC9a4FAB34eF9f40767739D1Ff7;


    //name为SoCarbonTest, Symbol为SCRBT
    constructor(uint256 _lockTime) ERC20 ("SoCarbonTest","SCRBT"){
        i_owner = msg.sender; //谁 deploy the contract
        startTime = block.timestamp; //初始时间 
        lockTime = _lockTime * 1 minutes; //设置锁住时间
        uint decimal18 = 1000000000000000000;   
        //直接分给不同part的负责人
        _mint(DEVELOPMENT, 240000*decimal18);
        _mint(MARKET_PARTNERSHIP,400000*decimal18);
        _mint(RESEARCH,100000*decimal18);
        _mint(TEAM,400000*decimal18); //需要不定期的释放该Token
        _mint(COMMUNITY, 180000*decimal18);
        _mint(INVESTMENT,200000*decimal18);
        _mint(RESERVE,180000*decimal18); //需要一直锁住该Token
        _mint(LIQUIDITY,300000*decimal18); 

    }

    function resetLockTime(uint256 _lockTime) external{
        lockTime = _lockTime * 1 minutes; //重新设置锁住时间
    }

    event transferToken(
        address indexed sender,
        uint256 senderTime,
        uint256 amount
    );



    //传输Token
    function transfer(address from, address to, uint256 value) external {
        require(from != RESERVE, "this token is locked, cannot be transfer"); //一直被锁住

        //不定期释放
        if(from == TEAM){
            //未满足释放时间
            require(block.timestamp >= startTime + lockTime, "TokenLock: current time is before release time");
        }
        _transfer(from, to, value);

        emit transferToken(msg.sender, block.timestamp, value);
    }

}