pragma ton-solidity >= 0.50.0;

import "GameData.sol";

interface IPartner {
    function onGameAnnounce(uint8 flavor, uint32 gameId, address gameAddr, bool isWhite, uint16 rating) external;
    function onGameCompletion(uint8 flavor, uint32 gameId, GameResult result) external;
}

interface IEntrant {
    function updateGameStatus(uint8 flavor, uint32 gameId, GameStatus status) external;
    function updateGameAddress(uint8 flavor, uint32 gameId, address gameAddr) external;
}
