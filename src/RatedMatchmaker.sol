pragma ton-solidity >= 0.50.0;

import "Matchmaker.sol";

contract RatedMatchmaker is Matchmaker, IRatedMatchmaker {

    struct Matching {
        uint16 ratingLo;
        uint16 ratingHi;
        uint32 createdAt;
        uint32 validUntil;
    }
    mapping (uint32 => Matching) public _matching;

    constructor(TvmCell gameCode) public {
        if (msg.sender != _maker)
            _error(0, 0, DEPLOYER_ADDRESS_MISMATCH);
        _gameCode = gameCode;
        INSMatchmaker(_maker).onMatchmakerDeploy{value: REG}(_uid);
    }

    function _checkEntrantRated(uint32 id, uint16 rating) private {
        if (_entrants.exists(id)) {
            EntrantS entrant = _entrants[id];
            if (entrant.addr != msg.sender)
                _error(id, rating, ENTRANT_ADDRESS_MISMATCH);
            if (rating != entrant.rating)
                _error(rating, entrant.rating, ENTRANT_RATING_MISMATCH);
        } else
            _entrants[id] = EntrantS(msg.sender, rating);
    }

    function _removeIfExpired(uint32 rid) private {
        Matching rq = _matching[rid];
        if (rq.validUntil > now) {
            _notifyAll(rid, GameStatus.Expired);
            delete _matching[rid];
        }
    }

    function onGameDeploy(uint32 id) external override {
        tvm.accept();
        _notifyAll(id, GameStatus.Active);
    }

    function _matchRating(uint16 rating, uint16 lo, uint16 hi) private pure returns (bool) {
        return (rating >= lo && rating <= hi);
    }

    function requestRatedGame(uint32 id, uint16 rating, uint16 ratingLo, uint16 ratingHi, uint8 quota) external override {
        _checkEntrantRated(id, rating);
        if (rating < ratingLo)
            _error(id, rating, ENTRANT_RATING_TOO_LOW);
        if (rating > ratingHi)
            _error(id, rating, ENTRANT_RATING_TOO_HIGH);
        uint32 gameId = _createGameRecord(id, quota);
        _matching[gameId] = Matching(ratingLo, ratingHi, now, now + DEF_TIMEOUT);
        for ((uint32 uid, ): _pending) {
            if (_matchRating(_entrants[uid].rating, ratingLo, ratingHi)) {
                _doMatch(gameId, uid);
                return;
            }
        }
        _requestedCount++;
    }

    function acceptGame(uint32 id, uint16 rating) external override {
        _checkEntrantRated(id, rating);
        if (_requestedCount == 0) {
            _pending[id] = true;
            return;
        }
        for ((uint32 rid, Matching m): _matching)
            if (_matchRating(rating, m.ratingLo, m.ratingHi) && !_games[rid].entrants.empty()) {
                _doMatch(rid, id);
                delete _matching[rid];
                _requestedCount--;
                break;
            }
    }

    function cancelRequestRated(uint32 id, uint16 rating) external override {
        _checkEntrantRated(id, rating);
        if (_requestedCount == 0)
            _error(id, 0, NO_PENDING_REQUESTS);
        for ((uint32 gid, GameS game): _games)
            if (game.status == GameStatus.Requested && game.entrants[0] == id) {
                _games[gid].status = GameStatus.Cancelled;
                _requestedCount--;
            }
    }

    function _name(uint8 index) private pure returns (string) {
        return index < 2 ? format("Player {}: ", index + 1) : format("Arbite {}: ", index - 1);
    }

    function _index(uint16 index) private pure returns (string) {
        return format(" move {}, ", index / 2 + 1) + (index % 2 == 0 ? "white" : "black");
    }

    function _codeRated(uint8 code) private pure returns (string) {
        if (code == ENTRANT_ADDRESS_MISMATCH)
            return "ENTRANT_ADDRESS_MISMATCH";
        if (code == ENTRANT_ID_MISMATCH)
            return "ENTRANT_ID_MISMATCH";
        if (code == ENTRANT_RATING_MISMATCH)
            return "ENTRANT_RATING_MISMATCH";
        if (code == ENTRANT_RATING_TOO_LOW)
            return "ENTRANT_RATING_TOO_LOW";
        if (code == ENTRANT_RATING_TOO_HIGH)
            return "ENTRANT_RATING_TOO_HIGH";
    }

    function _ts(uint32 ts) private pure returns (string) {
        return format(" at {} ", ts);
    }

    function viewGames() external view returns (string[] games) {
        for (uint32 i = 0; i < _nGames; i++) {
            uint32[] entrants = _games[i].entrants;
            string s = format("Game {}:\n", i);
            for (uint j = 0; j < entrants.length; j++) {
                EntrantS e = _entrants[entrants[j]];
                s.append(_name(uint8(j)) + format(" rating: {} address: {}\n", e.rating, e.addr));
            }
            games.push(s);
        }
    }

}
