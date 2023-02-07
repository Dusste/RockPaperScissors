module Frontend exposing (..)

-- import Html exposing (..)
--import Html exposing (br, button, form, h1, h2, input, li, p, ul)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events
import Element.Font as Font exposing (center)
import Element.Input as Input
import Lamdera exposing (sendToBackend)
import Process
import Random
import Task
import Time
import Types exposing (..)
import Url


type alias Model =
    FrontendModel


app =
    Lamdera.frontend
        { init = init
        , onUrlRequest = UrlClicked
        , onUrlChange = UrlChanged
        , update = update
        , updateFromBackend = updateFromBackend
        , subscriptions =
            \m ->
                case m.userState of
                    NotChoosen ->
                        Time.every 1000 Tick

                    _ ->
                        Sub.none
        , view = view
        }


init : Url.Url -> Nav.Key -> ( Model, Cmd FrontendMsg )
init url key =
    ( { key = key
      , userChoices = Scissors
      , userName = ""
      , userState = NewUser
      , startingCounterNumber = 5
      , players = []
      , opponent = Machine
      , randomInt = 1
      }
    , Random.generate TakeRandom (Random.int 1 3)
    )


update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
update msg model =
    case msg of
        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                External url ->
                    ( model
                    , Nav.load url
                    )

        UrlChanged _ ->
            ( model, Cmd.none )

        Tick _ ->
            let
                counterDone =
                    model.startingCounterNumber == 0
            in
            ( { model
                | startingCounterNumber =
                    if counterDone then
                        0

                    else
                        model.startingCounterNumber - 1
                , userState =
                    if counterDone then
                        TimerDone

                    else
                        NotChoosen
              }
            , if counterDone then
                sendToBackend <| TimeIsUp ( model.userName, model.userChoices )

              else
                Cmd.none
            )

        StartGame ->
            ( { model | userState = NotChoosen }, Cmd.none )

        ChooseSign choice ->
            ( { model | userChoices = choice }, Cmd.none )

        StoreName name ->
            ( { model | userName = name }, Cmd.none )

        SendUserName name ->
            let
                notValidName =
                    String.isEmpty name
            in
            ( { model
                | userState =
                    if notValidName then
                        NewUser

                    else
                        GamePending
              }
            , if notValidName then
                Cmd.none

              else
                sendToBackend <| UserJoined name model.opponent model.randomInt
            )

        ChooseOpponent opponentChoice ->
            ( { model | opponent = opponentChoice }, Cmd.none )

        InitiateReset ->
            ( model
            , sendToBackend ResetBeModel
            )

        TakeRandom num ->
            ( { model | randomInt = num }, Cmd.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        UserGreeting greeting ->
            ( { model | userName = greeting, userState = GamePending }, Cmd.none )

        UserBecameClient player ->
            ( { model | players = player :: model.players }
            , player
                :: model.players
                |> List.length
                |> ShouldStartGame
                |> sendToBackend
            )

        BeOrdersStart ->
            ( model
            , Process.sleep 4000
                |> Task.perform (\_ -> StartGame)
            )

        UpdatePlayers playersList ->
            ( { model | players = playersList }, Cmd.none )

        RestGame ->
            ( { model
                | userChoices = Scissors
                , userName = ""
                , userState = NewUser
                , startingCounterNumber = 5
                , players = []
                , opponent = Machine
              }
            , Cmd.none
            )


scaled : Int -> Float
scaled =
    Element.modular 16 1.25


view : Model -> Browser.Document FrontendMsg
view model =
    { title = ""
    , body =
        [ Element.layout [ Background.color <| rgb255 1 150 324, Font.color <| rgb255 255 255 255, paddingXY 0 180 ] <|
            Element.column [ centerX ]
                [ Element.paragraph [ Font.size <| Basics.round (scaled 5), paddingEach { top = 0, right = 0, left = 20, bottom = 30 } ] [ text "Dobrodošao u igru - Kamen Papir Makaze" ]
                , Element.column [ width fill, spacing 100, padding 40, center, Background.color <| rgba255 25 105 162 0.3, Border.rounded 3 ]
                    [ case model.userState of
                        NewUser ->
                            Element.column
                                [ spacing 20
                                , centerX
                                ]
                                [ Element.el []
                                    (Element.wrappedRow []
                                        [ Input.radio
                                            [ spacing 30
                                            , width Element.fill
                                            , Font.size <| Basics.round (scaled 4)
                                            ]
                                            { onChange = ChooseOpponent
                                            , label = Input.labelAbove [ Font.size <| Basics.round (scaled 4), center, Element.paddingXY 0 20 ] (text "Igram protiv")
                                            , selected = Just model.opponent
                                            , options =
                                                [ Input.optionWith Man (radioOption (Element.text "Čoveka"))
                                                , Input.optionWith Machine (radioOption (Element.text "Mašine"))
                                                ]
                                            }
                                        ]
                                    )
                                , Input.text
                                    [ padding 10
                                    , spacing 30
                                    , Font.color <| rgb255 92 99 118
                                    ]
                                    { onChange = \a -> StoreName a
                                    , label = Input.labelAbove [ Font.size <| Basics.round (scaled 4), paddingXY 0 12 ] (text "Upiši svoje ime")
                                    , text = model.userName
                                    , placeholder = Nothing
                                    }
                                , Input.button
                                    [ padding 10
                                    , spacing 0
                                    , centerX
                                    , Background.color <| rgb255 17 75 123
                                    , Border.rounded 3
                                    , mouseOver <| [ Background.color <| rgb255 17 60 110 ]
                                    ]
                                    { label = Element.text "Pošalji"
                                    , onPress = Just <| SendUserName model.userName
                                    }
                                ]

                        -- ]
                        GamePending ->
                            Element.column [ centerX, width <| fillPortion 500, center, spacing 50, Font.size <| Basics.round (scaled 4) ]
                                [ Element.paragraph [] [ text "Zdravo ", Element.el [ Font.color <| rgb255 255 255 1 ] (text model.userName) ]
                                , case model.opponent of
                                    Man ->
                                        Element.paragraph [] [ text "Čekamo sve učesnike da se priključe... Ako nisi, posalji ovaj link drugaru sa kojim želiš da igraš" ]

                                    Machine ->
                                        Element.paragraph [] [ text "" ]
                                , Element.paragraph [] <|
                                    let
                                        playersWithoutMe =
                                            List.filter
                                                (\( name, _ ) ->
                                                    not <| String.contains name model.userName
                                                )
                                                model.players
                                    in
                                    List.map
                                        (\( name, _ ) ->
                                            Element.el [ center, Font.color <| rgb255 255 255 1 ] (text name)
                                        )
                                        playersWithoutMe
                                , Element.paragraph [ center ]
                                    [ text <|
                                        if List.length model.players == 2 then
                                            "će igrati protiv tebe"

                                        else
                                            ""
                                    ]
                                ]

                        NotChoosen ->
                            Element.column [ centerX, width fill, center, Font.size <| Basics.round (scaled 3) ]
                                [ Element.paragraph [ center ] [ text <| model.userName ++ "," ]
                                , Element.wrappedRow [ centerX, paddingEach { top = 10, right = 0, left = 0, bottom = 50 } ]
                                    [ Input.radio
                                        [ paddingXY 0 50
                                        , spacing 20
                                        , width Element.fill
                                        ]
                                        { onChange = ChooseSign
                                        , label = Input.labelAbove [ Font.size <| Basics.round (scaled 4), center ] (text "izaberi svoj znak:")
                                        , selected = Just model.userChoices
                                        , options =
                                            [ Input.optionWith Rock (radioOption (Element.text "Kamen"))
                                            , Input.optionWith Scissors (radioOption (Element.text "Makaze"))
                                            , Input.optionWith Paper (radioOption (Element.text "Papir"))
                                            ]
                                        }
                                    ]
                                , Element.paragraph [ center ] [ text <| "Imate još: " ++ String.fromInt model.startingCounterNumber ++ " sekundi" ]
                                ]

                        -- TimerDone & ChoosingDone
                        _ ->
                            Element.column [ centerX, Font.size <| Basics.round (scaled 3), spacing 20, center ]
                                [ Element.column [ width fill ]
                                    (List.map
                                        (\( name, choice ) ->
                                            Element.paragraph [ padding 10 ] [ text <| "Učesnik " ++ name ++ " je izabrao " ++ choiceToString choice ]
                                        )
                                        model.players
                                    )
                                , Element.paragraph [ center ]
                                    [ viewWinner
                                        model
                                    ]
                                ]
                    ]
                ]
        ]
    }


