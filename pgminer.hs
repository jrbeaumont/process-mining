import Tuura.Concurrency
import Data.List
import Data.Set (Set)
import qualified Data.Set as Set
import Data.Map (Map)
import qualified Data.Map as Map
import Tuura.Graph
import Tuura.Log
import Tuura.CmdLineFlags
import System.FilePath


readLog :: FilePath -> IO (Log String)
readLog filename = do
    contents <- readFile filename
    return . canonicalise $ parse contents

writeResult :: FilePath -> [String] -> IO ()
writeResult filename expressions = do
    let report = unlines $ addIds expressions
    writeFile filename report
  where
    addIds = zipWith (\n s -> "g" ++ show n ++ " = " ++ s) [1..]

toIntLog :: Log String -> (Log Int, Set Int, Int -> String)
toIntLog log = (intLog, Set.map a2i alphabet, i2a)
  where
    alphabet = events log
    a2i s    = Set.findIndex s alphabet
    i2a i    = Set.elemAt i alphabet
    intLog   = map (map a2i) log


main :: IO ()
main = do
    options <- parseArgs
    let [filename, result] = [optInput options] ++ if optOutput options == ""
            then [filename `replaceExtension` "cpog"]
            else [optOutput options]
    (logOriginal, alphabet, decode) <- fmap toIntLog $ readLog filename
    let log    = if (optSplit options) then dropSubtraces $ split logOriginal else logOriginal
        oracle = oracleMokhovCarmona log
        events = Set.elems alphabet
        cache  = Map.fromSet (uncurry oracle) $
                 Set.fromList [ (x, y) | x <- events, y <- events, x <= y ]
        co a b = cache Map.! (min a b, max a b)
        graphs = map (fmap decode) $ reduceLog co log
    putStrLn "Concurrent pairs:"
    print [ (decode x, decode y) | (x:xs) <- tails events, y <- xs, x `co` y ]
    writeResult result $ map printGraphExpr graphs
    putStrLn $ "\nComplete. See results in '" ++ result ++ "'."
