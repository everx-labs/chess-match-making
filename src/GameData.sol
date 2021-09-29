pragma ton-solidity >= 0.50.0;

enum GameStatus { Undefined, New, Cancelled, Requested, Proposed, Accepted, Observed, Active, Completed, Failed, Failed2, Expired, Reserved, Last }
enum GameResult { Undefined, Cancelled, Tie, WhiteWon, BlackWon, Reserved, Last }

struct Move {
    uint16 index;
    bool isWhite;
    string alg;
}
