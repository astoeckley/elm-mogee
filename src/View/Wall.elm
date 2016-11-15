module View.Wall exposing (render)

import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3)
import WebGL as GL
import View.Common exposing (box)


type alias UniformTextured =
    { size : Vec2
    , offset : Vec3
    , texture : GL.Texture
    , textureSize : Vec2
    }


type alias Varying =
    { texturePos : Vec2 }


render : GL.Texture -> ( Float, Float ) -> ( Float, Float, Float ) -> GL.Renderable
render texture ( w, h ) position =
    GL.render
        texturedVertexShader
        texturedFragmentShader
        box
        { offset = Vec3.fromTuple position
        , texture = texture
        , textureSize = vec2 (toFloat (Tuple.first (GL.textureSize texture))) (toFloat (Tuple.second (GL.textureSize texture)))
        , size =
            vec2 w
                (if w == 1 || h == 1 then
                    h
                 else
                    h + 3
                )
            -- only expand wider walls
        }



-- Shaders


texturedVertexShader : GL.Shader View.Common.Vertex UniformTextured Varying
texturedVertexShader =
    [glsl|

  precision mediump float;
  attribute vec2 position;
  uniform vec3 offset;
  uniform vec2 size;
  varying vec2 texturePos;

  void main () {
    vec2 roundOffset = vec2(floor(offset.x + 0.5), floor(offset.y + 0.5));
    vec2 clipSpace = (position * size + roundOffset) / 32.0 - 1.0;
    gl_Position = vec4(clipSpace.x, -clipSpace.y, offset.z / 10.0, 1);
    texturePos = position * size;
  }

|]


texturedFragmentShader : GL.Shader {} UniformTextured Varying
texturedFragmentShader =
    [glsl|

  precision mediump float;
  uniform sampler2D texture;
  uniform vec2 textureSize;
  varying vec2 texturePos;

  void main () {
    vec2 pos = vec2(texturePos.x, float(int(texturePos.y) - int(texturePos.y) / 5 * 5));
    vec2 textureClipSpace = pos / textureSize - 1.0;
    float offset = 11.0 / textureSize.y;
    gl_FragColor = texture2D(texture, vec2(textureClipSpace.x, -textureClipSpace.y - offset));
    if (gl_FragColor.a == 0.0) discard;
  }

|]
