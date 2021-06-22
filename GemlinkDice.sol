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
    require(b <= a,'');
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

contract GemlinkDice is Ownable{
    using SafeMath for uint256;

    string constant public name = "GemLink.io";
    bool public _STOP_GAME;
    address public _finishAllGamesAddress;
    address public _dividentsContractAddress;
    uint256 public _dividentsContractDecimals = 6;
    uint256 public _comission = 3;
    uint256 public _minimalBetValue = 1e7;
    uint256 public _maximalBetValue = 1e11;
    uint256 public _totalSunInGame;
    uint256 public _minReward = 1e7;
    uint256 public _maxReward = 1e10;
    uint256 public _CountOfGamesThatUserCanFinish = 3;

    struct Bet{
        bool launchExtraX;
        int8 predictedNumber;
        int8 lastLuckyNumber;
        uint32 awaitedBlockNumber;
        uint64 extraXWin;
        uint64 mul;
        uint64 trxValue;
    }

    event rollEnded(
        address indexed player,
        uint256 betTrxValue,
        uint256 winAmount,
        int256 predictedNumber,
        uint256 luckyNumber,
        bool extraX,
        uint256 tokenMined
    );

    event betIsPlaced(
        address indexed player,
        uint256 betTrxValue,
        uint256 winAmount,
        int256 predictedNumber,
        bool extraX
    );

    event highRiskRollEnded(
        address indexed player,
        uint256 betTrxValue,
        uint256 winAmount,
        int256 predictedNumber,
        uint256 luckyNumber,
        bool extraX,
        uint256 tokenMined
    );

    event prizeGetted(
        address indexed player,
        uint256 winAmount
    );

    mapping(address => Bet) private bets;
    address[] private playersAwaitedRoll;

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

    function Set_dividentsContractAddress(address contractAddress) external onlyOwner returns(bool){
        _dividentsContractAddress = contractAddress;
        return true;
    }
    function Set_finishAllGamesAddress(address contractAddress) external onlyOwner returns(bool){
        _finishAllGamesAddress = contractAddress;
        return true;
    }

    function STOP_GAME(bool stop) external onlyOwner returns(bool){
        _STOP_GAME = stop;
        return true;
    }

    function getFromBank(uint256 amount) external onlyOwner returns(bool){
        msg.sender.transfer(amount);
        return true;
    }

    function putToBank() external payable {}

    function getFinances() public view returns (uint256, uint256, uint256) {
        return (
            address(this).balance,
            _totalSunInGame,
            playersAwaitedRoll.length
        );
    }

    function placeBet(int8 predictedNumber, bool launchExtraX) public payable{
        require(!_STOP_GAME, "Game is paused.");
        require(bets[msg.sender].awaitedBlockNumber == 0, "Await roll ending!");
        require((predictedNumber > -95 && predictedNumber < 0) ||
                (predictedNumber < 99 && predictedNumber > 4), "Unexpected predicted number");

        uint32 size;
        address _addr = msg.sender;
        assembly{
            size := extcodesize(_addr)
        }
        if (size > 0) return;

        uint256 rewardAtBegin = getPossibleReward(msg.sender);

        require((launchExtraX && (rewardAtBegin > 0) && (msg.value == 0)) ||
                (launchExtraX && (rewardAtBegin == 0) && (msg.value >= _minimalBetValue)) ||
                (!launchExtraX && (msg.value >= _minimalBetValue) && (rewardAtBegin == 0)),
                "Value of transaction out of range");

        bets[msg.sender].trxValue = uint64(bets[msg.sender].trxValue + msg.value);
        bets[msg.sender].awaitedBlockNumber = uint32(block.number);
        bets[msg.sender].predictedNumber = predictedNumber;
        bets[msg.sender].launchExtraX = launchExtraX;
        bets[msg.sender].mul = uint64(multiply(bets[msg.sender].mul == 0? 1e6 :bets[msg.sender].mul, getMul(predictedNumber), 6));

        _totalSunInGame = _totalSunInGame.add(getPossibleReward(msg.sender).sub(rewardAtBegin));

        require(_totalSunInGame <= address(this).balance.div(2), "Not enought balance on contract");
        require(getPossibleReward(msg.sender).sub(bets[msg.sender].trxValue) <= _maxReward,"Max revard exeeded.");

        finishGamesByPlayer();

        playersAwaitedRoll.push(msg.sender);

        uint256 tokenWin = tokenReward(bets[msg.sender].trxValue);
        InterfaceDividents(_dividentsContractAddress).mintToken.value(tokenWin/2)(msg.sender,  tokenWin);

        emit betIsPlaced(
            msg.sender,
            bets[msg.sender].trxValue,
            getPossibleReward(msg.sender),
            predictedNumber,
            launchExtraX
        );
    }

    function finishAllGames() public returns(uint256 countOfFinishedGames){
        require(msg.sender == _finishAllGamesAddress, 'Only Joda can call this function.');
        countOfFinishedGames = finishGames(true);
    }

    function finishGamesByPlayer() private{
        finishGames(false);
    }


    function finishGames(bool allGames) private returns(uint256 countOfFinishedGames){
        uint256 gamesToFinish = playersAwaitedRoll.length;
        uint256 actualFinishedGames;

        if (gamesToFinish == 0) return;

        while(countOfFinishedGames < gamesToFinish) {
            address player = playersAwaitedRoll[countOfFinishedGames];

            Bet storage _Bet = bets[player];

            if (_Bet.awaitedBlockNumber >= block.number) {
                countOfFinishedGames = countOfFinishedGames.add(1);
                continue;
            }

            uint256 tempHash = uint256(blockhash(_Bet.awaitedBlockNumber));
            if (tempHash == 0){
                countOfFinishedGames = countOfFinishedGames.add(1);
                _Bet.awaitedBlockNumber = uint32(block.number);
                continue;
            }

            uint256 possibleReward = getPossibleReward(player);
            uint256 luckyNumber = uint256(keccak256(abi.encodePacked(tempHash, player))) % 100;//
            uint256 tokenWin = tokenReward(_Bet.trxValue);

            bool win = (_Bet.predictedNumber < 0) ? (luckyNumber < abs(_Bet.predictedNumber)) : (luckyNumber > abs(_Bet.predictedNumber));
            _Bet.lastLuckyNumber = int8(luckyNumber);

            if(win){
                emit rollEnded(
                    player,
                    _Bet.trxValue,
                    possibleReward,
                    _Bet.predictedNumber,
                    luckyNumber,
                    _Bet.launchExtraX,
                    tokenWin
                );

                if (uint64(multiply(_Bet.mul, getMul(_Bet.predictedNumber), 6)) > 1e7){
                  emit highRiskRollEnded(
                    player,
                    _Bet.trxValue,
                    possibleReward,
                    _Bet.predictedNumber,
                    luckyNumber,
                    _Bet.launchExtraX,
                    tokenWin
                  );
                }

                if(_Bet.launchExtraX){
                    killPlayerAwaitedRoll(countOfFinishedGames);

                    _Bet.awaitedBlockNumber = 0;
                    gamesToFinish = gamesToFinish.sub(1);
                    _Bet.extraXWin = uint64(possibleReward);
                } else {

                    getPrize(countOfFinishedGames);
                    gamesToFinish = gamesToFinish.sub(1);
                }
            } else {
                emit rollEnded(
                    player,
                    _Bet.trxValue,
                    0,
                    _Bet.predictedNumber,
                    luckyNumber,
                    _Bet.launchExtraX,
                    tokenWin
                );

                killPlayer(countOfFinishedGames);
                gamesToFinish = gamesToFinish.sub(1);
            }



            if (!allGames){
                if (actualFinishedGames > 1){
                    countOfFinishedGames = gamesToFinish;
                }else{
                    actualFinishedGames++;
                }
            }
        }
    }

    function getPrize(uint256 index) private{
        address player = playersAwaitedRoll[index];
        require(bets[player].trxValue > 0, "Amount is empty");
        uint256 possibleReward = getPossibleReward(player);
        killPlayer(index);
        player.transfer(possibleReward);
        emit prizeGetted(player, possibleReward);
    }

    function killPlayer(uint256 index) private{
        address player = playersAwaitedRoll[index];

        _totalSunInGame = _totalSunInGame.sub(getPossibleReward(player));
        // delete( bets[player]);

        delete( bets[player].launchExtraX);
        delete( bets[player].predictedNumber);
        delete( bets[player].mul);
        delete( bets[player].trxValue);
        delete( bets[player].awaitedBlockNumber);
        delete( bets[player].extraXWin);

        killPlayerAwaitedRoll(index);
    }

    function killPlayerAwaitedRoll(uint256 index) private{
        if (index < playersAwaitedRoll.length.sub(1)){
          playersAwaitedRoll[index] = playersAwaitedRoll[playersAwaitedRoll.length.sub(1)];
        }

        playersAwaitedRoll.length = playersAwaitedRoll.length.sub(1);
    }

    function getReward() external {
        uint256 reward = uint256(bets[msg.sender].extraXWin);
        require(reward > _minReward, "Win something!");
        require(bets[msg.sender].awaitedBlockNumber == 0 && bets[msg.sender].launchExtraX == true, "Rollig stones still rolling!!!");
        require(getPossibleReward(msg.sender) == reward, "Reward doesn`t match possible reward!");

        _totalSunInGame = _totalSunInGame.sub(reward);
        // delete( bets[msg.sender]);

        delete( bets[msg.sender].launchExtraX);
        delete( bets[msg.sender].predictedNumber);
        delete( bets[msg.sender].mul);
        delete( bets[msg.sender].trxValue);
        delete( bets[msg.sender].awaitedBlockNumber);
        delete( bets[msg.sender].extraXWin);

        msg.sender.transfer(reward);
        emit prizeGetted(msg.sender, reward);
    }

    function getRewardInfo() external view returns (
        uint64 initialBetValue,
        uint256 possibleReward,
        uint64 mul,
        uint64 awaitedBlockNumber,
        bool launchExtraX,
        int8 predictedNumber,
        int8 lastLuckyNumber,
        uint64 extraXWin
        ){
        return (
            bets[msg.sender].trxValue,
            getPossibleReward(msg.sender),
            bets[msg.sender].mul,
            bets[msg.sender].awaitedBlockNumber,
            bets[msg.sender].launchExtraX,
            bets[msg.sender].predictedNumber,
            bets[msg.sender].lastLuckyNumber,
            bets[msg.sender].extraXWin
        );
    }

    function getMul(int8 predictedNumber) internal view returns (uint256){
        uint64 temp_number = abs(predictedNumber);
        return uint64(((predictedNumber < 0 ? 1e8 / temp_number : 1e8 / (99 - temp_number)) * (100 - _comission)).div(100));
    }

    function tokenReward(uint256 betTrxValue) internal view returns (uint256){
        return betTrxValue.mul(_comission).div(100);
    }

    function multiply(uint256 a, uint256 b, uint256 decimals) internal pure returns(uint256){
        return a.mul(b).div(10 ** decimals);
    }

    function abs(int8 numba) internal pure returns(uint64){
        return uint64(numba < 0 ? -numba : numba);
    }

    function getPossibleReward(address player) private view returns(uint256){
        return multiply(bets[player].trxValue, bets[player].mul, 6);
    }
}