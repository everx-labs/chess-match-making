pragma ton-solidity >= 0.50.0;

import "Base.sol";
import "Organizers.sol";
import "Clients.sol";
import "SystemServices.sol";
import "IRepo.sol";

abstract contract Participant is Base, INSMatchmakerClient, IEntrant {

    address public _nsMaker;
    mapping (uint8 => uint16) public _ratings;
    mapping (uint8 => address) public _matchmakers;
    mapping (uint8 => GameStatus) public _active;

    struct CurrentGame {
        uint32 gameId;
        address gameAddress;
    }
    mapping (uint8 => CurrentGame) public _cgames;

    address _deployer;
    uint32 public _uid;

    function setNSMatchmakerAddress(address addr) external accept {
        _nsMaker = addr;
//        if (_uid == 0)
//            _uid = uint32(rnd.getSeed() & 0xFFFF);
    }

    function _flavor(uint8 variant, uint8 timeControl, bool incremental, bool rated) internal pure returns (uint8) {
        return variant + (timeControl << 4) + (incremental ? 1 << 6 : 0) + (rated ? 1 << 7 : 0);
    }

    function _getMatchmaker(uint8 flavor) internal view returns (address) {
        if (_matchmakers.exists(flavor))
            return _matchmakers[flavor];
        else {
            // No matchmaker known for this game flavor - query for one
            INSMatchmaker(_nsMaker).queryMatchmakerAddress{value: DEF}(flavor);
            return address(0);
        }
    }

    function queryMatchmaker(uint8 flavor) external view accept {
        INSMatchmaker(_nsMaker).queryMatchmakerAddress{value: DEF}(flavor);
    }

    function updateMatchmakerAddress(uint8 flavor, address addr) external override {
        if (msg.sender == _nsMaker) {
            tvm.accept();
            _matchmakers[flavor] = addr;
            if (!_ratings.exists(flavor) && flavor > RATED)
                _ratings[flavor] = DEFAULT_RATING;
        }
    }

    function updateGameStatus(uint8 flavor,uint32 /*gameId*/, GameStatus status) external override {
        _active[flavor] = status;
    }

    function requestMatchmaker(uint8 flavor) external view accept {
        INSMatchmaker(_nsMaker).requestMatchmaker{value: ORG}(flavor);
    }

    function recordMoves(uint8 flavor, Move[] moves) external view accept {
        if (_active.exists(flavor) && _active[flavor] == GameStatus.Active)
            IGame(_cgames[flavor].gameAddress).recordMoves{value: RATE * (uint64(moves.length) + 1)}(moves);
    }
/*
    function getRating(uint8 flavor) external view returns (uint16 rating) {
        rating = _ratings[variant & 0x0F];
    }
*/
}