radioOption : Element msg -> Input.OptionState -> Element msg
radioOption optionLabel status =
    Element.wrappedRow
        [ Element.spacing 10
        , Element.width Element.shrink
        ]
        [ Element.el
            [ Element.width (Element.px 20)
            , Element.height (Element.px 20)
            , Border.width <|
                case status of
                    Input.Idle ->
                        2

                    Input.Focused ->
                        2

                    Input.Selected ->
                        10
            , Border.color <|
                case status of
                    Input.Idle ->
                        Element.rgb 1 1 1

                    Input.Focused ->
                        Element.rgb 1 1 1

                    Input.Selected ->
                        Element.rgb 1 1 1
            ]
            Element.none
        , Element.el [ Element.width Element.fill ] optionLabel
        ]


viewWinner : Model -> Element FrontendMsg
viewWinner model =
    Element.column [ width fill, centerX, padding 30, Font.size <| Basics.round (scaled 4), spacing 30 ]
        [ Element.paragraph
            []
            [ case determineWinner model.players of
                Just ( winnerName, winnerChoice ) ->
                    text <| "Pobednik je " ++ winnerName ++ " sa izborom " ++ choiceToString winnerChoice ++ "! Čestitamo !"

                Nothing ->
                    text "Nema pobednika, izabrali ste isti znak"
            ]
        , Input.button
            [ padding 10
            , spacing 0
            , centerX
            , Background.color <| rgb255 17 75 123
            , Border.rounded 3
            , Font.size <| Basics.round (scaled 3)
            , mouseOver <| [ Background.color <| rgb255 17 60 110 ]
            ]
            { onPress = Just InitiateReset
            , label = Element.text "Igraj ponovo"
            }
        ]


