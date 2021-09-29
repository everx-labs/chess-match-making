pragma ton-solidity >= 0.50.0;

struct CImg {
    uint16 version;
    uint16 initialBalance;
    TvmCell c;
}

interface IRepo {
    function onDeploy(uint32 id, uint8 n) external;
}
