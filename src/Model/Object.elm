module Model.Object
    exposing
        ( Object
        , Category(..)
        , isDead
        , update
        , walls
        , mogee
        , isMogee
        , isScreen
        , isWall
        , collide
        , offset
        , invertScreen
        )

import Model.Direction as Direction exposing (Direction(..))
import Model.Mogee as Mogee exposing (Mogee)
import Model.Screen as Screen exposing (AnimationState(Moving), Screen)
import Time exposing (Time)


type Category
    = WallCategory
    | MogeeCategory Mogee
    | ScreenCategory Screen


type alias Keys =
    { x : Float
    , y : Float
    }


type alias Object =
    { number : Int
    , category : Category
    , velocity : ( Float, Float )
    , size : ( Float, Float )
    , position : ( Float, Float )
    }


offset : Direction -> Object -> Object
offset direction object =
    { object | position = Direction.offset ( 64, 64 ) object.position direction }


gravity : Float
gravity =
    0.0001


friction : Float
friction =
    0.001


jumpVelocity : Float
jumpVelocity =
    0.06


walkVelocity : Float
walkVelocity =
    0.03


screenVelocity : Float
screenVelocity =
    0.01


screen : Int -> Direction -> Direction -> ( Float, Float ) -> Object
screen number from to =
    Object
        number
        (ScreenCategory (Screen.screen from to))
        ( screenVelocity + 0.001 * toFloat number
        , screenVelocity + 0.001 * toFloat number
        )
        ( 64, 64 )


mogee : ( Float, Float ) -> Object
mogee =
    Object -1 (MogeeCategory Mogee.mogee) ( 0, 0 ) Mogee.size


size : Float
size =
    64


borderSize : Float
borderSize =
    1


wall : Int -> ( Float, Float ) -> ( Float, Float ) -> Object
wall number =
    Object number WallCategory ( 0, 0 )


walls : Direction -> Direction -> Int -> List Object
walls from to number =
    let
        corner =
            wall number ( borderSize, borderSize )

        horizontal =
            wall number ( size - 2 * borderSize, borderSize )

        vertical =
            wall number ( borderSize, size - 2 * borderSize )

        oppositeDir =
            Direction.opposite from
    in
        screen number from to ( 0, 0 )
            :: wall number ( 7, 2 ) ( 0, 11 )
            :: wall number ( 16, 2 ) ( 24, 11 )
            :: wall number ( 11, 2 ) ( 6, 27 )
            :: wall number ( 13, 2 ) ( 51, 27 )
            :: wall number ( 11, 2 ) ( 0, 43 )
            :: wall number ( 33, 2 ) ( 31, 43 )
            :: wall number ( 19, 2 ) ( 17, 58 )
            :: List.map
                corner
                [ ( 0, 0 )
                , ( size - borderSize, 0 )
                , ( size - borderSize, size - borderSize )
                , ( 0, size - borderSize )
                ]
            ++ (List.filter (\d -> d /= oppositeDir && d /= to) [ Left, Right, Top, Bottom ]
                    |> List.map
                        (\d ->
                            case d of
                                Left ->
                                    vertical ( 0, borderSize )

                                Right ->
                                    vertical ( size - borderSize, borderSize )

                                Top ->
                                    horizontal ( borderSize, 0 )

                                Bottom ->
                                    horizontal ( borderSize, size - borderSize )
                        )
               )


isMogee : Object -> Bool
isMogee obj =
    case obj.category of
        MogeeCategory _ ->
            True

        _ ->
            False


isWall : Object -> Bool
isWall obj =
    case obj.category of
        WallCategory ->
            True

        _ ->
            False


isScreen : Object -> Bool
isScreen obj =
    case obj.category of
        ScreenCategory _ ->
            True

        _ ->
            False


moveY : Time -> Float -> List Object -> Object -> Object
moveY dt dy walls object =
    let
        ( vx, vy ) =
            object.velocity

        ( x, y ) =
            object.position

        newVelocity =
            vy + gravity * dt

        deltaY =
            dt * (vy + newVelocity) * 0.5
    in
        List.foldl
            (\({ position, size } as wall) object ->
                if collide object wall then
                    if deltaY < 0 then
                        {- Hit the top wall -}
                        { object
                            | velocity = ( vx, 0 )
                            , position = ( x, Tuple.second position + Tuple.second size )
                        }
                    else
                        {- Hit the bottom wall -}
                        { object
                            | velocity =
                                ( vx
                                , if dy == 1 then
                                    -jumpVelocity
                                  else
                                    0
                                )
                            , position = ( x, Tuple.second position - Tuple.second object.size )
                        }
                else
                    object
            )
            { object
                | position = ( x, y + deltaY )
                , velocity = ( vx, newVelocity )
            }
            walls


