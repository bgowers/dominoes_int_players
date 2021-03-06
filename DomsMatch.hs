module DomsMatch where

 {- play a 5's & 3's singles match between 2 given players
    play n games, each game up to 61
 -}
 
 --import Doms
 import System.Random
 import Data.List
 import Debug.Trace
 import Data.Maybe
 
 type Dom = (Int,Int)
 -- with highest pip first i.e. (6,1) not (1,6)

 data DomBoard = InitBoard|Board Dom Dom History
                    deriving (Show)
 
 type History = [(Dom,Player,MoveNum)]
 -- History allows course of game to be reconstructed                                            
                                               
 data Player = P1|P2 -- player 1 or player 2
                  deriving (Eq,Show)
 
 data End = L|R -- left end or right end
                  deriving (Eq,Show)
 
 type MoveNum = Int

 type Hand = [Dom]
  
 -- the full set of Doms
 domSet :: [Dom]
 
 domSet = [(6,6),(6,5),(6,4),(6,3),(6,2),(6,1),(6,0),
                 (5,5),(5,4),(5,3),(5,2),(5,1),(5,0),
                       (4,4),(4,3),(4,2),(4,1),(4,0),
                             (3,3),(3,2),(3,1),(3,0),
                                   (2,2),(2,1),(2,0),
                                         (1,1),(1,0),
                                               (0,0)]
                                                                                         
 
 type Move = (Dom,End)
 type Scores = (Int,Int)
                                                                                              
 -- state in a game - p1's hand, p2's hand, player to drop, current board, scores 
 type GameState =(Hand,Hand,Player, DomBoard, Scores)
 
 
 ------------------------------------------------------
 {- DomsPlayer
    given a Hand, the Board, which Player this is and the current Scores
    returns a Dom and an End
    only called when player is not knocking
    made this a type, so different players can be created
 -}
 
 type DomsPlayer = Hand->DomBoard->Player->Scores->(Dom,End)
 
 {- variables
     hand h
     board b
     player p
     scores s
 -}

 -- example players
 -- randomPlayer plays the first legal dom it can, even if it goes bust

 randomPlayer :: DomsPlayer
 
 randomPlayer h b p s 
  |not(null ldrops) = ((head ldrops),L)
  |otherwise = ((head rdrops),R)
  where
   ldrops = leftdrops h b
   rdrops = rightdrops h b
   
 -- hsdplayer plays highest scoring dom
 -- we have  hsd :: Hand->DomBoard->(Dom,End,Int)
 
 hsdPlayer h b p s = (d,e)
                     where (d,e,_)=hsd h b
                     
  -- highest scoring dom

 hsd :: Hand->DomBoard->(Dom,End,Int)
 
 hsd h InitBoard = (md,L,ms)
  where
   dscores = zip h (map (\ (d1,d2)->score53 (d1+d2)) h)
   (md,ms) = maximumBy (comparing snd) dscores
   
 
 hsd h b = 
  let
   ld = leftdrops h b
   rd = rightdrops h b
   lscores = zip ld (map (\d->(scoreDom d L b)) ld) -- [(Dom, score)]
   rscores = zip rd (map (\d->(scoreDom d R b)) rd)
   (lb,ls) = if (not(null lscores)) then (maximumBy (comparing snd) lscores) else ((0,0),-1) -- can't be chosen
   (rb,rs) = if (not(null rscores)) then (maximumBy (comparing snd) rscores) else ((0,0),-1)
  in
   if (ls>rs) then (lb,L,ls) else (rb,R,rs)
   
 -----------------------------------------------------------------------------------------
 --- INTELLIGENT PLAYERS ---

 {-
  winPlayer tries (5,4) on InitBoard otherwise hsd from startPlayHand,
  then hsd until score of 53, then tries to play a domino to score 61
  otherwise plays hsd
 -}
 winPlayer :: DomsPlayer

 winPlayer h InitBoard p s
   | elem (5,4) h = ((5,4),L)
   | otherwise = hsdPlayer playHand InitBoard p s
  where
   playHand = startPlayHand h

 winPlayer h b p s
   | pscore < 53 = (hsdPlayer h b p s)
   | not (win_dom == ((-1,-1),L)) = win_dom -- play winning dom
   | otherwise = hsdPlayer h b p s
  where
   pscore = playerScore p s
   win_dom = get61 (getValidDrops h b) pscore


 {-
  same as winPlayer apart from including a tactic where if it is not possible
  to score 61 (from anything after 53) then try to get score 59, else play hsd
 -}
 getClosePlayer :: DomsPlayer
   
 getClosePlayer h InitBoard p s
   | elem (5,4) h = ((5,4),L)
   | otherwise = hsdPlayer playHand InitBoard p s
  where
   playHand = startPlayHand h

 getClosePlayer h b p s
   | not (win_dom == ((-1,-1),L)) = win_dom
   | not (dom59 == ((-1,-1),L)) = dom59 -- play dom to score 59
   | pscore < 53 = (hsdPlayer h b p s)
   | otherwise = hsdPlayer h b p s
  where
   pscore = playerScore p s
   win_dom = get61 (getValidDrops h b) pscore
   dom59 = get59 (getValidDrops h b) pscore


 {-
  same as winPlayer apart from including a tactic where if the opposing
  player knocked on its last move, if possible, play a domino that will
  keep the ends of the board the same, blocking the opposing player
 -}
 blockPlayer :: DomsPlayer

 blockPlayer h InitBoard p s
   | elem (5,4) h = ((5,4),L)
   | otherwise = hsdPlayer playHand InitBoard p s
  where
   playHand = startPlayHand h

 blockPlayer h b p s
   -- below, if a domino containing numbers from both ends of the board,
   -- or a double of an end is contained within the viable drops, play that domino
   | not (win_dom == ((-1,-1),L)) = win_dom
   | (leftright || leftleft || rightright) && opknocking = blockingDom (le,re) h b   
   | pscore < 53 = (hsdPlayer h b p s)
   | otherwise = hsdPlayer h b p s
  where
   pscore = playerScore p s
   win_dom = get61 (getValidDrops h b) pscore
   (le,re) = orderDom (getEnds b) -- treat the ends of the board as a domino (ordered so highest pips first)
   alldrops = (leftdrops h b) ++ (rightdrops h b)
   leftright = elem (le,re) alldrops
   leftleft = elem (le,le) alldrops
   rightright = elem (re,re) alldrops
   opknocking = ((getLastMovePlayer (getHistory b)) == p)


 {-
  superPlayer implements all the tactics from blockPlayer, getClosePlayer and winPlayer
 -}
 superPlayer :: DomsPlayer

 superPlayer h InitBoard p s
   | elem (5,4) h = ((5,4),L)
   | otherwise = hsdPlayer playHand InitBoard p s
  where
   playHand = startPlayHand h

 superPlayer h b p s
   | not (win_dom == ((-1,-1),L)) = win_dom
   | (leftright || leftleft || rightright) && opknocking = blockingDom (le,re) h b
   | not (dom59 == ((-1,-1),L)) = dom59
   | pscore < 53 = (hsdPlayer h b p s)
   | otherwise = hsdPlayer h b p s
  where
   pscore = playerScore p s
   win_dom = get61 (getValidDrops h b) pscore
   dom59 = get59 (getValidDrops h b) pscore
   (le,re) = orderDom (getEnds b)
   alldrops = (leftdrops h b) ++ (rightdrops h b)
   leftright = elem (le,re) alldrops
   leftleft = elem (le,le) alldrops
   rightright = elem (re,re) alldrops
   opknocking = ((getLastMovePlayer (getHistory b)) == p)


 {-
  same tactics as winPlayer apart from including a tactic where if the opponent's
  score is 53 or above, if possible only play dominos that will block the other
  player from winning
 -} 

 blockOPWinPlayer :: DomsPlayer
 
 blockOPWinPlayer h InitBoard p s
   | elem (5,4) h = ((5,4),L)
   | otherwise = hsdPlayer playHand InitBoard p s
  where
   playHand = startPlayHand h

 blockOPWinPlayer h b p s
   | not (win_dom == ((-1,-1),L)) = win_dom
   | (opscore >= 53) && (not(null blockHand)) && ((hsdPlayer blockHand b p s) /= ((0,0),R)) = hsdPlayer blockHand b p s
   | pscore < 53 = (hsdPlayer h b p s)
   | otherwise = hsdPlayer h b p s
  where
   pscore = playerScore p s
   win_dom = get61 (getValidDrops h b) pscore
   (le,re) = getEnds b
   knockingLeft = genDomsX le
   knockingRight = genDomsX re
   remdoms = getRemDoms h (getBoard b)
   remdomsC = if ((getLastMovePlayer (getHistory b)) == p) then ((remdoms \\ knockingLeft) \\ knockingRight) else remdoms
   opscore = opScore p s
   playableDoms = (map (\dom -> (dom,L)) (leftdrops h b)) ++ (map (\dom -> (dom,R)) (rightdrops h b))
   blockHand = h \\ (badDoms remdoms playableDoms b opscore)

 ----------------------------------------------------------------------------------------------
 --- INTELLIGENT PLAYER HELPER FUNCTIONS ---

 -- hand to play from at start

 startPlayHand :: Hand -> Hand

 startPlayHand h
   | hasall = h
   | has63 && hasd6 = delete (5,5) (delete (5,2) h)
   | has52 && hasd5 = delete (6,6) (delete (6,3) h)
   | otherwise = newHand
  where
   hasd6 = elem (6,6) h
   has63 = elem (6,3) h
   hasd5 = elem (5,5) h
   has52 = elem (5,2) h
   hasall = hasd6 && has63 && hasd5 && has52
   newHand = h \\ [(5,5),(6,6),(5,2),(6,3)]
 

 -- return a domino from hand that can obtain a score of 61

 get61 :: [(Dom,Int,End)] -> Int -> (Dom,End)

 get61 [] _ = ((-1,-1),L)

 get61 ((dom,score,end):t) pscore
   | (61 - pscore) == score = (dom,end)
   | otherwise = get61 t pscore
  

 -- return a domino from hand that can obtain a score of 59

 get59 :: [(Dom,Int,End)] -> Int -> (Dom,End)
  
 get59 [] _ = ((-1,-1),L)

 get59 ((dom,score,end):t) pscore
   | (59 - pscore) == score = (dom,end)
   | otherwise = get59 t pscore


 -- get dominoes with their scores and ends to play and concatenate the left and right lists

 getValidDrops :: Hand -> DomBoard -> [(Dom,Int,End)]

 getValidDrops h b = 
  let
   ld = leftdrops h b
   rd = rightdrops h b
   leftDomsScores = if (not(null ld)) then (getDomScoresAndEnds ld L b) else []
   rightDomsScores = if (not(null rd)) then (getDomScoresAndEnds rd R b) else []
   allDomsScores = leftDomsScores ++ rightDomsScores
  in
   allDomsScores


 -- zip dominoes with their score and end to play

 getDomScoresAndEnds :: [Dom] -> End -> DomBoard -> [(Dom,Int,End)]

 getDomScoresAndEnds doms end board = map (\dom -> (dom,(scoreDom dom end board),end)) doms


 -- get remaining score of player
 
 playerScore :: Player -> Scores -> Int
 
 playerScore player (s1,s2)
  | player == P1 = s1
  | otherwise = s2


 -- get remaining score of other player
 
 opScore :: Player -> Scores -> Int
 
 opScore player (s1,s2)
  | player == P1 = s2
  | otherwise = s1
 

 -- get the ends of a given board

 getEnds :: DomBoard -> (Int,Int)

 getEnds (Board (l,_) (_,r) _) = (l,r)


 -- return the history of a given board

 getHistory :: DomBoard -> History

 getHistory (Board _ _ history) = history


 -- return the player of the last move made

 getLastMovePlayer :: History -> Player

 getLastMovePlayer history = p
  where
   moves = map (\(_,player,move) -> (player,move)) history
   (p,moveNum) = maximumBy (comparing snd) moves


 -- get dominoes from hand that match ends of the board

 blockingDom :: Dom -> Hand -> DomBoard -> (Dom,End)

 blockingDom (l,r) h b
   | elem (l,r) ld = ((l,r),L)
   | elem (l,r) rd = ((l,r),R)
   | elem (l,l) ld = ((l,l),L)
   | elem (l,l) rd = ((l,l),R)
   | elem (r,r) ld = ((r,r),L)
   | elem (r,r) rd = ((r,r),R)
  where
   ld = leftdrops h b
   rd = rightdrops h b


 -- get remaining dominoes (whole set minus those in hand and on board)

 getRemDoms :: Hand -> [Dom] -> [Dom]

 getRemDoms hand board = ((domSet \\ hand) \\ board)


 {-
  bad doms to play
  i.e. dominoes that will enable the other player to win

  remdoms - all remaining dominoes
  hand - all playable dominoes from original hand with their ends
  board - the board
  opscore - opponent's score
 -}
 badDoms :: [Dom] -> [(Dom,End)] -> DomBoard -> Int -> [Dom]
 
 badDoms _ [] _ _ = []

 badDoms remdoms ((dom,end):rhand) board opscore = filter (/=(-1,-1)) (badDom:(badDoms remdoms rhand board opscore))
  where
   Just newboard = playDom P1 dom end board
   remdomsWithScores = getValidDrops remdoms newboard
   opWinDoms = filter (\(_,opdomscore,_) -> ((61 - opscore) == opdomscore)) remdomsWithScores
   badDom = if (not(null opWinDoms)) then (dom) else (-1,-1)


 -- generate all doms that contain a given number

 genDomsX :: Int -> [Dom]

 genDomsX x = [if (x<y) then (x,y) else (y,x) | y <- [0..6]]


 -- get the dominoes from a given DomBoard
 
 getBoard :: DomBoard -> [Dom]
 
 getBoard (Board _ _ history) = [dom|(dom, _, _)<-history]


 -- change domino to greatest pip first
 
 orderDom :: Dom -> Dom

 orderDom (l,r)
   | l > r = (l,r)
   | otherwise = (r,l)
 
 -----------------------------------------------------------------------------------------
 {- top level fn
    args: 2 players (p1, p2), number of games (n), random number seed (seed)
    returns: number of games won by player 1 & player 2
    calls playDomsGames giving it n, initial score in games and random no gen
 -} 
 
 domsMatch :: DomsPlayer->DomsPlayer->Int->Int->(Int,Int)
 
 domsMatch p1 p2 n seed = playDomsGames p1 p2 n (0,0) (mkStdGen seed)
 
 -----------------------------------------------------------------------------------------
 
