pragma solidity ^0.5.0;

import "./ownable.sol";

contract LycanFactory is Ownable {

  event NewLycan(uint LycanId, string name, uint core);

  uint coreDigits = 12;
  uint coreTrim = 10 ** coreDigits;
  uint cooldownTime = 8 hours;
  uint levelCooldownTime = 1 days;

  struct Lycan {
    string name;
    uint core;
    uint level;
    uint readyTime;
    uint32 winCount;
    uint32 lossCount;
    uint attack;          //4
    uint defense;         //4
    uint lycanType;       //1
    uint lazyFactor;      //3
    uint power;             //(attack*def/(lazyfactor+1))pow type
    uint levelTime;
  }

  Lycan[] public Lycans;

  mapping (uint => address) public LycanToOwner;
  mapping (address => uint) ownerLycanCount;

  function _createLycan(string memory _name, uint _core) internal {
    uint attack = _core % 10000;
    uint def = (_core % 10**8)/(10**4);
    uint ltype = (_core % 10**9)/(10**8);
    uint lazy = _core/(10**9);
    uint power = (attack*def/lazy+1)**ltype;
    uint id = Lycans.push(Lycan(_name, _core, 1, uint(now), 0, 0, attack, def, ltype, lazy, power, uint32(now+levelCooldownTime))) - 1;
    LycanToOwner[id] = msg.sender;
    ownerLycanCount[msg.sender]++;
    emit NewLycan(id, _name, _core);
  }

  function _generateRandomCore(string memory _x) private view returns (uint) {
    uint Rand = uint(keccak256(abi.encodePacked(_x)));
    return Rand % coreTrim;
  }

  function createRandomLycan(string memory _name) public {
    require(ownerLycanCount[msg.sender] == 0,"already have one. Go to War");
    uint core = _generateRandomCore(_name);
    core = core - core % 100;
    _createLycan(_name, core);
  }
  
  function numberOfLycan() public view returns(uint){
      return ownerLycanCount[msg.sender];
  }
}

contract LycanFeeding is LycanFactory {

  modifier ownerOf(uint _LycanId) {
    require(msg.sender == LycanToOwner[_LycanId],"Not Owner");
    _;
  }

  function _triggerCooldown(Lycan storage _Lycan) internal {
    _Lycan.readyTime = uint(now + cooldownTime);
  }

  function _isReady(Lycan storage _Lycan) internal view returns (bool) {
      return (_Lycan.readyTime <= now);
  }

  function feedAndMultiply(uint _LycanId, uint _targetCore) internal ownerOf(_LycanId) {
    Lycan storage myLycan = Lycans[_LycanId];
    require(_isReady(myLycan),"Lycan Tired");
    uint newCore = (myLycan.core + _targetCore) / 2;
    _createLycan("NoName", newCore);
    _triggerCooldown(myLycan);
  }
}


contract LycanHelper is LycanFeeding {

  uint levelUpFee = 0.1 ether;

  function cashOut() external onlyOwner {
    address payable _owner = owner();
    _owner.transfer(address(this).balance);
  }

  function setLevelUpFee(uint _fee) external onlyOwner {
    levelUpFee = _fee;
  }

  function levelUp(uint _LycanId) external payable {
    require(msg.value == levelUpFee,"pay correctly you dumbo");
    require(now > Lycans[_LycanId].levelTime, "Patience is the ultimate virtue");
    Lycans[_LycanId].level++;
    Lycans[_LycanId].levelTime += levelCooldownTime;
  }

  function getLycansByOwner(address _owner) external view returns(uint[] memory) {
    uint[] memory result = new uint[](ownerLycanCount[_owner]);
    uint counter = 0;
    for (uint i = 0; i < Lycans.length; i++) {
      if (LycanToOwner[i] == _owner) {
        result[counter] = i;
        counter++;
      }
    }
    return result;
  }
}

contract LycanAttack is LycanHelper {
  uint randNonce = 0;

  function randMod(uint _modulus) internal returns(uint) {
    randNonce++;
    return uint(keccak256(abi.encodePacked(now, msg.sender, randNonce))) % _modulus;
  }

  function attack(uint _LycanId, uint _targetId) external ownerOf(_LycanId) {
    require(_isReady(Lycans[_LycanId]),"Lycan Tired");
    Lycan storage myLycan = Lycans[_LycanId];
    Lycan storage enemyLycan = Lycans[_targetId];
    uint rand = randMod(100);
    uint attackVictoryProbability = (myLycan.power * enemyLycan.power) % 100;
    if (rand <= attackVictoryProbability) {
      myLycan.winCount++;
      myLycan.level++;
      enemyLycan.lossCount++;
      feedAndMultiply(_LycanId, enemyLycan.core);
    } else {
      myLycan.lossCount++;
      enemyLycan.winCount++;
      _triggerCooldown(myLycan);
    }
  }
}