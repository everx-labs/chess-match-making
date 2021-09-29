pragma ton-solidity >= 0.50.0;

import "Organizers.sol";

contract Game is IGame {

    uint8 public _barrier;

    uint32 static _id;
    uint32[] static _entrants;
    address static _maker;

    mapping (address => uint8) public _writers;

    struct Records {
        mapping (uint16 => string) game; // Moves placed into the game record
        uint16 sp;      // last move recorded
        uint32 ts;      // most recent record timestamp
    }
    Records[] public _recs;

    uint16 public _maxMove;    // Maximal move recorded by participants
    uint32 public _modifiedAt; // timestamp of the most recent record

    mapping (uint16 => mapping (uint => uint8)) public _consensys;
    uint16 public _checkPoint;

    uint64 constant RATE    = 20 milliton;
    uint64 constant DEF     = 40 milliton;
    uint64 constant REG     = 0.3 ton;

    struct ErrorS {
        uint8 id;
        uint16 index;
        uint8 code;
        uint32 ts;
    }
    ErrorS[] public _errorLog;

    uint8 constant UNKNOWN_RECORDER         = 151;
    uint8 constant ILLEGAL_MOVE_INDEX       = 152;
    uint8 constant GAP_AT_INDEX             = 153;

    uint8 constant DEPLOYER_ADDRESS_MISMATCH = 165;


    uint32 _uid;
    GameResult _result;

    constructor(address[] writers) public {
        if (msg.sender != _maker)
            _error(0, 0, DEPLOYER_ADDRESS_MISMATCH);
        Records r;
        uint8 cap = uint8(writers.length);
        _barrier = cap - cap / 3;
        for (uint i = 0; i < cap; i++) {
            _writers[writers[i]] = uint8(i);
            _recs.push(r);
        }
        IMatchmaker(_maker).onGameDeploy{value: REG}(_id);
    }

    function _error(uint8 id, uint16 index, uint8 code) private {
        _errorLog.push(ErrorS(id, index, code, now));
    }

    function _align(uint8 id, uint16 index) private {
        Records rec = _recs[id];
        uint16 sp = rec.sp;
        while (sp < index) {
            _error(id, sp, GAP_AT_INDEX);
            _recs[id].game[sp] = "???";
            sp++;
        }
        if (sp > rec.sp)
            _recs[id].sp = sp;
    }

    function _advanceCheckPoint(uint hashCode) private {
        _checkFinality(hashCode);
        _checkPoint++;
        for ((uint hc, uint8 c): _consensys[_checkPoint])
            if (c >= _barrier)
                _advanceCheckPoint(hc);
    }

    function recordMoves(Move[] moves) external override {
        if (!_writers.exists(msg.sender)) {
            _error(0, 0, UNKNOWN_RECORDER);
            return;
        }
        tvm.accept();   // TODO: remove this

        uint8 writerId = _writers[msg.sender];

        for (Move move: moves) {
            if (move.index == 0)
                _error(writerId, move.index, ILLEGAL_MOVE_INDEX);
            uint16 i = move.index * 2 - (move.isWhite ? 2 : 1);

            // If this participant has already recorded this move, skip to the next iteration
            if (_recs[writerId].game.exists(i))
                continue;

            _align(writerId, i);
            _recs[writerId].game[i] = move.alg;
            _recs[writerId].sp++;
            uint hashCode = sha256(move.alg);

            _consensys[i][hashCode]++;
            if (i == _checkPoint && _consensys[i][hashCode] >= _barrier)
                _advanceCheckPoint(hashCode);
            if (i > _maxMove)
                _maxMove = i;
        }
        _modifiedAt = now;
    }

    function _isGameOver(uint hashCode) private pure returns (GameResult) {
        if (hashCode == 0xde60b41c4a3cb0dc5d939412d3af37dc981f5b3b8b5a7153325d1cfc8c1d0c6d)
            return GameResult.Tie;
        else if (hashCode == 0xa302da3294ef556ab933c9b09a7fdebf7ca7bb51868dee1cc24b35dc4e68cf97)
            return GameResult.WhiteWon;
        else if (hashCode == 0x389f7fbc8e058d61efa91d591e1dc5c5ad418fec3fb2d4aa68ec49ae4e7b784e)
            return GameResult.BlackWon;
        return GameResult.Undefined;
    }

    function processResult(GameResult result) external {
        if (msg.sender == address(this)) {
            tvm.accept();
            _result = result;
            IMatchmaker(_maker).proposeCompletion{value: REG}(_id, result);
        }
    }

    function _checkFinality(uint hashCode) private pure {
        GameResult result = _isGameOver(hashCode);
        if (result > GameResult.Undefined)
            this.processResult(result);
    }

    function _formatMatch(mapping (uint16 => string) game) private pure returns (string result) {
        for ((uint16 index, string text): game) {
            if (index % 2 == 0)
                result.append(format("{}.", index / 2 + 1));
            result.append(text + " ");
        }
    }

    function viewMatch() external view returns (string[] records) {
        for (Records r: _recs)
            records.push(_formatMatch(r.game));
    }

    function _name(uint8 id) private pure returns (string) {
        return id < 2 ? format("Player {}: ", id + 1) : format("Observer {}: ", id - 1);
    }

    function _index(uint16 index) private pure returns (string) {
        return format(" move {}, ", index / 2 + 1) + (index % 2 == 0 ? "white" : "black");
    }

    function _code(uint8 code) private pure returns (string) {
        if (code == ILLEGAL_MOVE_INDEX)
            return "Illegal move index";
        if (code == GAP_AT_INDEX)
            return "Gap in records";
    }

    function _ts(uint32 ts) private pure returns (string) {
        return format(" at {}\n", ts);
    }

    function errorLog() external view returns (string[] errors) {
        for (ErrorS e: _errorLog)
            errors.push(_name(e.id) + _code(e.code) + _index(e.index) + _ts(e.ts));
    }

}
