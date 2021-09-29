pragma ton-solidity >= 0.50.0;

import "Participant.sol";

contract Watcher is Participant {

    constructor(uint32 uid) public {
        _deployer = msg.sender;
        _uid = uid;
        IRepo(_deployer).onDeploy{value: FEE}(uid, 3);
    }

    function register(uint8 flavor) external view accept {
        address addr = _getMatchmaker(flavor);
        if (addr != address(0))
            IMatchmaker(addr).registerObserver{value: FEE}(_uid, _ratings[flavor]);
    }

    function resign(uint8 flavor) external view accept {
        address addr = _getMatchmaker(flavor);
        if (addr != address(0))
            IMatchmaker(addr).resignObserver{value: FEE}(_uid);
    }

    function updateGameAddress(uint8 flavor, uint32 gameId, address gameAddr) external override {
        _cgames[flavor] = CurrentGame(gameId, gameAddr);
    }
}
