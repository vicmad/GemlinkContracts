pragma solidity ^0.4.25;


library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {return 0;}
    uint256 c = a * b;
    require(c / a == b,'');
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b > 0,'');
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b <= a,'Underflow detected! Stay where you are! Calling 911...');
    uint256 c = a - b;
    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    require(c >= a,'');
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0,'');
    return a % b;
  }
}

contract Ownable {
  address private _owner;

  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );

  constructor() internal {
    _owner = msg.sender;
    emit OwnershipTransferred(address(0), _owner);
  }

  function owner() public view returns(address) {
    return _owner;
  }

  modifier onlyOwner() {
    require(isOwner(),'');
    _;
  }

  function isOwner() public view returns(bool) {
    return msg.sender == _owner;
  }

  function renounceOwnership() public onlyOwner {
    emit OwnershipTransferred(_owner, address(0));
    _owner = address(0);
  }

  function transferOwnership(address newOwner) public onlyOwner {
    _transferOwnership(newOwner);
  }

  function _transferOwnership(address newOwner) internal {
    require(newOwner != address(0),'');
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

interface InterfaceDividents {
  function totalTokenMinted() external view returns(uint256);
  function mintToken(address player, uint256 amount) external payable returns(bool);
}

contract GemlinkNaturalCrasp is Ownable{
    using SafeMath for uint256;
    using SafeMath for uint64;

    string constant public name = "NRG crasps";
    bool public _STOP_GAME;
    address public _rollEndRoundAddress;
    address public _dividentsContractAddress;
    uint256 public _dividentsContractDecimals = 6;
    uint256 public _comission = 5;
    uint256 public _minimalBetValue = 50e6;//50 TRX
    uint256 public _maximalBetValue = 10e9;//10k TRX
    uint256 public _totalSunInGame;
    uint256 public _minReward = _minimalBetValue + 1;
    uint256 public _maxReward = 100e9;//100k TRX
    uint256 public _CountOfGamesThatUserCanFinish = 2;

    bool public betsCanBeAccepted = false;

    event rollEnded(
        address indexed player,
        uint256 winAmount
    );

    event roundEnded(
        uint256 firstCube,
        uint256 seckondCube,
        uint256 thirdCube,
        uint256 countOfFinishedGames
    );

    //service functions
    function configureInitialParameters(
        uint256  comission,
        uint256  minimalBetValue,
        uint256  minReward,
        uint256  maxReward,
        uint256  dividentsContractDecimals,
        uint256  CountOfGamesThatUserCanFinish
    )external onlyOwner returns(bool){
        _comission = comission;
        _minimalBetValue = minimalBetValue;
        _minReward = minReward;
        _maxReward = maxReward;
        _dividentsContractDecimals = dividentsContractDecimals;
        _CountOfGamesThatUserCanFinish = CountOfGamesThatUserCanFinish;

        return true;
    }

    function Set_rollEndRoundAddress(address contractAddress) external onlyOwner returns(bool){
        _rollEndRoundAddress = contractAddress;
        return true;
    }

    function Set_dividentsContractAddress(address contractAddress) external onlyOwner returns(bool){
        _dividentsContractAddress = contractAddress;
        return true;
    }

    function STOP_GAME(bool stop) external onlyOwner returns(bool){
        _STOP_GAME = stop;
        return true;
    }

    function getFromBank(uint256 amount) external onlyOwner returns(uint256){
        msg.sender.transfer(amount);
        return amount;
    }

    function putToBank() external payable returns(uint256){
        return msg.value;
    }

    function getFinances() public view returns (uint256, uint256, uint256){
        return (
            address(this).balance,
            _totalSunInGame,
            playersAwaitedRoll.length
        );
    }
    // end service functions



    //initialization
    address[] private playersAwaitedRoll;
    mapping(uint256 => uint256) private Coef;
    mapping(uint256 => uint256) private Chips;//1-6
    mapping(address => mapping(uint256 => uint256))BetMap;

    constructor() public{
        initiateCoef();
        initiateChips();
    }

    function initiateCoef() private{
        Coef[1] = 1950000;//    small 3-10
        Coef[2] = 1950000;//    big 11-18
        Coef[3] = 150e6;//      summ 3
        Coef[4] = 50e6;//       summ 4
        Coef[5] = 18e6;//       summ 5
        Coef[6] = 14e6;//       summ 6
        Coef[7] = 12e6;//       summ 7
        Coef[8] = 8e6;//        summ 8
        Coef[9] = 6e6;//        summ 9
        Coef[10] = 6e6;//        summ 10
        Coef[11] = 6e6;//        summ 11
        Coef[12] = 6e6;//        summ 12
        Coef[13] = 8e6;//        summ 13
        Coef[14] = 12e6;//       summ 14
        Coef[15] = 14e6;//       summ 15
        Coef[16] = 18e6;//       summ 16
        Coef[17] = 50e6;//       summ 17
        Coef[18] = 150e6;//      summ 18
        Coef[19] = 1950000;//    cube 1
        Coef[20] = 1950000;//    cube 2
        Coef[21] = 1950000;//    cube 3
        Coef[22] = 1950000;//    cube 4
        Coef[23] = 1950000;//    cube 5
        Coef[24] = 1950000;//    cube 6
    }

    function initiateChips() private{
        Chips[1] = 10 * 1e6;
        Chips[2] = 50 * 1e6;
        Chips[3] = 100 * 1e6;
        Chips[4] = 500 * 1e6;
        Chips[5] = 1000 * 1e6;
        Chips[6] = 5000 * 1e6;
    }

    //end initialization

    //game functions
    function placeBet(uint256[] passedBets) public payable{
        require(betsCanBeAccepted, "Bets are no longer accepted!");

        uint32 size;
        uint256 callValue = msg.value;
        uint256 tokenWin = tokenReward(callValue);
        address player = msg.sender;

        require(BetMap[player][0] == 0, "Bet already placed");

        assembly{
            size := extcodesize(player)
        }
        if (size > 0) return;

        require(callValue >= Chips[1], "Not anoungh money even for one cheapest bet");

        for (uint i = 0; i < passedBets.length; i++) {
            uint256 betCode = passedBets[i];
            uint256 chip = uint256(betCode % 10);
            uint256 betType = betCode / 10;
            require(chip > 0 && chip < 7 && betType > 0 && betType < 25, "Broken bet received!");

            callValue = callValue.sub(installSingleBet(player, betType, chip));
        }

        require (callValue == 0,"Whong amount of received money!");
        playersAwaitedRoll.push(msg.sender);
        BetMap[player][0] = 1;


        require(_totalSunInGame <= address(this).balance.div(2), "Not enought balance on contract");
        //InterfaceDividents(_dividentsContractAddress).mintToken.value(tokenWin/2)(msg.sender,  tokenWin);
    }

    function installSingleBet(address player, uint256 betType, uint256 chip) private returns(uint256 callValue){
        callValue = Chips[chip];
        BetMap[player][betType] = BetMap[player][betType].add(callValue);
        _totalSunInGame = _totalSunInGame.add(multiply(callValue, Coef[betType], 6));
    }

    function rollEndRound(uint256 firstCube, uint256 seckondCube, uint256 thirdCube) public{
        require(!betsCanBeAccepted, "Bets still can be accepted. Stop bets accepting at first.");
        require(msg.sender == _rollEndRoundAddress, 'Only Joda can call this function.');
        require(
            firstCube > 0 && firstCube < 7 &&
            seckondCube > 0 && seckondCube < 7 &&
            thirdCube > 0 && thirdCube < 7,
            "One or more cube has unsufficent value!"
        );

        uint256 summ = firstCube + seckondCube + thirdCube;
        uint256 BigOrSmall = summ < 11 ? 1 : 2;

        for (uint i = 0; i < playersAwaitedRoll.length; i++) {
            address player = playersAwaitedRoll[i];
            uint256 totalWin;

            // bigOrSmall
            totalWin = totalWin.add(multiply(BetMap[player][BigOrSmall], Coef[BigOrSmall], 6));

            // summ
            totalWin = totalWin.add(multiply(BetMap[player][summ], Coef[summ], 6));

            // spec cube
            totalWin = totalWin.add(multiply(BetMap[player][19], Coef[19], 6));
            totalWin = totalWin.add(multiply(BetMap[player][20], Coef[20], 6));
            totalWin = totalWin.add(multiply(BetMap[player][21], Coef[21], 6));
            totalWin = totalWin.add(multiply(BetMap[player][22], Coef[22], 6));
            totalWin = totalWin.add(multiply(BetMap[player][23], Coef[23], 6));
            totalWin = totalWin.add(multiply(BetMap[player][24], Coef[24], 6));


            killPlayer(player);
            emit rollEnded(player, totalWin);
            if (totalWin > 0){
                player.transfer(totalWin);
            }
        }

        emit roundEnded(firstCube, seckondCube, thirdCube, playersAwaitedRoll.length);
        playersAwaitedRoll.length = 0;
        _totalSunInGame = 0;
    }

    function killPlayer(address player) private{
        for (uint i = 0; i < 25; i++)
            delete(BetMap[player][i]);
    }

    function startAcceptingBets() public onlyOwner returns(bool){
        require(!betsCanBeAccepted, "Bets already can be accepted");
        betsCanBeAccepted = true;
        return betsCanBeAccepted;
    }

    function stopAcceptingBets() public onlyOwner returns(bool){
        require(betsCanBeAccepted, "Bets already can not be accepted");
        betsCanBeAccepted = false;
        return betsCanBeAccepted;
    }

    function tokenReward(uint256 betTrxValue, uint256 comission) internal pure returns (uint256){
        return betTrxValue.mul(comission).div(100);
    }

    //end game functions

    //helpers

    function multiply(uint256 a, uint256 b, uint256 decimals) internal pure returns(uint256){
        return a.mul(b).div(10 ** decimals);
    }

    function tokenReward(uint256 betTrxValue) internal view returns (uint256){
        return betTrxValue.mul(_comission).div(100);
    }
}
