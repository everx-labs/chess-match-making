pragma ton-solidity >= 0.50.0;

import "Base.sol";
import "SystemServices.sol";
import "Organizers.sol";
import "Clients.sol";
import "Game.sol";

abstract contract Matchmaker is Base, IMatchmaker {

    struct EntrantS {
        address addr;
        uint16 rating;
    }
    mapping (uint32 => EntrantS) public _entrants;  // Local cache of players registry
    mapping (uint32 => bool) public _availableObservers;
    mapping (uint32 => bool) public _pending;
    uint16 public _needWatching;
    uint16 public _requestedCount;

    struct GameS {
        GameStatus status;
        uint32[] entrants;
        address addr;
        uint8 audience;
    }
    mapping (uint32 => GameS) public _games;
    uint32 _nGames;
    TvmCell _gameCode;

    uint16 _rating;

    uint64 constant DEPLOY_VALUE = 2 ton;
    uint32 constant DEF_TIMEOUT = 1 hours;

    struct ErrorS {
        uint32 id;
        uint32 value;
        uint8 code;
    }
    ErrorS[] public _errorLog;

    uint32 static _uid;
    uint8 static _flavor;
    address static _maker;

    function _findObserver() internal returns (uint32 id) {
        optional(uint32, bool) res = _availableObservers.delMin();
        if (res.hasValue())
            (id, ) = res.get();
        else
            _needWatching++;
    }

    function registerObserver(uint32 uid, uint16 rating) external override {
        _checkEntrant(uid);
        if (_availableObservers.exists(uid))
            _error(uid, 0, OBSERVER_ALREADY_REGISTERED);
        else {
            _availableObservers[uid] = true;
            _entrants[uid].rating = rating;
        }
    }

    function resignObserver(uint32 uid) external override {
        if (_availableObservers.exists(uid)) {
            if (msg.sender == _entrants[uid].addr)
                _availableObservers[uid] = false;
            else
                _error(uid, 0, OBSERVER_ID_MISMATCH);
        }
        else
            _error(uid, 0, OBSERVER_IS_NOT_REGISTERED);
    }

    function proposeCompletion(uint32 gid, GameResult result) external override {
        if (!_games.exists(gid)) {
            _error(gid, 0, UNKNOWN_GAME_ID);
            return;
        }
        GameS game = _games[gid];
        if (msg.sender != game.addr) {
            _error(gid, 0, GAME_ADDRESS_MISMATCH);
            return;
        }
        tvm.accept();
        this.wrapUp(gid, result);
        for (uint i = 2; i < game.entrants.length; i++)
            _availableObservers[game.entrants[i]] = true;
    }

    function wrapUp(uint32 gid, GameResult result) external {
        if (msg.sender != address(this))
            return;
        tvm.accept();
        _notifyAll(gid, GameStatus.Completed);
        for (uint32 eid: _games[gid].entrants)
            IPartner(_entrants[eid].addr).onGameCompletion{value: LGHT}(_flavor, gid, result);
    }

    function _doMatch(uint32 gameId, uint32 player2) internal {
        uint32 player1 = _games[gameId].entrants[0];
        _games[gameId].entrants.push(player2);
        TvmCell state = _buildGameState(gameId, player1, player2);
        _games[gameId].addr = address.makeAddrStd(0, tvm.hash(state));
        _notifyAll(gameId, GameStatus.Proposed);

        /*if (_needWatching > 0) {
            _needWatching++;
            return;
        }*/

        while (_games[gameId].entrants.length < _games[gameId].audience) {
            uint32 oid = _findObserver();
            if (oid > 0)
                _games[gameId].entrants.push(oid);
            else
                return;
        }
        _deployGame(gameId);
    }

    function _deployGame(uint32 gameId) internal {
        GameS game = _games[gameId];
        if (game.entrants.length < 2) {
            _error(gameId, 0, NO_PLAYERS_FOUND);
            return;
        }
        if (game.entrants.length < game.audience) {
            _error(gameId, 0, NOT_ENOUGH_PARTICIPANTS);
            return;
        }
        if (game.entrants.length > game.audience) {
            _error(gameId, 0, TOO_MANY_PARTICIPANTS);
            return;
        }

        TvmCell state = _buildGameState(gameId, game.entrants[0], game.entrants[1]);
        address[] writers;
        for (uint32 entrant: _games[gameId].entrants)
            writers.push(_entrants[entrant].addr);

        new Game{stateInit: state, value: DEP}(writers);
        _notifyAll(gameId, GameStatus.Observed);
    }

    function _createGameRecord(uint32 uid, uint8 quota) internal returns (uint32 gameId) {
        uint32[] players;
        players.push(uid);
        gameId = _nGames++;
        _games[gameId] = GameS(GameStatus.Requested, players, address(0), 2 + quota);
        _notifyAll(gameId, GameStatus.Requested);
    }

    function _notifyAll(uint32 gid, GameStatus status) internal {
        _games[gid].status = status;
        for (uint32 eid: _games[gid].entrants)
            IEntrant(_entrants[eid].addr).updateGameStatus{value: LGHT}(_flavor, gid, status);
        if (status == GameStatus.Active)
            _startGame(gid);
    }

    function _startGame(uint32 gid) internal view {
        uint32[] entrants = _games[gid].entrants;
        IPartner(_entrants[entrants[0]].addr).onGameAnnounce{value: LGHT}(_flavor, gid, _games[gid].addr, true, _entrants[entrants[1]].rating);
        IPartner(_entrants[entrants[1]].addr).onGameAnnounce{value: LGHT}(_flavor, gid, _games[gid].addr, false, _entrants[entrants[0]].rating);
        for (uint i = 2; i < entrants.length; i++)
            IEntrant(_entrants[entrants[i]].addr).updateGameAddress{value: LGHT}(_flavor, gid, _games[gid].addr);
    }

    function _error(uint32 id, uint32 value, uint8 code) internal {
        _errorLog.push(ErrorS(id, value, code));
    }

    function _buildGameState(uint32 gameId, uint32 player1, uint32 player2) internal view returns (TvmCell) {
        uint32[] players;
        players.push(player1);
        players.push(player2);
        return tvm.buildStateInit({contr: Game, varInit: {_id: gameId, _entrants: players, _maker: address(this)}, code: _gameCode});
    }

    function _checkEntrant(uint32 id) internal {
        if (_entrants.exists(id)) {
            if (_entrants[id].addr != msg.sender)
                _error(id, 0, ENTRANT_ADDRESS_MISMATCH);
        } else
            _entrants[id].addr = msg.sender;
    }

    function _code(uint8 code) private pure returns (string) {
        if (code == ENTRANT_ADDRESS_MISMATCH)
            return "ENTRANT_ADDRESS_MISMATCH";
        if (code == ENTRANT_ID_MISMATCH)
            return "ENTRANT_ID_MISMATCH";
    }

    function errorLog() external view returns (string[] errors) {
        for (ErrorS e: _errorLog)
            errors.push(format("ID: {} value: {} ", e.id, e.value) + _code(e.code));
    }

    function setGameCode(TvmCell c) external {
        tvm.accept();
        _gameCode = c;
    }
}
