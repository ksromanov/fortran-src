{
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
{-# LANGUAGE DeriveGeneric #-}

module Forpar.Lexer.FreeForm where

import Data.Data
import Data.Typeable
import Data.Maybe (isJust, isNothing, fromJust)
import Data.Char (toLower)
import Data.Word (Word8)

import Control.Monad (join)

import GHC.Generics

import Forpar.ParserMonad
import Forpar.Util.Position
import Forpar.Util.FirstParameter

import Debug.Trace

}

$digit = 0-9
$octalDigit = 0-7
$hexDigit = [a-e $digit]
$bit = 0-1

$letter = a-z
$alphanumeric = [$letter $digit \_]

@label = $digit{1,5}
@name = $letter $alphanumeric{0,9} $alphanumeric{0,9} $alphanumeric{0,9} $alphanumeric?

@binary = b\'$bit+
@octal = o\'$octalDigit+
@hex = z\'$hexDigit+

@digitString = $digit+
@kindParam = (@digitString|@name)
@intLiteralConst = @digitString (\_ @kindParam)?
@bozLiteralConst = (@binary|@octal|@hex)

$expLetter = [ed]
@exponent = [\-\+] @digitString
@significand = @digitString? \. @digitString
@realLiteral = @significand ($expLetter @exponent)? (\_ @kindParam)?
             | @digitString $expLetter @exponent \_ @kindParam?
             | @digitString \. $expLetter @exponent (\_ @kindParam)?
             | @digitString \_ @kindParam
@altRealLiteral = @digitString \.

@characterLiteralBeg = (@kindParam \_)? (\'|\")

@bool = ".true." | ".false."
@logicalLiteral = @bool (\_ @kindParam)?

--------------------------------------------------------------------------------
-- Start codes | Explanation
--------------------------------------------------------------------------------
-- 0           | For statement starters
-- scI         | For statements that can come after logical IF
-- scC         | To be used in lexCharacter, it only appears to force Happy to
--             | resolve it.
-- scN         | For everything else
--------------------------------------------------------------------------------
tokens :-

<0,scN> "!"                                         { lexComment }

<0,scN> (\n\r|\r\n|\n)                              { toSC 0 >> addSpan TNewline }
<0,scN,scI> [\t\ ]+                                 ;

<scN> "("                                           { addSpan TLeftPar }
<scN> ")"                                           { addSpan TRightPar }
<scN> ","                                           { addSpan TComma }
<scN> ";"                                           { addSpan TSemiColon }
<scN> ":"                                           { addSpan TColon }
<scN> "::"                                          { addSpan TDoubleColon }
<scN> "="                                           { addSpan TOpAssign}
<scN> "=>"                                          { addSpan TArrow }
<scN> "%"                                           { addSpan TPercent }

<0,scI> @name / { partOfExpOrPointerAssignmentP }   { addSpanAndMatch TId }
<0> @name / { constructNameP }                    { addSpanAndMatch TId }

-- Program units
<0> "program"                                     { addSpan TProgram }
<0> "end"\ *"program"                             { addSpan TEndProgram }
<0> "function"                                    { addSpan TFunction }
<scN> "function" / { typeSpecP }                              { addSpan TFunction }
<0> "end"\ *"function"                            { addSpan TEndFunction }
<scN> "result" / { resultP }                        { addSpan TResult }
<0> "recursive"                                   { toSC 0 >> addSpan TRecursive }
<scN> "recursive" / { typeSpecP }                { toSC 0 >> addSpan TRecursive }
<0> "subroutine"                                  { addSpan TSubroutine }
<0> "end"\ *"subroutine"                          { addSpan TEndSubroutine }
<0> "block"\ *"data"                              { addSpan TBlockData }
<0> "end"\ *"block"\ *"data"                      { addSpan TEndBlockData }
<0> "module"                                      { addSpan TModule }
<0> "end"\ *"module"                              { addSpan TEndModule }
<0> "contains"                                    { addSpan TContains }
<0> "use"                                         { addSpan TUse }
<scN> "only" / { useStP }                           { addSpan TOnly }
<0> "interface"                                   { addSpan TInterface }
<0> "end"\ *"interface"                           { addSpan TEndInterface }
<scN> "procedure" / { moduleStP }                   { addSpan TProcedure }
<scN> "assignment" / { genericSpecP }               { addSpan TAssignment }
<scN> "operator" / { genericSpecP }                 { addSpan TOperator }
<0,scI> "call"                                      { addSpan TCall }
<0,scI> "return"                                    { addSpan TReturn }

-- Type def related
<0> "type"                                        { addSpan TType }
<0> "end"\ *"type"                                { addSpan TEndType }
<0> "sequence"                                    { addSpan TSequence }

-- Intrinsic types
<0> "integer"                                         { addSpan TInteger }
<0> "real"                                            { addSpan TReal }
<0> "double"\ *"precision"                            { addSpan TDoublePrecision }
<0> "logical"                                         { addSpan TLogical }
<0> "character"                                      { addSpan TCharacter }
<0> "complex"                                         { addSpan TComplex }

-- Selector
"kind"                                            { addSpan TKind }
"len"                                             { addSpan TLen }

-- Attributes
<0> "public"                                    { addSpan TPublic }
<scN> "public" / { attributeP }                                  { addSpan TPublic }
<0> "private"                                   { addSpan TPrivate }
<scN> "private" / { attributeP }                                  { addSpan TPrivate }
<0> "parameter"                                 { addSpan TParameter }
<scN> "parameter" / { attributeP }                                 { addSpan TParameter }
<0> "allocatable"                               { addSpan TAllocatable }
<scN> "allocatable" / { attributeP }                               { addSpan TAllocatable }
<0> "dimension"                                 { addSpan TDimension }
<scN> "dimension" / { attributeP }                                 { addSpan TDimension }
<0> "external"                                  { addSpan TExternal }
<scN> "external" / { attributeP }                                  { addSpan TExternal }
<0> "intent"                                    { addSpan TIntent }
<scN> "intent" / { attributeP }                                    { addSpan TIntent }
<0> "intrinsic"                                 { addSpan TIntrinsic }
<scN> "intrinsic" / { attributeP }                                 { addSpan TIntrinsic }
<0> "optional"                                  { addSpan TOptional }
<scN> "optional" / { attributeP }                                  { addSpan TOptional }
<0> "pointer"                                   { addSpan TPointer }
<scN> "pointer" / { attributeP }                                   { addSpan TPointer }
<0> "save"                                      { addSpan TSave }
<scN> "save" / { attributeP }                                      { addSpan TSave }
<0> "target"                                    { addSpan TTarget }
<scN> "target" / { attributeP }                                    { addSpan TTarget }

-- Attribute values
<scN> "in"\ *"out" / { followsIntentP }             { addSpan TInOut }
<scN> "in" / { followsIntentP }                     { addSpan TIn }
<scN> "out" / { followsIntentP }                    { addSpan TOut }

-- Control flow
<0> "do"                                          { addSpan TDo }
<0> "end"\ *"do"                                  { addSpan TEndDo }
<0> "while"                                       { addSpan TWhile }
<0> "if"                                          { addSpan TIf }
<scN> "then" / { ifStP }                            { addSpan TThen }
<0> "else"                                        { addSpan TElse }
<0> "else"\ *"if"                                 { addSpan TElsif }
<0> "end"\ *"if"                                  { addSpan TEndIf }
<0> "select"\ *"case"                             { addSpan TSelectCase }
<0> "case"                                        { addSpan TCase }
<0> "end"\ *"select"                              { addSpan TEndSelect }
<scN> "default" / { caseStP }                       { addSpan TDefault }
<0,scI> "cycle"                                     { addSpan TCycle }
<0,scI> "exit"                                      { addSpan TExit }
<0,scI> "go"\ *"to"                                 { addSpan TGoto }
<0,scI> "assign"                                    { addSpan TAssign }
<scN> "to" / { assignStP }                          { addSpan TTo }
<0,scI> "continue"                                  { addSpan TContinue }
<0,scI> "stop"                                      { addSpan TStop }
<0,scI> "pause"                                     { addSpan TPause }

-- Where construct
<0,scI> "where"                                     { addSpan TWhere }
<0> "elsewhere"                                   { addSpan TElsewhere }
<0> "end"\ *"where"                               { addSpan TEndWhere }

-- Beginning keyword
<0> "data"                                        { addSpan TData }
<0,scI> "allocate"                                  { addSpan TAllocate }
<0,scI> "deallocate"                                { addSpan TDeallocate }
<0,scI> "nullify"                                   { addSpan TNullify }
<0> "namelist"                                    { addSpan TNamelist }
<0> "implicit"                                    { addSpan TImplicit }
<0> "equivalence"                                 { addSpan TEquivalence }
<0> "common"                                      { addSpan TCommon }
<0> "end"                                         { addSpan TEnd }

<scN> "none" / { implicitStP }                      { addSpan TNone }

-- I/O
<0,scI> "open"                                      { addSpan TOpen }
<0,scI> "close"                                     { addSpan TClose }
<0,scI> "read"                                      { addSpan TRead }
<0,scI> "write"                                     { addSpan TWrite }
<0,scI> "print"                                     { addSpan TPrint }
<0,scI> "backspace"                                 { addSpan TBackspace }
<0,scI> "rewind"                                    { addSpan TRewind }
<0,scI> "inquire"                                   { addSpan TInquire }
<0,scI> "end"\ *"file"                              { addSpan TEndfile }

-- Literals
<0> @label                                        { addSpanAndMatch TLabel }
<scN> @intLiteralConst                              { addSpanAndMatch TIntegerLiteral  }
<scN> @bozLiteralConst                              { addSpanAndMatch TBozLiteral  }

<scN> @realLiteral                                  { addSpanAndMatch TRealLiteral }
<scN> @altRealLiteral / { notPrecedingDotP }        { addSpanAndMatch TRealLiteral }

<scN,scC> @characterLiteralBeg                        { lexCharacter }

<scN> @logicalLiteral                               { addSpanAndMatch TLogicalLiteral }

-- Operators
<scN> "**"                                          { addSpan TOpExp }
<scN> "+"                                           { addSpan TOpPlus }
<scN> "-"                                           { addSpan TOpMinus }
<scN> "*"                                           { addSpan TStar }
<scN> "/"                                           { addSpan TSlash }
<scN> ".or."                                        { addSpan TOpOr }
<scN> ".and."                                       { addSpan TOpAnd }
<scN> ".not."                                       { addSpan TOpNot }
<scN> ".eqv."                                       { addSpan TOpEquivalent }
<scN> ".neqv."                                      { addSpan TOpNotEquivalent }
<scN> (".eq."|"==")                                 { addSpan TOpEQ }
<scN> (".ne."|"/=")                                 { addSpan TOpNE }
<scN> (".lt."|"<=")                                 { addSpan TOpLT }
<scN> (".le."|"<=")                                 { addSpan TOpLE }
<scN> (".gt."|">=")                                 { addSpan TOpGT }
<scN> (".ge."|">=")                                 { addSpan TOpGE }
<scN> "." $letter+ "."                              { addSpanAndMatch TOpCustom }

<scN> @name                                         { addSpanAndMatch TId }

{

--------------------------------------------------------------------------------
-- Predicated lexer helpers
--------------------------------------------------------------------------------

partOfExpOrPointerAssignmentP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
partOfExpOrPointerAssignmentP fv _ _ ai = evalParse (lexerM $ f False 0) ps
  where
    ps = ParseState
      { psAlexInput = ai { aiStartCode = StartCode scN Return }
      , psVersion = fv
      , psFilename = "<unknown>"
      , psParanthesesCount = 0 }
    f leftParSeen parCount maybeToken
      | not leftParSeen =
        case maybeToken of
          Just TNewline{} -> return False
          Just TEOF{} -> return False
          Just TArrow{} -> return True
          Just TOpAssign{} -> return True
          Just TLeftPar{} -> lexerM $ f True 1
          _ -> return False
      | parCount == 0 =
        case maybeToken of
          Just (TOpAssign _) -> return True
          Just (TArrow _) -> return True
          _ -> return False
      | parCount > 0 =
        case maybeToken of
          Just TNewline{} -> return False
          Just TEOF{} -> return False
          Just TLeftPar{} -> lexerM $ f True (parCount + 1)
          Just TRightPar{} -> lexerM $ f True (parCount - 1)
          _ -> lexerM $ f True parCount
      | otherwise =
        error "Error while executing part of expression assignment predicate."

attributeP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
attributeP _ _ _ ai =  followsComma && precedesDoubleColon && startsWithTypeSpec
  where
    precedesDoubleColon = not . flip seenConstr ai . fillConstr $ TDoubleColon
    followsComma
      | Just TComma{} <- aiPreviousToken ai = True
      | otherwise = False
    startsWithTypeSpec
      | (token:_) <- prevTokens =
        isTypeSpec token || fillConstr TType == toConstr token
      | otherwise = False
    prevTokens = reverse . aiPreviousTokensInLine $ ai

constructNameP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
constructNameP fv _ _ ai =
  case nextTokenConstr fv ai of
    Just constr -> constr == fillConstr TColon
    _ -> False

genericSpecP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
genericSpecP _ _ _ ai = Just True == do
  constr <- prevTokenConstr ai
  if constr `elem` fmap fillConstr [ TInterface, TPublic, TPrivate ]
  then return True
  else if constr `elem` fmap fillConstr [ TComma, TDoubleColon ]
  then return $ seenConstr (fillConstr TPublic) ai || seenConstr (fillConstr TPrivate) ai
  else Nothing

typeSpecP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
typeSpecP _ _ _ ai
  | (prevToken:_) <- prevTokens
  , isTypeSpec prevToken = True
  | otherwise = isTypeSpecImmediatelyBefore $ reverse prevTokens
  where
    isTypeSpecImmediatelyBefore tokens@(x:xs)
      | isTypeSpec tokens = True
      | otherwise = isTypeSpecImmediatelyBefore xs
    isTypeSpecImmediatelyBefore [] = False
    prevTokens = aiPreviousTokensInLine ai

resultP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
resultP _ _ _ ai =
    (flip seenConstr ai . fillConstr $ TFunction) &&
    prevTokenConstr ai == (Just $ fillConstr TRightPar)

notPrecedingDotP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
notPrecedingDotP fv ai _ _ =
  case nextTokenConstr fv ai of
    Just constr -> not $ constr `elem` dotConstructors
    Nothing -> True
  where
    dotConstructors =
      fillConstr <$>
        [ TOpOr, TOpAnd, TOpNot, TOpEquivalent, TOpNotEquivalent
        , TOpEQ, TOpNE, TOpLT, TOpLE, TOpGT
        , TOpGE, flip TOpCustom undefined ]

followsIntentP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
followsIntentP _ _ _ ai =
  (map toConstr . take 2 . aiPreviousTokensInLine) ai ==
  map fillConstr [ TLeftPar, TIntent ]

useStP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
useStP _ _ _ ai = seenConstr (toConstr $ TUse undefined) ai

moduleStP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
moduleStP _ _ _ ai = prevTokenConstr ai == (Just $ fillConstr TModule)

ifStP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
ifStP _ _ _ ai = seenConstr (fillConstr TIf) ai

caseStP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
caseStP _ _ _ ai = prevTokenConstr ai == (Just $ fillConstr TCase)

assignStP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
assignStP _ _ _ ai = seenConstr (fillConstr TAssign) ai

implicitStP :: FortranVersion -> AlexInput -> Int -> AlexInput -> Bool
implicitStP _ _ _ ai = prevTokenConstr ai == (Just $ fillConstr TImplicit)

prevTokenConstr :: AlexInput -> Maybe Constr
prevTokenConstr ai = toConstr <$> aiPreviousToken ai

nextTokenConstr :: FortranVersion -> AlexInput -> Maybe Constr
nextTokenConstr fv ai = do
    token <- evalParse lexer' parseState
    case token of
      TNewline{} -> return $ toConstr token
      _ -> Nothing
  where
    parseState = ParseState
      { psAlexInput = ai
      , psParanthesesCount = 0
      , psVersion = fv
      , psFilename = "<unknown>" }

seenConstr :: Constr -> AlexInput -> Bool
seenConstr candidateConstr ai =
  candidateConstr `elem` (toConstr <$> aiPreviousTokensInLine ai)

fillConstr = toConstr . ($ undefined)

--------------------------------------------------------------------------------
-- Lexer helpers
--------------------------------------------------------------------------------

addSpan :: (SrcSpan -> Token) -> LexAction (Maybe Token)
addSpan cons = do
  s <- getLexemeSpan
  return $ Just $ cons s

addSpanAndMatch :: (SrcSpan -> String -> Token) -> LexAction (Maybe Token)
addSpanAndMatch cons = do
  s <- getLexemeSpan
  m <- getMatch
  return $ Just $ cons s m

getLexeme :: LexAction Lexeme
getLexeme = do
  ai <- getAlex
  return $ aiLexeme ai

putLexeme :: Lexeme -> LexAction ()
putLexeme lexeme = do
  ai <- getAlex
  putAlex $ ai { aiLexeme = lexeme }

resetLexeme :: LexAction ()
resetLexeme = putLexeme initLexeme

getMatch :: LexAction String
getMatch = do
  lexeme <- getLexeme
  return $ (reverse . lexemeMatch) lexeme

putMatch :: String -> LexAction ()
putMatch newMatch = do
  lexeme <- getLexeme
  putLexeme $ lexeme { lexemeMatch = reverse newMatch }

instance Spanned Lexeme where
  getSpan lexeme =
    let ms = lexemeStart lexeme
        me = lexemeEnd lexeme in
      SrcSpan (fromJust ms) (fromJust me)
  setSpan _ = error "Lexeme span cannot be set."

updatePreviousToken :: Maybe Token -> LexAction ()
updatePreviousToken maybeToken = do
  ai <- getAlex
  putAlex $ ai { aiPreviousToken = maybeToken }

addToPreviousTokensInLine :: Token -> LexAction ()
addToPreviousTokensInLine token = do
  ai <- getAlex
  putAlex $
    case token of
      TNewline _ -> updatePrevTokens ai [ ]
      t -> updatePrevTokens ai $ t : aiPreviousTokensInLine ai
  where
    updatePrevTokens ai tokens = ai { aiPreviousTokensInLine = tokens }

checkPreviousTokensInLine :: (Token -> Bool) -> AlexInput -> Bool
checkPreviousTokensInLine prop ai = any prop $ aiPreviousTokensInLine ai

getLexemeSpan :: LexAction SrcSpan
getLexemeSpan = do
  lexeme <- getLexeme
  return $ getSpan lexeme

-- Automata for character literal parsing is given below. Wherever it says '
-- you can replace ", whichever is used depends on what the first matched
-- character is and they are dual in their nature.
--
--      else
--       +-+
--       | v
--       +-+  Nothing  +-+
-- +---> |0|---------->|3|
--   +-> +-+           +-+
--   |    |
-- ' |    | '
--   |    v
--   |   +-+  Nothing  +-+
--   +---|1|---------->|2|
--       +-+           +-+
--        |             ^
--        +-------------+
--             else
--
-- For more information please refer to Fortran 90 standard's section related
-- to character constants.
lexCharacter :: LexAction (Maybe Token)
lexCharacter = do
    alex <- getAlex
    putAlex $ alex { aiStartCode = StartCode scC Stable }
    match <- getMatch
    let boundaryMarker = last match
    _lexChar 0 boundaryMarker
  where
    _lexChar 0 bm = do
      alex <- getAlex
      case alexGetByte alex of
        Just (_, newAlex) -> do
          putAlex newAlex
          m <- getMatch
          if last m == bm
          then _lexChar 1 bm
          else _lexChar 0 bm
        Nothing -> fail "Unmatched character literal."
    _lexChar 1 bm = do
      alex <- getAlex
      case alexGetByte alex of
        Just (_, newAlex) -> do
          let m = lexemeMatch . aiLexeme $ newAlex
          if head m == bm
          then do
            putAlex newAlex
            putMatch . reverse . tail $ m
            _lexChar 0 bm
          else _lexChar 2 bm
        Nothing -> _lexChar 2 bm
    _lexChar 2 _ = do
      alex <- getAlex
      putAlex $ alex { aiStartCode = StartCode scN Return }
      match <- getMatch
      putMatch . init . tail $ match
      addSpanAndMatch TString

lexComment :: LexAction (Maybe Token)
lexComment = do
  alex <- getAlex
  case alexGetByte alex of
    Just (_, ai) ->
      if currentChar ai == '\n'
      then addSpanAndMatch TComment
      else putAlex ai >> lexComment
    Nothing -> addSpanAndMatch TComment

toSC :: Int -> LexAction ()
toSC startCode = do
  alex <- getAlex
  putAlex $ alex { aiStartCode = StartCode startCode Return }

stabiliseStartCode :: LexAction ()
stabiliseStartCode = do
  alex <- getAlex
  let sc = aiStartCode alex
  putAlex $ alex { aiStartCode = sc { scStatus = Stable } }

normaliseStartCode :: LexAction ()
normaliseStartCode = do
  alex <- getAlex
  let startCode = aiStartCode alex
  case scStatus startCode of
    Return -> putAlex $ alex { aiStartCode = StartCode scN Stable }
    Stable -> return ()

--------------------------------------------------------------------------------
-- AlexInput & related definitions
--------------------------------------------------------------------------------

data Lexeme = Lexeme
  { lexemeMatch :: String
  , lexemeStart :: Maybe Position
  , lexemeEnd   :: Maybe Position
  } deriving (Show)

initLexeme :: Lexeme
initLexeme = Lexeme
  { lexemeMatch = ""
  , lexemeStart = Nothing
  , lexemeEnd   = Nothing }

data StartCodeStatus = Return | Stable deriving (Show)

data StartCode = StartCode
  { scActual :: Int
  , scStatus :: StartCodeStatus }
  deriving (Show)

data AlexInput = AlexInput
  { aiSourceInput               :: String
  , aiPosition                  :: Position
  , aiPreviousChar              :: Char
  , aiLexeme                    :: Lexeme
  , aiStartCode                 :: StartCode
  , aiPreviousToken             :: Maybe Token
  , aiPreviousTokensInLine      :: [ Token ]
  } deriving (Show)

instance Loc AlexInput where
  getPos = aiPosition

instance LastToken AlexInput Token where
  getLastToken = aiPreviousToken

type LexAction a = Parse AlexInput Token a

vanillaAlexInput :: AlexInput
vanillaAlexInput = AlexInput
  { aiSourceInput = ""
  , aiPosition = initPosition
  , aiPreviousChar = '\n'
  , aiLexeme = initLexeme
  , aiStartCode = StartCode 0 Return
  , aiPreviousToken = Nothing
  , aiPreviousTokensInLine = [ ] }

updateLexeme :: Char -> Position -> AlexInput -> AlexInput
updateLexeme char p ai =
  let lexeme = aiLexeme ai
      match = lexemeMatch lexeme
      newMatch = char : match
      start = lexemeStart lexeme
      newStart = if isNothing start then Just p else start
      newEnd = Just p in
    ai { aiLexeme = Lexeme newMatch newStart newEnd }

--------------------------------------------------------------------------------
-- Definitions needed for alexScanUser
--------------------------------------------------------------------------------

data Move = Continuation | Char | Newline

alexGetByte :: AlexInput -> Maybe (Word8, AlexInput)
alexGetByte ai
  -- When all characters are already read
  | posAbsoluteOffset _position == (toInteger . length . aiSourceInput) ai = Nothing
  -- Skip the continuation line altogether
  | isContinuation ai = alexGetByte . skipContinuation $ ai
  -- Read genuine character and advance. Also covers white sensitivity.
  | otherwise =
      Just ( fromIntegral . fromEnum $ _curChar
           , updateLexeme _curChar _position
               ai
               { aiPosition =
                   case _curChar of
                     '\n'  -> advance Newline _position
                     _     -> advance Char _position
               , aiPreviousChar = _curChar })
  where
    _curChar = currentChar ai
    _position = aiPosition ai

alexInputPrevChar :: AlexInput -> Char
alexInputPrevChar ai = aiPreviousChar ai

takeNChars :: Integer -> AlexInput -> String
takeNChars n ai =
  take (fromIntegral n) . drop (fromIntegral _dropN) $ aiSourceInput ai
  where
    _dropN = posAbsoluteOffset . aiPosition $ ai

currentChar :: AlexInput -> Char
currentChar ai
  -- case sensitivity matters only in character literals
  | (scActual . aiStartCode) ai == scC = _currentChar
  | otherwise = toLower _currentChar
  where
  _currentChar = head . takeNChars 1 $ ai

alexAdvance :: AlexInput -> AlexInput
alexAdvance ai =
  case alexGetByte ai of
    Just (_,ai') -> ai'
    Nothing -> error "File has prematurely ended."

isContinuation :: AlexInput -> Bool
isContinuation ai = (scActual . aiStartCode) ai /= scC && _isContinuation ai 0
  where
    _isContinuation ai 0 =
      if currentChar ai == '&'
      then _isContinuation (alexAdvance ai) 1
      else False
    _isContinuation ai 1 =
      case currentChar ai of
        ' ' -> _isContinuation (alexAdvance ai) 1
        '\t' -> _isContinuation (alexAdvance ai) 1
        '\r' -> _isContinuation (alexAdvance ai) 1
        '!' -> True
        '\n' -> True
        _ -> False

-- Here's the skip continuation automaton:
--
--              white     white,\n
--               +-+        +-+
--               | v        | v        +---+
--     +-+   &   +-+   \n   +-+   &    |---|
-- +-->|0|------>|1|------->|3|------->||4||
--     +-+       +-+        +-+----+   |---|
--                |          ^     |   +---+
--                |!         |     |
--                v          |     |else
--            +->+-+         |     v
--        else|  |2|---------+   +---+
--            +--+-+             |---|
--                               ||5||
--                               |---|
--                               +---+
--
-- For more information refer to Fortran 90 standard.
-- This version is more permissive than the specification
-- as it allows empty lines to be used between continuations.
skipContinuation :: AlexInput -> AlexInput
skipContinuation ai = _skipCont ai 0
  where
    _skipCont ai 0 =
      if currentChar ai == '&'
      then _skipCont (alexAdvance ai) 1
      else error "This case is excluded by isContinuation."
    _skipCont ai 1 =
      let _curChar = currentChar ai in
        if _curChar `elem` [' ', '\t', '\r']
        then _skipCont (alexAdvance ai) 1
        else if _curChar == '!'
        then _skipCont (alexAdvance ai) 2
        else if _curChar == '\n'
        then _skipCont (alexAdvance ai) 3
        else
          error $
            join [ "Did not expect non-blank/non-comment character after "
                 , "continuation symbol (&)." ]
    _skipCont ai 2 =
      if currentChar ai == '\n'
      then _skipCont (alexAdvance ai) 3
      else _skipCont (alexAdvance ai) 2
    _skipCont ai 3 =
      let _curChar = currentChar ai in
        if _curChar `elem` [' ', '\t', '\r', '\n']
        then _skipCont (alexAdvance ai) 3
        else if _curChar == '!'
        then _skipCont (alexAdvance ai) 2
        else if _curChar == '&'
        -- This state accepts as if there were no spaces between the broken
        -- line and whatever comes after second &. This is implicitly state (4)
        then alexAdvance ai
        -- This state accepts but the broken line delimits the previous token.
        -- This is implicitly state (5). To achieve this, it returns the
        -- previous ai, which either has whitespace or newline, so it will
        -- nicely delimit.
        else ai

advance :: Move -> Position -> Position
advance move position =
  case move of
    Newline ->
      position
        { posAbsoluteOffset = _absl + 1 , posColumn = 1 , posLine = _line + 1 }
    Char ->
      position { posAbsoluteOffset = _absl + 1 , posColumn = _col + 1 }
  where
    _col = posColumn position
    _line = posLine position
    _absl = posAbsoluteOffset position

--------------------------------------------------------------------------------
-- Lexer definition
--------------------------------------------------------------------------------

lexer :: (Token -> LexAction a) -> LexAction a
lexer cont = do
   mToken <- lexer'
   case mToken of
     Just token -> cont token
     Nothing -> fail "Unrecognised token. "

lexerM :: ((Maybe Token) -> LexAction a) -> LexAction a
lexerM cont = lexer' >>= \mToken -> cont mToken

lexer' :: LexAction (Maybe Token)
lexer' = do
  resetLexeme
  alex <- getAlex
  let startCode = scActual . aiStartCode $ alex
  normaliseStartCode
  newAlex <- getAlex
  version <- getVersion
  case alexScanUser version newAlex startCode of
    AlexEOF -> return $ Just $ TEOF $ SrcSpan (getPos alex) (getPos alex)
    AlexError _ -> return Nothing
    AlexSkip newAlex _ -> do
      putAlex $ newAlex { aiStartCode = StartCode startCode Return }
      lexer'
    AlexToken newAlex _ action -> do
      putAlex newAlex
      maybeToken <- action
      case maybeToken of
        Just token -> do
          updatePreviousToken maybeToken
          addToPreviousTokensInLine token
          return maybeToken
        Nothing -> lexer'

alexScanUser :: FortranVersion -> AlexInput -> Int -> AlexReturn (LexAction (Maybe Token))

--------------------------------------------------------------------------------
-- Tokens
--------------------------------------------------------------------------------

data Token =
    TId                 SrcSpan String
  | TComment            SrcSpan String
  | TString             SrcSpan String
  | TLabel              SrcSpan String
  | TIntegerLiteral     SrcSpan String
  | TRealLiteral        SrcSpan String
  | TBozLiteral         SrcSpan String
  | TComma              SrcSpan
  | TSemiColon          SrcSpan
  | TColon              SrcSpan
  | TDoubleColon        SrcSpan
  | TOpAssign           SrcSpan
  | TArrow              SrcSpan
  | TPercent            SrcSpan
  | TLeftPar            SrcSpan
  | TRightPar           SrcSpan
  -- Mainly operators
  | TOpCustom           SrcSpan String
  | TOpExp              SrcSpan
  | TOpPlus             SrcSpan
  | TOpMinus            SrcSpan
  | TStar               SrcSpan
  | TSlash              SrcSpan
  | TOpOr               SrcSpan
  | TOpAnd              SrcSpan
  | TOpNot              SrcSpan
  | TOpEquivalent       SrcSpan
  | TOpNotEquivalent    SrcSpan
  | TOpLT               SrcSpan
  | TOpLE               SrcSpan
  | TOpEQ               SrcSpan
  | TOpNE               SrcSpan
  | TOpGT               SrcSpan
  | TOpGE               SrcSpan
  | TLogicalLiteral     SrcSpan String
  -- Keywords
  -- Program unit related
  | TProgram            SrcSpan
  | TEndProgram         SrcSpan
  | TFunction           SrcSpan
  | TEndFunction        SrcSpan
  | TResult             SrcSpan
  | TRecursive          SrcSpan
  | TSubroutine         SrcSpan
  | TEndSubroutine      SrcSpan
  | TBlockData          SrcSpan
  | TEndBlockData       SrcSpan
  | TModule             SrcSpan
  | TEndModule          SrcSpan
  | TContains           SrcSpan
  | TUse                SrcSpan
  | TOnly               SrcSpan
  | TInterface          SrcSpan
  | TEndInterface       SrcSpan
  | TProcedure          SrcSpan
  | TAssignment         SrcSpan
  | TOperator           SrcSpan
  | TCall               SrcSpan
  | TReturn             SrcSpan
  -- Attributes
  | TPublic             SrcSpan
  | TPrivate            SrcSpan
  | TParameter          SrcSpan
  | TAllocatable        SrcSpan
  | TDimension          SrcSpan
  | TExternal           SrcSpan
  | TIntent             SrcSpan
  | TIntrinsic          SrcSpan
  | TOptional           SrcSpan
  | TPointer            SrcSpan
  | TSave               SrcSpan
  | TTarget             SrcSpan
  -- Attribute values
  | TIn                 SrcSpan
  | TOut                SrcSpan
  | TInOut              SrcSpan
  -- Beginning keyword
  | TData               SrcSpan
  | TNamelist           SrcSpan
  | TImplicit           SrcSpan
  | TEquivalence        SrcSpan
  | TCommon             SrcSpan
  | TAllocate           SrcSpan
  | TDeallocate         SrcSpan
  | TNullify            SrcSpan
  -- Misc
  | TNone               SrcSpan
  -- Control flow
  | TGoto               SrcSpan
  | TAssign             SrcSpan
  | TTo                 SrcSpan
  | TContinue           SrcSpan
  | TStop               SrcSpan
  | TPause              SrcSpan
  | TDo                 SrcSpan
  | TEndDo              SrcSpan
  | TWhile              SrcSpan
  | TIf                 SrcSpan
  | TThen               SrcSpan
  | TElse               SrcSpan
  | TElsif              SrcSpan
  | TEndIf              SrcSpan
  | TCase               SrcSpan
  | TSelectCase         SrcSpan
  | TEndSelect          SrcSpan
  | TDefault            SrcSpan
  | TCycle              SrcSpan
  | TExit              SrcSpan
  -- Where construct
  | TWhere              SrcSpan
  | TElsewhere          SrcSpan
  | TEndWhere           SrcSpan
  -- Type related
  | TType               SrcSpan
  | TEndType            SrcSpan
  | TSequence           SrcSpan
  -- Selector
  | TKind               SrcSpan
  | TLen                SrcSpan
  -- Intrinsic types
  | TInteger            SrcSpan
  | TReal               SrcSpan
  | TDoublePrecision    SrcSpan
  | TLogical            SrcSpan
  | TCharacter          SrcSpan
  | TComplex            SrcSpan
  -- I/O
  | TOpen               SrcSpan
  | TClose              SrcSpan
  | TRead               SrcSpan
  | TWrite              SrcSpan
  | TPrint              SrcSpan
  | TBackspace          SrcSpan
  | TRewind             SrcSpan
  | TInquire            SrcSpan
  | TEndfile            SrcSpan
  -- Etc.
  | TEnd                SrcSpan
  | TNewline            SrcSpan
  | TEOF                SrcSpan
  deriving (Eq, Show, Data, Typeable, Generic)

instance FirstParameter Token SrcSpan
instance FirstParameter Token SrcSpan => Spanned Token where
  getSpan = getFirstParameter
  setSpan = setFirstParameter

instance Tok Token where
  eofToken TEOF{} = True
  eofToken _ = False

class TypeSpec a where
  isTypeSpec :: a -> Bool

instance TypeSpec Token where
  isTypeSpec TInteger{} = True
  isTypeSpec TReal{} = True
  isTypeSpec TDoublePrecision{} = True
  isTypeSpec TLogical{} = True
  isTypeSpec TCharacter{} = True
  isTypeSpec TComplex{} = True
  isTypeSpec _ = False

instance TypeSpec [ Token ] where
  isTypeSpec tokens
    | [ TType{}, TLeftPar{}, _, TRightPar{} ] <- tokens = True
    -- This is an approximation but should hold for almost all legal programs.
    | (typeToken:TLeftPar{}:rest) <- tokens =
      isTypeSpec typeToken &&
      case last rest of
        TRightPar{} -> True
        _ -> False
    | (TCharacter{}:TStar{}:rest) <- tokens =
      case rest of
        [ TIntegerLiteral{} ] -> True
        (TLeftPar{}:rest') | TRightPar{} <- last rest' -> True
        _ -> False
    | otherwise = False

--------------------------------------------------------------------------------
-- Functions to help testing & output
--------------------------------------------------------------------------------

initParseState :: String -> FortranVersion -> String -> ParseState AlexInput
initParseState srcInput fortranVersion filename =
  _vanillaParseState { psAlexInput = vanillaAlexInput { aiSourceInput = srcInput } }
  where
    _vanillaParseState = ParseState
      { psAlexInput = undefined
      , psVersion = fortranVersion
      , psFilename = filename
      , psParanthesesCount = 0 }

collectFreeTokens :: FortranVersion -> String -> Maybe [Token]
collectFreeTokens version srcInput =
    collectTokens lexer' $ initParseState srcInput version "<unknown>"

}
