module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Time
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
    , userChoices : UserChoices
    , userName : String
    , userState : UserState
    , startingCounterNumber : Int
    , players : List Player
    , opponent : Opponent
    , randomInt : Int
    }


type Opponent
    = Man
    | Machine


type alias Player =
    ( String, UserChoices )


type UserChoices
    = Scissors
    | Rock
    | Paper


type UserState
    = NewUser
    | GamePending
    | NotChoosen
    | ChoosingDone
    | TimerDone


type alias BackendModel =
    { players : List Player
    }


type FrontendMsg
    = UrlClicked UrlRequest
    | UrlChanged Url
    | ChooseSign UserChoices
    | StartGame
    | Tick Time.Posix
    | StoreName String
    | SendUserName String
    | InitiateReset
    | ChooseOpponent Opponent
    | TakeRandom Int


type ToBackend
    = UserJoined String Opponent Int
    | ShouldStartGame Int
    | TimeIsUp Player
    | ResetBeModel


type BackendMsg
    = NoOp


type ToFrontend
    = UserGreeting String
    | UserBecameClient Player
    | BeOrdersStart
    | UpdatePlayers (List Player)
    | RestGame