moveX : Time -> Float -> List Object -> Object -> Object
moveX dt dx walls object =
    let
        ( vx, vy ) =
            object.velocity

        ( x, y ) =
            object.position

        newVelocity =
            if dx == 0 then
                if vx /= 0 then
                    let
                        new =
                            max (abs vx - friction * dt) 0
                    in
                        (vx / abs vx) * new
                else
                    0
            else
                dx * walkVelocity

        deltaX =
            dt * (vx + newVelocity) * 0.5
    in
        List.foldl
            (\({ position, size } as wall) object ->
                if collide object wall then
                    if deltaX < 0 then
                        {- Hit the left wall -}
                        { object
                            | velocity =
                                ( -0.000001, vy )
                                -- keep the sign of the direction
                            , position = ( Tuple.first position + Tuple.first size, y )
                        }
                    else
                        {- Hit the right wall -}
                        { object
                            | velocity =
                                ( 0.000001, vy )
                                -- keep the sign of the direction
                            , position = ( Tuple.first position - Tuple.first object.size, y )
                        }
                else
                    object
            )
            { object
                | position = ( x + deltaX, y )
                , velocity = ( newVelocity, vy )
            }
            walls


invertScreen : Object -> Object
invertScreen ({ size, position, velocity, category } as object) =
    case category of
        ScreenCategory { to } ->
            let
                ( x, y ) =
                    position

                ( w, h ) =
                    size
            in
                (case to of
                    Left ->
                        { object
                            | size = ( 64 - w, h )
                            , position = ( x + w, y )
                        }

                    Right ->
                        { object
                            | size = ( 64 - w, h )
                            , position = ( x - (64 - w), y )
                        }

                    Top ->
                        { object
                            | size = ( w, 64 - h )
                            , position = ( x, y + h )
                        }

                    Bottom ->
                        { object
                            | size = ( w, 64 - h )
                            , position = ( x, y - (64 - h) )
                        }
                )

        _ ->
            object


shrink : Time -> Screen -> Object -> List Object -> List Object
shrink dt { to, state } object =
    let
        ( x, y ) =
            object.position

        ( w, h ) =
            object.size

        newW =
            max 0 (w - dt * Tuple.first object.velocity)

        newH =
            max 0 (h - dt * Tuple.second object.velocity)
    in
        if state /= Moving then
            (::) object
        else if w == 0 || h == 0 then
            identity
        else
            (case to of
                Left ->
                    { object
                        | size = ( newW, 64 )
                    }

                Right ->
                    { object
                        | size = ( newW, 64 )
                        , position = ( x - newW + w, y )
                    }

                Top ->
                    { object
                        | size = ( 64, newH )
                    }

                Bottom ->
                    { object
                        | size = ( 64, newH )
                        , position = ( x, y - newH + h )
                    }
            )
                |> (::)


activate : List Object -> Screen -> Object -> Object
activate objects screen object =
    if List.all (\{ number } -> number /= object.number - 1) objects then
        { object | category = ScreenCategory (Screen.activate screen) }
    else
        object


update : Time -> Keys -> List Object -> List Object -> Object -> List Object -> List Object
update elapsed { x, y } screens walls object =
    case object.category of
        ScreenCategory screen ->
            let
                newScreen =
                    Screen.update elapsed object.velocity screen
            in
                { object | category = ScreenCategory newScreen }
                    |> activate screens newScreen
                    |> shrink elapsed newScreen

        WallCategory ->
            if List.any (collide object) screens then
                (::) object
            else
                identity

        MogeeCategory mogee ->
            if List.any (collide object) screens then
                { object | category = MogeeCategory (Mogee.update elapsed object.velocity mogee) }
                    |> moveY elapsed y walls
                    |> moveX elapsed x walls
                    |> (::)
            else
                (::) { object | category = MogeeCategory (Mogee.die mogee) }


toIntTuple : ( Float, Float ) -> ( Int, Int )
toIntTuple ( x, y ) =
    ( round x, round y )


collide : Object -> Object -> Bool
collide o1 o2 =
    let
        ( x1, y1 ) =
            toIntTuple o1.position

        ( w1, h1 ) =
            toIntTuple o1.size

        ( x2, y2 ) =
            toIntTuple o2.position

        ( w2, h2 ) =
            toIntTuple o2.size
    in
        x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2


isDead : List Object -> Bool
isDead =
    List.any
        (\{ category } ->
            case category of
                MogeeCategory { state } ->
                    state == Mogee.Dead

                _ ->
                    False
        )
