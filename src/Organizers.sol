pragma ton-solidity >= 0.50.0;

import "GameData.sol";

interface IMatchmaker {
    function onGameDeploy(uint32 id) external;
    function registerObserver(uint32 id, uint16 rating) external;
    function resignObserver(uint32 id) external;
    function proposeCompletion(uint32 gid, GameResult result) external;
}

interface IRatedMatchmaker {
    function requestRatedGame(uint32 id, uint16 rating, uint16 ratingLo, uint16 ratingHi, uint8 quota) external;
    function acceptGame(uint32 id, uint16 rating) external;
    function cancelRequestRated(uint32 id, uint16 rating) external;
}

interface ICasualMatchmaker {
    function requestCasualGame(uint32 id, uint8 quota) external;
    function joinCasualGame(uint32 id) external;
    function cancelRequest(uint32 id) external;
}

interface IGame {
    function recordMoves(Move[] moves) external;
}
