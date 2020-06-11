# Haskell Dominoes

## About

This is a small project implementing dominos using the functional programming language, haskell.

## Setup

1. Download and install GHCI (https://www.haskell.org/platform/)
2. Clone this repository.
3. Start GHCI in the root directory of this project (using command prompt), loading in the DomsMatch.hs file.
    * `$ ghci DomsMatch.hs` 
    
    OR
    
    * `$ ghci` then `Prelude> :l DomsMatch.hs`
4. Call the 'domsMatch' function with two players (listed below), the number of games to play and the random seed (e.g. `domsMatch hsdPlayer randomPlayer 100 42`)
5. The result will show how many games each player won respectively (e.g. _'(97, 3)'_ means that P1 won 97 games, P2 won 3 games.

The list of available players is:

* __randomPlayer__ - plays any playable domino from hand
* __hsdPlayer__ - plays the highest scoring playable domino from hand
* __winPlayer__ - tries to play _(5,4)_ if in hand, then plays like hsdPlayer until score is >=53, then tries to play domino to score 61, otherwise plays hsd
* __getClosePlayer__ - same as winPlayer apart from including a tactic where if it is not possible to score 61 then try to get score 59, else play hsd
* __blockPlayer__ - same as winPlayer apart from including a tactic where if the opposing player knocked on its last move, if possible, play a domino that will keep the ends of the board the same, blocking the opposing player
* __superPlayer__ - implements all the tactics from blockPlayer, getClosePlayer and winPlayer
* __blockOPWinPlayer__ - same tactics as winPlayer apart from including a tactic where if the opponent's score is 53 or above, if possible only play dominos that will block the other player from winning
