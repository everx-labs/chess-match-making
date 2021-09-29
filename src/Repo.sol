pragma ton-solidity >= 0.50.0;

import "IRepo.sol";
import "NSMatchmaker.sol";
import "NSMatchmakerClient.sol";
import "Watcher.sol";

contract Repo is Base, IRepo {
    uint32 public _counter;
    mapping (uint8 => TvmCell) public _images;
    uint8 public _version = 4;
    uint8 public _flavor;

    struct ImageData {
        uint8 flavor;
        uint16 initialBalance;
    }
    mapping (uint8 => ImageData) public _meta;

    struct Active {
        uint8 kind;
        uint32 id;
    }
    mapping (address => Active) public _active;

    address public _nsmm;

    function setNSMatchmakerAddress(address addr) external accept {
        _nsmm = addr;
    }

    function _spawn(uint8 n) private {
        uint32 counter = _counter++;
        address addr;
        if (n == 1)
            addr = new NSMatchmakerClient{value: 40 ton, code: _images[n], pubkey: counter}(counter);
        else if (n == 2)
            addr = new Partner{value: 15 ton, code: _images[n], pubkey: counter}(counter);
        else if (n == 3)
            addr = new Watcher{value: 6 ton, code: _images[n], pubkey: counter}(counter);
        NSMatchmakerClient(addr).setNSMatchmakerAddress{value: DEF}(_nsmm);
    }

    function deploy(uint8 flavor) external accept {
        _counter += _version * 10;
        _flavor = flavor;
        _spawn(1);
        _spawn(2);
        _spawn(3);
    }

    function deployOne(uint8 n) external accept {
        _spawn(n);
    }

    function onDeploy(uint32 id, uint8 n) external override accept {
        address addr = msg.sender;
        if (n == 1)
            NSMatchmakerClient(addr).requestMatchmaker{value: DEF}(_flavor);
        if (n == 2)
            Partner(addr).queryMatchmaker{value: DEF}(_flavor);
        if (n == 3)
            Watcher(addr).queryMatchmaker{value: DEF}(_flavor);
        _active[addr] = Active(n, id);
    }

    function updateNSMatchmaker() external view accept {
        NSMatchmaker(_nsmm).upgrade{value: REG}(_images[0]);
    }

    function updateImage(uint8 n, uint8 flavor, TvmCell c) external accept {
        TvmCell code = c.toSlice().loadRef();
        _images[n] = code;
        if (n == 4 || n == 5)
            NSMatchmaker(_nsmm).setMatchmakerCode{value: REG}(flavor, code);
        if (n == 6)
            NSMatchmaker(_nsmm).setGameCode{value: REG}(code);
    }

    function upgrade(TvmCell c) external {
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
