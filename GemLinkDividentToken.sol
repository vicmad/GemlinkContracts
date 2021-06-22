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
    require(isOwner(),"Only owner can call this function");
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
    require(newOwner != address(0), " 0 address detected!");
    emit OwnershipTransferred(_owner, newOwner);
    _owner = newOwner;
  }
}

interface ITRC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender)external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value)external returns (bool);
    function transferFrom(address from, address to, uint256 value)external returns (bool);

    event Transfer(address indexed from,address indexed to,uint256 value);
    event Approval(address indexed owner,address indexed spender,uint256 value);
}


//DONE: add all functions from TRC20 contract
//DONE: use only SaveMath functions
contract GemLinkDividentToken is Ownable, ITRC20{
  using SafeMath for uint256;

  mapping (uint256=> address) private _frozenTokenHolders;

  mapping (address => uint256) private _balances;
  mapping (address => uint256) private _frozenTokens;
  mapping (address => uint256) private _balancesSUN;
  mapping (address => bool) private _initHolder;
  mapping (address => mapping (address => uint256)) private _allowed;

  address[] private _whiteListContracts;
  string public  name;
  string public  symbol;
  uint256 public  decimals;
  uint256 public _totalSupply;

  uint256 public _leftSupply;
  uint256 public _frozenTokenHoldersCount;
  uint256 public _frozenTokensSum;
  bool private _transferAllowed = true;
  uint256 public minSumFrozenTokenToDividents = 1e6;
  uint256 public countedCalculationDividents;

  // event Transfer(address indexed from,address indexed to,uint256 value);
  // event Approval(address indexed owner,address indexed spender,uint256 value);

  modifier onlywhiteListContracts{
    require(whiteListed(msg.sender) == true, "Only owner can call this function.");
    _;
  }

  constructor ()public{
    _whiteListContracts.push(msg.sender);
    name = "GemLinkDividentToken";
    symbol = "GML";
    decimals = 6;
    _totalSupply = 250000000*10**decimals;
    _leftSupply = _totalSupply;
    _balances[this] = _totalSupply;
  }

  function totalSupply() external view returns (uint256){
    return _totalSupply;
  }
  
  function leftSupply() external view returns (uint256){
    return _leftSupply;
  }
  
  function frozenTokenHoldersCount() external view returns (uint256){
    return _frozenTokenHoldersCount;
  }
  
  function frozenTokensSum() external view returns (uint256){
    return _frozenTokensSum;
  }

  function balanceOf(address who) external view returns (uint256) {
    return _balances[who];
  }
  
  function frozenTokens(address who) external view returns (uint256) {
    return _frozenTokens[who];
  }
  
  function balancesSUN(address who) external view returns (uint256) {
    return _balancesSUN[who];
  }

  function allowance(address owner, address spender)external view returns (uint256){
        return _allowed[owner][spender];
  }

  function approve(address spender, uint256 value) external returns (bool) {
      require(spender != address(0));

      _allowed[msg.sender][spender] = value;
      emit Approval(msg.sender, spender, value);
      return true;
  }

  function balanceTRXOf(address owner) public view returns (uint256) {
    return _balancesSUN[owner];
  }

  function transfer(address to, uint256 value) public returns (bool) {
    require(_transferAllowed, "Transfer functions is turned off");
    require(value <= _balances[msg.sender],"Not anought balance!");
    require(to != address(0), " 0 address detected!");

    _balances[msg.sender] = _balances[msg.sender].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(msg.sender, to, value);
    return true;
  }



  function transferFrom(address from,address to,uint256 value) public  onlywhiteListContracts returns (bool){
    require(_transferAllowed, "Transfer functions is turned off");
    require(value <= _balances[from],"Not anought balance!");
    require(to != address(0), " 0 address detected!");

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);

    emit Transfer(from, to, value);
    return true;
  }

    function mintToken(address to, uint256 value) external payable onlywhiteListContracts returns (bool) {
    if (value < _leftSupply){
         _leftSupply = _leftSupply.sub(value);
        //_balances[to] = _balances[to].add(value);
        transferFrom(this, to, value);
        return true;
    }
     return false;//token already Mint

  }
    
  //Dividends administration
  function whiteListed(address contractAddress) public view returns(bool){
        if (_whiteListContracts.length == 0 ) return false;
        for (  uint256 j; j < _whiteListContracts.length; j++){
          if (_whiteListContracts[j] == contractAddress) return true;
        }
        return false;
  }

  function addToWhiteList(address contractAddress) public onlyOwner{
    _whiteListContracts.push(contractAddress);
  }

  function clearWhiteList() public onlyOwner{
    _whiteListContracts.length = 0;
  }

  function chandeTransferAllowance(bool isOn) public onlyOwner{
    _transferAllowed = isOn;
  }


  //Dividends logic
  function freezeToken(uint256 amount) external returns(bool){
    require(amount > 0, "You cant freeze 0 tokens");
    require(_balances[msg.sender] >= amount, "Not enought available tokens.");

    if (_initHolder[msg.sender] == false){
        _initHolder[msg.sender] = true;
      _frozenTokenHolders[_frozenTokenHoldersCount] = msg.sender;
      _frozenTokenHoldersCount++;
    }

    _frozenTokens[msg.sender] = _frozenTokens[msg.sender].add(amount);
    _balances[msg.sender] = _balances[msg.sender].sub(amount);
    _frozenTokensSum = _frozenTokensSum.add(amount);

    return true;
  }

  function unfreezeToken(uint256 amount) external returns(bool){
    require(amount > 0, "You cant withdraw 0 tokens");
    require(_frozenTokens[msg.sender] >= amount, "Not enought available tokens.");

    _balances[msg.sender] = _balances[msg.sender].add(amount);
    _frozenTokens[msg.sender] = _frozenTokens[msg.sender].sub(amount);
    _frozenTokensSum = _frozenTokensSum.sub(amount);

    return true;
  }

  function calculationDividentsToHodlers() public onlyOwner returns(uint256 totalCalculationDividents){
    uint256 tmp_expectedDividentsToHodlers = expectedDividentsToHodlers();
    require (tmp_expectedDividentsToHodlers <= (address(this).balance - countedCalculationDividents), "Cant payout dividents");
    uint256 tempCount;
    for(uint i = 0 ; i<_frozenTokenHoldersCount; i++) {
        address holder = _frozenTokenHolders[i];
        uint256 tokenamount = _frozenTokens[holder];
        if(tokenamount < minSumFrozenTokenToDividents) continue;
          tempCount = 0;
        if (tokenamount < 1e11) {
          tempCount = tokenamount.mul(50).div(1e4);// 0.5%
        }else if (tokenamount < 1e12){
          tempCount = tokenamount.mul(75).div(1e4);// 0.75%
        }else{
          tempCount = tokenamount.mul(100).div(1e4);// 1%
        }
        _balancesSUN[holder] = _balancesSUN[holder].add(tempCount);
        totalCalculationDividents += tempCount;
    }
    countedCalculationDividents += totalCalculationDividents;
  }

