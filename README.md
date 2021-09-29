# **Chess Matchmaking**

The Chess Matchmaking smart-contract system provides extended support for the chess matches facilitation:

    Record keeping - electronic scoresheet, see "FIDE Article 8: The recording of the moves"
    Match making - matching opponents for the same game flavor using rating ranges, if applicable
    Custom facilitation of up to 144 possible flavors of the chess competitions transparent to end-user

## Pre-requisites

    GNU make 4.2.1 or newer
    jq 1.6 or newer
    wget (for "tools" target)

## Installation steps

    make tools: downloads binaries for Linux or MacOS into ~/bin directory
    make install: configures the local environment

## Game flavors

    144 flavors of chess matches stem from a combination of game variant, time limit, time control and rating accounting.

    VARIANT: one of (STANDARD CRAZYHOUSE CHESS960 KING_OF_THE_HILL THREE_CHECK ANTICHESS ATOMIC HORDE RACING_KINGS)
    TIME LIMIT: one of (CLASSICAL RAPID BLITZ BULLET)
    TIME CONTROL: FIXED or INCREMENTAL
    MODE: CASUAL or RATED

## Brief reference of smart-contracts

The "Game" smart-contract implements functionality of a scoresheet, as described in the Article 8: recording of the moves of the FIDE chess rules
Each of 144 possible combinations of the parameters is handled by a specialized instance of the "Matchmaker" contract, deployed upon request.
The Matchmaker contract provides match organizer services, pairing the contending players according to their preferences and rating in the particular chess flavor they are competing in, deploying Game contract on success.
The "Participant" contract keeps track of player's active games state, match history, and ratings (if applicable) in all the game flavors employed by the player so far.
