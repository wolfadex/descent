module Ui exposing (button, card, spacerHorizontal, spacerVertical)

import Element exposing (Attribute, Element, Length)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Ui.Color as Color


card : List (Attribute msg)
card =
    [ Border.shadow
        { blur = 10
        , color = Element.rgba 0 0 0 0.05
        , offset = ( 0, 2 )
        , size = 1
        }
    , Border.width 1
    , Border.color Color.lightGray
    , Border.rounded 4
    , Element.alignTop
    , Element.padding 20
    , Element.height Element.shrink
    ]


spacerVertical : Length -> Element msg
spacerVertical length =
    Element.el [ Element.height length ] Element.none


spacerHorizontal : Length -> Element msg
spacerHorizontal length =
    Element.el [ Element.width length ] Element.none


button : List (Attribute msg) -> { onPress : Maybe msg, label : Element msg } -> Element msg
button attributes =
    Input.button
        (card
            ++ [ Font.center
               , Background.color <| Color.lightGray
               , Element.mouseOver
                    [ Border.color <| Color.gray
                    ]
               , Element.paddingXY 16 12
               ]
            ++ attributes
        )
