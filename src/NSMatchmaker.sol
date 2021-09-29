pragma ton-solidity >= 0.50.0;

import "Organizers.sol";
import "CasualMatchmaker.sol";
import "RatedMatchmaker.sol";
import "IRepo.sol";

contract NSMatchmaker is Base, INSMatchmaker {

    struct MakerS {
        uint8 flavor;
        address addr;
        uint8 status;
        uint16 rating;
        address requestedBy;
    }

    uint16 constant DEF_MATCHMAKER_RATING = 100;

    mapping (uint8 => uint32) public _dedicated;
    MakerS[] public _makers;
    MakerS[] public _makersCopy;

    uint16 public _version;
    TvmCell public _mrCode;
    TvmCell public _mcCode;
    TvmCell public _gameCode;
    uint32 _nMatchmakers;
    mapping (uint32 => address) public _requests;
    address public _peer;

    function queryMatchmakerAddress(uint8 gameFlavor) external override {
        INSMatchmakerClient(msg.sender).updateMatchmakerAddress(gameFlavor, _makers[_dedicated[gameFlavor]].addr);
    }

    function _deployCasualMatchmaker(uint32 counter, uint8 gameFlavor) private view returns (address) {
        TvmCell si = tvm.buildStateInit({contr: CasualMatchmaker, varInit: {_uid: counter, _flavor: gameFlavor, _maker: address(this)}, code: _mcCode});
        return new CasualMatchmaker{value: CAS, stateInit: si}(_gameCode);
    }

    function _deployRatedMatchmaker(uint32 counter, uint8 gameFlavor) private view returns (address) {
        TvmCell si = tvm.buildStateInit({contr: RatedMatchmaker, varInit: {_uid: counter, _flavor: gameFlavor, _maker: address(this)}, code: _mrCode});
        return new RatedMatchmaker{value: DEP, stateInit: si}(_gameCode);
    }

    function requestMatchmaker(uint8 gameFlavor) external override {
        if (!_dedicated.exists(gameFlavor)) {
            uint32 counter = _nMatchmakers++;
            address addr = gameFlavor < RATED ? _deployCasualMatchmaker(counter, gameFlavor) : _deployRatedMatchmaker(counter, gameFlavor);
            // Insert value checks here
            _makers.push(MakerS(gameFlavor, addr, 1, DEF_MATCHMAKER_RATING, msg.sender));
        } else {
            INSMatchmakerClient(msg.sender).updateMatchmakerAddress{value: DEF}(gameFlavor, _makers[_dedicated[gameFlavor]].addr);
        }
    }

    function onMatchmakerDeploy(uint32 id) external override {
        MakerS maker = _makers[id];
        if (maker.addr == msg.sender) {
  //          tvm.accept();
            // TODO: check status and address
            _makers[id].status = 2;
            _dedicated[maker.flavor] = id;
            INSMatchmakerClient(maker.requestedBy).updateMatchmakerAddress{value: DEF}(maker.flavor, maker.addr);
//            Matchmaker(msg.sender).setGameSI{value: DEF}(_gsi);
        }
    }

    function setMatchmakerCode(uint8 flavor, TvmCell c) external {
        tvm.accept();
        if (flavor < RATED)
            _mcCode = c;
        else
            _mrCode = c;
    }

    function setGameCode(TvmCell c) external {
        tvm.accept();
        _gameCode = c;
    }

    function shareGameCode(address addr) external view {
        if (msg.sender == address(this)) {
            tvm.accept();
            Matchmaker(addr).setGameCode{value: DEF}(_gameCode);
        }
    }

    function sendGameCode(uint32 n) external view {
        tvm.accept();
        this.shareGameCode(_makers[n].addr);
    }

    function flushGameCode() external view {
        tvm.accept();
        for (MakerS maker: _makers)
            this.shareGameCode(maker.addr);
    }

    function setPeer(address addr) external accept {
        _peer = addr;
    }

    function shareData(address addr) external view accept {
        NSMatchmaker(addr).loadData(_makers);
    }

    function loadData(MakerS[] makers) external accept {
        _makersCopy = makers;
    }

    function commitData() external accept {
        _makers = _makersCopy;
    }

    function upgrade(TvmCell c) external {
//        require(msg.pubkey() == tvm.pubkey(), 100);
        tvm.accept();
        tvm.commit();
        tvm.setcode(c);
        tvm.setCurrentCode(c);
        onCodeUpgrade();
    }

    function onCodeUpgrade() internal {
        tvm.resetStorage();
        _version++;
    }

}
