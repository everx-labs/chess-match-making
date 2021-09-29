pragma ton-solidity >= 0.50.0;

import "Participant.sol";

contract Partner is Participant, IPartner {

    constructor(uint32 uid) public {
        _deployer = msg.sender;
        _uid = uid;
        IRepo(_deployer).onDeploy{value: FEE}(uid, 2);
    }

    struct ResultsHistory {
        uint8 points; // doubled
        uint32 gameId;
        uint16 adversary;
        uint32 ts;
    }
    mapping (uint8 => ResultsHistory[]) public _results;

    struct GameInfo {
        bool isWhite;
        uint16 adversary;
        uint32 startedAt;
    }
    mapping (uint32 => GameInfo) public _gameInfo;

    function _requestGame(uint8 flavor, uint16 ratingLo, uint16 ratingHi, uint8 quota) internal {
        /* Check if there's already a game of this flavor in progress */
        if (_active.exists(flavor)) {
            GameStatus status = _active[flavor];
            if (status >= GameStatus.Completed) {
                /* Previous game has been completed. Archive or discard the data */
                delete _cgames[flavor];
                delete _active[flavor];
            } else if (status >= GameStatus.Active)
                /* Game is in progress. Either finish or forfeit it before requesting another one */
                return;
            else if (status >= GameStatus.Requested)
                /* Already requested a game of this flavor */
                return;
        }

        address addr = _getMatchmaker(flavor); // Matchmaker address should have been known at this point
        if (addr != address(0)) {
            if (flavor < RATED)
                /* Friendly game - pay a fee and place a bet */
                ICasualMatchmaker(addr).requestCasualGame{value: FEE + BET}(_uid, quota);
            else {
                uint16 rating = _ratings[flavor];
                if (rating >= ratingLo && rating <= ratingHi)
                    /* Rated game - pay a fee and place a bond */
                    IRatedMatchmaker(addr).requestRatedGame{value: BET}(_uid, rating, ratingLo, ratingHi, quota);
                else
                    return; // Error: rating is not in the specified range
            }
            _active[flavor] = GameStatus.Requested;
        }
    }

    function _points(uint32 gameId, GameResult result) private view returns (uint8) {
        if (result == GameResult.Tie)
            return 1;
        bool isWhite = _gameInfo[gameId].isWhite;
        return (isWhite && result == GameResult.WhiteWon || !isWhite && result == GameResult.BlackWon) ? 2 : 0;
    }

    function onGameAnnounce(uint8 flavor, uint32 gameId, address addr, bool isWhite, uint16 rating) external override {
        _cgames[flavor] = CurrentGame(gameId, addr);
        _gameInfo[gameId] = GameInfo(isWhite, rating, now);
    }

    function onGameCompletion(uint8 flavor, uint32 gameId, GameResult result) external override {
        _results[flavor].push(ResultsHistory(_points(gameId, result), gameId, _gameInfo[gameId].adversary, now));
    }

    function requestGame(uint8 flavor, uint16 ratingLo, uint16 ratingHi, uint8 quota) external accept {
        _requestGame(flavor, ratingLo, ratingHi, quota);
    }

    function _joinGame(uint8 flavor) internal view {
        address addr = _getMatchmaker(flavor);
        if (addr != address(0)) {
            if (flavor < RATED)
                ICasualMatchmaker(addr).joinCasualGame{value: FEE + BET}(_uid);
            else
                IRatedMatchmaker(addr).acceptGame{value: FEE + BOND}(_uid, _ratings[flavor]);
        }
    }

    function updateGameAddress(uint8 flavor, uint32 gameId, address gameAddr) external override {
        if (!_active.exists(flavor))
            return; // No pending requests for this game flavor
        if (_cgames[flavor].gameId != gameId || _cgames[flavor].gameAddress != gameAddr)
            return;
    }

    function joinGame(uint8 flavor) external view accept {
        _joinGame(flavor);
    }

    function cancelRequest(uint8 flavor) external view accept {
        if (!_active.exists(flavor))
            return; // No pending requests for this game flavor
        if (_active[flavor] < GameStatus.Requested)
            return; // Game status precedes request
        if (_active[flavor] >= GameStatus.Accepted)
            return; // Game is already accepted; either finish or forfeit it
        if (_matchmakers.exists(flavor)) {
            address addr = _matchmakers[flavor];
            if (flavor < RATED)
                ICasualMatchmaker(addr).cancelRequest{value: FEE}(_uid);
            else
                IRatedMatchmaker(addr).cancelRequestRated{value: FEE}(_uid, _ratings[flavor]);
        }
    }
}
