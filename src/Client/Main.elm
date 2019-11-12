module Client.Main exposing (main)

import Browser
import Html exposing (Html)


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = init
        , subscriptions = subscriptions
        , update = update
        }


type alias Model =
    {}

init : () -> ( Model, Cmd Msg )
init _ =
    ( {}, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )


view : Model -> Html Msg
view _ =
    Html.text "Client"