{- playDomsGames plays n games

  p1,p2 players
  (s1,s2) their scores
  gen random generator
-}
 
 playDomsGames :: DomsPlayer->DomsPlayer->Int->(Int,Int)->StdGen->(Int,Int)
 
 playDomsGames _ _ 0 score_in_games _ = score_in_games -- stop when n games played
 
 playDomsGames p1 p2 n (s1,s2) gen 
   |gameres==P1 = playDomsGames p1 p2 (n-1) (s1+1,s2) gen2 -- p1 won
   |otherwise = playDomsGames p1 p2 (n-1) (s1,s2+1) gen2 -- p2 won
  where
   (gen1,gen2)=split gen -- get 2 generators, so doms can be reshuffled for next hand
   gameres = playDomsGame p1 p2 (if (odd n) then P1 else P2) (0,0) gen1 -- play next game p1 drops if n odd else p2
 
 -----------------------------------------------------------------------------------------
 -- playDomsGame plays a single game - 61 up
 -- returns winner - P1 or P2
 -- the Bool pdrop is true if it's p1 to drop
 -- pdrop alternates between games
 
 playDomsGame :: DomsPlayer->DomsPlayer->Player->(Int,Int)->StdGen->Player
 
 playDomsGame p1 p2 pdrop scores gen 
  |s1==61 = P1
  |s2==61 = P2
  |otherwise = playDomsGame p1 p2 (if (pdrop==P1) then P2 else P1) (s1,s2) gen2
  where
   (gen1,gen2)=split gen
   (s1,s2)=playDomsHand p1 p2 pdrop scores gen1  
  
 -----------------------------------------------------------------------------------------
 -- play a single hand
  
 playDomsHand :: DomsPlayer->DomsPlayer->Player->(Int,Int)->StdGen->(Int,Int)
 
 playDomsHand p1 p2 nextplayer scores gen = 
   playDoms p1 p2 init_gamestate
  where
   spack = shuffleDoms gen
   p1_hand = take 9 spack
   p2_hand = take 9 (drop 9 spack)
   init_gamestate = (p1_hand,p2_hand,nextplayer,InitBoard,scores) 
   
 ------------------------------------------------------------------------------------------   
 -- shuffle 
 
 shuffleDoms :: StdGen -> [Dom]

 shuffleDoms gen =  
  let
    weights = take 28 (randoms gen :: [Int])
    dset = (map fst (sortBy  
               (\ (_,w1)(_,w2)  -> (compare w1 w2)) 
               (zip domSet weights)))
  in
   dset
   
 ------------------------------------------------------------------------------------------
 -- playDoms runs the hand
 -- returns scores at the end

 
 playDoms :: DomsPlayer->DomsPlayer->GameState->(Int,Int)
 
 playDoms _ _ (_,_,_,_, (61,s2)) = (61,s2) --p1 has won the game
 playDoms _ _ (_,_,_,_, (s1,61)) = (s1,61) --p2 has won the game
 
 
 playDoms p1 p2 gs@(h1,h2,nextplayer,b,scores)
  |(kp1 &&  kp2) = scores -- both players knocking, end of the hand
  |((nextplayer==P1) && (not kp1)) =  playDoms p1 p2 (p1play p1 gs) -- p1 plays, returning new gameState. p2 to go next
  |(nextplayer==P1) = playDoms p1 p2 (p2play p2 gs) -- p1 knocking so p2 plays
  |(not kp2) = playDoms p1 p2 (p2play p2 gs) -- p2 plays
  |otherwise = playDoms p1 p2 (p1play p1 gs) -- p2 knocking so p1 plays
  where
   kp1 = knocking h1 b -- true if p1 knocking
   kp2 = knocking h2 b -- true if p2 knocking
   
 ------------------------------------------------------------------------------------------
 -- is a player knocking?

 knocking :: Hand->DomBoard->Bool
 
 knocking h b = 
  ((null (leftdrops h b)) && (null (rightdrops h b))) -- leftdrops & rightdrops in doms.hs
 
 ------------------------------------------------------------------------------------------
   
 -- player p1 to drop
 
 p1play :: DomsPlayer->GameState->GameState
 
 p1play p1 (h1,h2,_,b, (s1,s2)) = 
  ((delete dom h1), h2, P2,(updateBoard dom end P1 b), (ns1, s2))
   where
    (dom,end) = p1 h1 b P1 (s1,s2)-- call the player, returning dom dropped and end it's dropped at.
    score = s1+ (scoreDom dom end b) -- what it scored
    ns1 = if (score >61) then s1 else score -- check for going bust
    
 
 -- p2 to drop
   
 p2play :: DomsPlayer->GameState->GameState
 
 p2play p2 (h1,h2,_,b,(s1,s2)) = 
  (h1, (delete dom h2),P1, (updateBoard dom end P2 b), (s1, ns2))
  where
   (dom,end) = p2 h2 b P2 (s1,s2)-- call the player, returning dom dropped and end it's dropped at.
   score = s2+ (scoreDom dom end b) -- what it scored
   ns2 = if (score >61) then s2 else score -- check for going bust
 
   -------------------------------------------------------------------------------------------
 -- updateBoard 
 -- update the board after a play
 
 updateBoard :: Dom->End->Player->DomBoard->DomBoard
 
 updateBoard d e p b
  |e==L = playleft p d b
  |otherwise = playright p d b

  ------------------------------------------------------------------------------------------
 -- doms which will go left
 leftdrops :: Hand->DomBoard->Hand
 
 leftdrops h b = filter (\d -> goesLP d b) h
 
 -- doms which go right
 rightdrops :: Hand->DomBoard->Hand
 
 rightdrops h b = filter (\d -> goesRP d b) h 
 
 -------------------------------------------------
 -- 5s and 3s score for a number
  
 score53 :: Int->Int
 score53 n = 
  let 
   s3 = if (rem n 3)==0 then (quot n 3) else 0
   s5 = if (rem n 5)==0 then (quot n 5) else 0 
  in
   s3+s5
   
 ------------------------------------------------ 
 -- need comparing
 -- useful fn specifying what we want to compare by
 comparing :: Ord b=>(a->b)->a->a->Ordering
 comparing f l r = compare (f l) (f r)
 
 ------------------------------------------------
 -- scoreDom
 -- what will a given Dom score at a given end?
 -- assuming it goes
 
 scoreDom :: Dom->End->DomBoard->Int
 
 scoreDom d e b = scoreboard (fromMaybe InitBoard (playDom P1 d e b))
                  -- where
                  --  nb = traceShow ("new board: " ++ show (playDom P1 d e b)) (fromMaybe [] (playDom P1 d e b)) -- player doesn't matter
 
 ----------------------------------------------------
 -- play to left - it will go
 playleft :: Player->Dom->DomBoard->DomBoard
 
 playleft p (d1,d2) InitBoard = Board (d1,d2) (d1,d2) [((d1,d2),p,1)]
 
 playleft p (d1,d2) (Board (l1,l2) r h)
  |d1==l1 = Board (d2,d1) r (((d2,d1),p,n+1):h)
  |otherwise =Board (d1,d2) r (((d1,d2),p,n+1):h)
  where
    n = maximum [m |(_,_,m)<-h] -- next drop number
    
 -- play to right
 playright :: Player->Dom->DomBoard->DomBoard
 
 playright p (d1,d2) InitBoard = Board (d1,d2) (d1,d2) [((d1,d2),p,1)]
 
 playright p (d1,d2)(Board l (r1,r2) h)
  |d1==r2 = Board l (d1,d2) (h++[((d1,d2),p,n+1)])
  |otherwise = Board l (d2,d1) (h++[((d2,d1),p,n+1)])
  where 
    n = maximum [m |(_,_,m)<-h] -- next drop number
 
 ------------------------------------------------------
 -- predicate - will given domino go at left?
 -- assumes a dom has been played
 
 goesLP :: Dom->DomBoard->Bool
 
 goesLP _ InitBoard = True
 
 goesLP (d1,d2) (Board (l,_) _ _) = (l==d1)||(l==d2)


 -- will dom go to the right?
 -- assumes a dom has been played
 
 goesRP :: Dom->DomBoard->Bool
 
 goesRP _ InitBoard = True
 
 goesRP (d1,d2) (Board _ (_,r) _) = (r==d1)||(r==d2)
 
 ------------------------------------------------

 -- playDom
 -- given player plays
 -- play a dom at left or right, if it will go

 
 playDom :: Player->Dom->End->DomBoard->Maybe DomBoard
 
 playDom p d L b
   |goesLP d b = Just (playleft p d b)
   |otherwise = Nothing
 
 playDom p d R b
   |goesRP d b = Just (playright p d b)
   |otherwise = Nothing
   
 ---------------------------------------------------    
 -- 5s & threes score for a board
 
 scoreboard :: DomBoard -> Int
 
 scoreboard InitBoard = 0

 scoreboard (Board (l1,l2) (r1,r2) hist)
  |length hist == 1 = score53 (l1+l2) -- 1 dom played, it's both left and right end
  |otherwise = score53 ((if l1==l2 then 2*l1 else l1)+ (if r1==r2 then 2*r2 else r2))   