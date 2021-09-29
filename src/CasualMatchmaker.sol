pragma ton-solidity >= 0.50.0;

import "Matchmaker.sol";

contract CasualMatchmaker is Matchmaker, ICasualMatchmaker {

    constructor(TvmCell gameCode) public {
        if (msg.sender != _maker)
            _error(0, 0, DEPLOYER_ADDRESS_MISMATCH);
        _gameCode = gameCode;
        INSMatchmaker(_maker).onMatchmakerDeploy{value: REG}(_uid);
    }

    function cancelRequest(uint32 id) external override {
        _checkEntrant(id);
        if (_requestedCount == 0)
            _error(id, 0, NO_PENDING_REQUESTS);
        for ((uint32 gid, GameS game): _games) {
            if (game.status == GameStatus.Requested && game.entrants[0] == id) {
                _games[gid].status = GameStatus.Cancelled;
                _requestedCount--;
            }
        }
    }

    function onGameDeploy(uint32 id) external override {
        _notifyAll(id, GameStatus.Active);
    }

    function requestCasualGame(uint32 uid, uint8 quota) external override {
        _checkEntrant(uid);
        uint32 gameId = _createGameRecord(uid, quota);
        optional(uint32, bool) res = _pending.delMin();
        if (res.hasValue()) {
            (uint32 jid, ) = res.get();
            _doMatch(gameId, jid);
        } else
            _requestedCount++;
    }

    function joinCasualGame(uint32 uid) external override {
        _checkEntrant(uid);
        if (_requestedCount == 0) {
            _pending[uid] = true;
            return;
        }
        for ((uint32 gid, GameS game): _games) {
            if (game.status == GameStatus.Requested) {
                if (game.entrants.length > 0) {
                    _doMatch(gid, uid);
                    _requestedCount--;
                    break;
                }
                else
                    _error(gid, 0, REQUESTOR_NOT_FOUND);
            }
        }
    }

}
