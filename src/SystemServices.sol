pragma ton-solidity >= 0.50.0;

interface INSMatchmaker {
    function queryMatchmakerAddress(uint8 gameFlavor) external;
    function requestMatchmaker(uint8 gameFlavor) external;
    function onMatchmakerDeploy(uint32 uid) external;
}

interface INSMatchmakerClient {
    function updateMatchmakerAddress(uint8 gameFlavor, address addr) external;
}
