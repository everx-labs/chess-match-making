pragma ton-solidity >= 0.50.0;

import "Partner.sol";

contract NSMatchmakerClient is Partner {

    constructor(uint32 uid) public Partner(uid) {
        _deployer = msg.sender;
        _uid = uid;
        IRepo(_deployer).onDeploy{value: FEE}(uid, 1);
    }

    function requestGameExt(uint8 variant, uint8 timeControl, bool incremental, bool rated, uint16 ratingLo, uint16 ratingHi, uint8 quota) external accept {
        _requestGame(_flavor(variant, timeControl, incremental, rated), ratingLo, ratingHi, quota);
    }

    function joinGameExt(uint8 variant, uint8 timeControl, bool incremental, bool rated) external view accept {
        _joinGame(_flavor(variant, timeControl, incremental, rated));
    }

    function getFlavor(uint8 variant, uint8 timeControl, bool incremental, bool rated) external pure returns (uint8 flavor) {
        flavor = _flavor(variant, timeControl, incremental, rated);
    }
}
