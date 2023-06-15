import {CToken} from "./CToken.sol";
import {Ownable} from 'oz/access/Ownable.sol';

struct Position {
  address  account;
  CToken   supplyMarket;
  uint     supplyUnderlyingAmount;
  CToken[] borrowMarkets;
  uint[]   borrowBalances;
}

struct PositionBalances {
  uint redeemable;
  uint[] repayable;
}
library PositionHelper {
  function getKey(Position memory position) internal pure returns (bytes memory) {
    return abi.encode(position.supplyMarket, position.borrowMarkets);
  }

  function isMergable(Position memory _existing, Position memory _new) internal pure returns (bool) {
    bool _uninitialized = _existing.supplyMarket == CToken(address(0));
    if (_uninitialized) { return true; }
    bool borrowMarketsMatch = keccak256(abi.encode(_existing.borrowMarkets)) == keccak256(abi.encode(_new.borrowMarkets));
    bool supplyMarketMatch = _existing.supplyMarket == _new.supplyMarket;
    return borrowMarketsMatch && supplyMarketMatch;
  }

  function addToPosition(Position memory _existing, Position memory _new) internal pure returns (Position memory) {
    require(isMergable(_existing, _new), "Positions are not mergable");
    _existing.supplyUnderlyingAmount += _new.supplyUnderlyingAmount;
    for(uint i = 0; i < _new.borrowMarkets.length; i++) {
      _existing.borrowBalances[i] += _new.borrowBalances[i];
    }
    return _existing;
  }

  function subFromPosition(Position memory _existing, Position memory _new) internal pure returns (Position memory, bool isClosed) {
    require(isMergable(_existing, _new), "Positions are not mergable");
    require(_new.supplyUnderlyingAmount <= _existing.supplyUnderlyingAmount, "Insufficient supply balance");

    isClosed = _new.supplyUnderlyingAmount == _existing.supplyUnderlyingAmount;

    _existing.supplyUnderlyingAmount -= _new.supplyUnderlyingAmount;
    for(uint i = 0; i < _new.borrowMarkets.length; i++) {
      require(_new.borrowBalances[i] <= _existing.borrowBalances[i], "Insufficient borrow balance");
      isClosed = isClosed && _new.borrowBalances[i] == _existing.borrowBalances[i];
      _existing.borrowBalances[i] -= _new.borrowBalances[i];
    }
    return (_existing, isClosed);
  }

  function borrowBalances(Position memory position) internal view returns (uint[] memory repayable) {
    repayable = new uint[](position.borrowBalances.length);
    for(uint i = 0; i < position.borrowMarkets.length; i++) {
      CToken _market = position.borrowMarkets[i];
      repayable[i] = _market.borrowBalanceStoredPartial(position.account, position.borrowBalances[i]);
    }
    return repayable;
  }
}

contract PositionManager is Ownable {
  using PositionHelper for Position;

  mapping(address => bool) public handlers;

  mapping(address => uint) public numPositions;
  mapping(address => mapping(bytes => uint)) public accountPositionIds;
  mapping(address => mapping(uint => Position)) public accountPositions;

  function setHandler(address _handler, bool _isHandler) external onlyOwner {
    handlers[_handler] = _isHandler;
    emit SetHandler(_handler, _isHandler);
  }

  // emergency function
  function removeAccountPosition(address account, uint positionId, bytes memory key) external onlyOwner {
    removeAccountPositionInternal(account, positionId, key);
  }

  function removeAccountPositionInternal(address account, uint positionId, bytes memory key) internal {
    require(positionId == accountPositionIds[account][key]);
    delete accountPositionIds[account][key];

    if(accountPositionIds[account][key] == numPositions[account]) {
      delete accountPositions[account][numPositions[account]];
      numPositions[account]--;
      return;
    }

    for (uint i = positionId; i < numPositions[account]; i++){
      // get the position at the next id
      Position memory _pos = accountPositions[account][i+1];
      bytes memory _key = _pos.getKey();
      // update the decremented id
      accountPositionIds[account][_key] = i;
      // update the position at the decremented id
      accountPositions[account][i] = _pos;
    }
    delete accountPositions[account][numPositions[account]];
    numPositions[account]--;
    return;
  }


  function getPositionId(address _account, bytes memory _key) public view returns (uint) {
    return accountPositionIds[_account][_key];
  }

  function increaseAccountPosition(address account, Position memory position) external onlyHandler {
    increaseAccountPositionInternal(account, position);
  }

  function increaseAccountPositionInternal(address account, Position memory position) internal {
    bytes memory _key = position.getKey();
    uint positionId = getPositionId(account, _key);
    // start from 1 not 0
    if(positionId == 0) { positionId = numPositions[account]+1; }

    Position memory existing = accountPositions[account][positionId];
    accountPositions[account][positionId] = existing.addToPosition(position);
    accountPositionIds[account][_key] = positionId;
    numPositions[account]++;
  }

  function decreaseAccountPosition(address account, Position memory position) external onlyHandler {
    decreaseAccountPositionInternal(account, position);
  }

  function decreaseAccountPositionInternal(address account, Position memory position) internal {
    bytes memory _key = position.getKey();
    uint positionId = getPositionId(account, _key);
    Position memory existing = accountPositions[account][positionId];
    (Position memory updated, bool isClosed) = existing.subFromPosition(position);
    if (isClosed) {
      removeAccountPositionInternal(account, positionId, _key);
    } else {
      accountPositions[account][positionId] = updated;
    }
  }

  function getAccountPositions(address account) public view returns (Position[] memory positions){
    positions = new Position[](numPositions[account]);
    for(uint i = 1; i <= numPositions[account]; i++) {
      positions[i-1] = accountPositions[account][i];
    }
    return positions;
  }

  modifier onlyHandler() {
    require(handlers[msg.sender], "only handler");
    _;
  }

  event SetHandler(address _handler, bool _isHandler);
}