function expectedDividentsToHodlers() public onlyOwner returns(uint256 totalCalculationDividents){
    uint256 tempCount;
    for(uint i = 0 ; i<_frozenTokenHoldersCount; i++) {
        address holder = _frozenTokenHolders[i];
        uint256 tokenamount = _frozenTokens[holder];
        if(tokenamount < minSumFrozenTokenToDividents) continue;
        tempCount = 0;
        if (tokenamount < 1e11) {
         tempCount = tokenamount.mul(50).div(1e4);// 0.5%
        }else if (tokenamount < 1e12){
          tempCount = tokenamount.mul(75).div(1e4);// 0.75%
        }else{
          tempCount = tokenamount.mul(100).div(1e4);// 1%
        }
        //_balancesSUN[holder] = _balancesSUN[holder].add(tempCount);
        totalCalculationDividents += tempCount;
    }
  }

  function withdrawDividents()external returns(bool){
    uint256 balance = _balancesSUN[msg.sender];
    require(balance > 0, "Balance is empty");

    _balancesSUN[msg.sender] = 0;
    msg.sender.transfer(balance);
    countedCalculationDividents -= balance;
    return true;
  }

  function totalTokenMinted() external view returns(uint256){
      return _totalSupply - _leftSupply;
  }
}//TODO: rating payments and another unusual shit