determineWinner : List Player -> Maybe Player
determineWinner players =
    let
        ( _, listChoices ) =
            List.unzip players

        isSameChoice =
            checkIfSameChoice listChoices choiceToString

        sortedPlayers =
            List.sortWith
                (\( _, choiceA ) ( _, choiceB ) ->
                    compareChoices ( choiceA, choiceB )
                )
                players
    in
    case sortedPlayers of
        ( winnerName, winnerChoice ) :: _ ->
            if isSameChoice then
                Nothing

            else
                Just ( winnerName, winnerChoice )

        _ ->
            Nothing


checkIfSameChoice : List UserChoices -> (UserChoices -> String) -> Bool
checkIfSameChoice list func =
    case list of
        firstChoice :: secondChoice :: _ ->
            func firstChoice == func secondChoice

        _ ->
            False


choiceToString : UserChoices -> String
choiceToString choice =
    case choice of
        Scissors ->
            "Makaze"

        Rock ->
            "Kamen"

        Paper ->
            "Papir"


compareChoices : ( UserChoices, UserChoices ) -> Order
compareChoices tup =
    case tup of
        ( Scissors, Rock ) ->
            GT

        ( Rock, Paper ) ->
            GT

        ( Scissors, Paper ) ->
            LT

        ( Rock, Scissors ) ->
            LT

        ( Paper, Rock ) ->
            LT

        ( Paper, Scissors ) ->
            GT

        ( Scissors, Scissors ) ->
            EQ

        ( Rock, Rock ) ->
            EQ

        ( Paper, Paper ) ->
            EQ
