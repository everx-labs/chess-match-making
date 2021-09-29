pragma ton-solidity >= 0.50.0;

abstract contract Base {

    uint8 _ver = 1;

    uint8 constant VARIANT      = 0 << 1;
    uint8 constant NONE         = 0;
    uint8 constant STANDARD     = 1;
    uint8 constant CRAZYHOUSE   = 2;
    uint8 constant CHESS960     = 3;
    uint8 constant KOTH         = 4;
    uint8 constant THREE_CHECK  = 5;
    uint8 constant ANTICHESS    = 6;
    uint8 constant ATOMIC       = 7;
    uint8 constant HORDE        = 8;
    uint8 constant RACING_KINGS = 9;

    uint8 constant FAST_CHESS   = 4 << 1;
    uint8 constant CLASSICAL    = 0 * FAST_CHESS;
    uint8 constant RAPID        = 1 * FAST_CHESS;
    uint8 constant BLITZ        = 2 * FAST_CHESS;
    uint8 constant BULLET       = 3 * FAST_CHESS;

    uint8 constant TIMING       = 6 << 1;
    uint8 constant FIXED        = 0 * TIMING;
    uint8 constant INCREMENT    = 1 * TIMING;

    uint8 constant MODE         = 7 << 1;
    uint8 constant CASUAL       = 0 * MODE;
    uint8 constant RATED        = 1 * MODE;

    uint64 constant RATE    = 20 milliton; // Minimal processing fee: rate per move
    uint64 constant LGHT    = 30 milliton; // Lightweight message processing
    uint64 constant DEF     = 40 milliton;  // Default message processing fee
    uint64 constant REG     = 0.5 ton;  // Regular processing fee
    uint64 constant FEE     = 1 ton;  // Registration fee
    uint64 constant BET     = 3 ton;  // Default bet value for friendly games
    uint64 constant CAS     = 2 ton;  // Casual matchmaker contract deployment value
    uint64 constant DEP     = 5 ton;  // Default deployment value of the game contract
    uint64 constant BOND    = 5 ton; // Default bond value for rated games
    uint64 constant ORG     = 10 ton; // Organizational fee to deploy a new Matchmaker

    uint16 constant DEFAULT_RATING          = 1500;

    /* Error codes */

    uint8 constant UNKNOWN_GAME_ID              = 130;

    uint8 constant RATING_OUT_OF_RANGE          = 150;
    uint8 constant UNKNOWN_RECORDER             = 151;

    uint8 constant DEPLOYER_ADDRESS_MISMATCH    = 165;

    uint8 constant GAME_ADDRESS_MISMATCH        = 178;
    uint8 constant ENTRANT_ADDRESS_MISMATCH     = 179;
    uint8 constant ENTRANT_ID_MISMATCH          = 180;
    uint8 constant ENTRANT_RATING_MISMATCH      = 181;
    uint8 constant ENTRANT_RATING_TOO_LOW       = 182;
    uint8 constant ENTRANT_RATING_TOO_HIGH      = 183;

    uint8 constant NO_PENDING_REQUESTS          = 190;
    uint8 constant PENDING_USER_ID_MISMATCH     = 191;

    uint8 constant ARBITE_INVALID_GAME_ID       = 200;
    uint8 constant OBSERVER_ALREADY_REGISTERED  = 201;
    uint8 constant OBSERVER_IS_NOT_REGISTERED   = 202;
    uint8 constant OBSERVER_ID_MISMATCH         = 203;

    uint8 constant NO_PLAYERS_FOUND             = 220;
    uint8 constant REQUESTOR_NOT_FOUND          = 221;
    uint8 constant NOT_ENOUGH_PARTICIPANTS      = 222;
    uint8 constant TOO_MANY_PARTICIPANTS        = 223;

    modifier accept {
        tvm.accept();
        _;
    }
}
