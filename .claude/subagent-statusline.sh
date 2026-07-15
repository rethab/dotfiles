#!/bin/bash

# Each task carries its own resolved model, unlike the main statusLine which
# always reflects the lead session.

jq -c '(.tasks // [])[] | {
  id,
  content: (
    (.name // .label // "task") as $name
    | (.description // .label // "") as $body
    | (.model // "?" | sub("^claude-"; "") | sub("-[0-9].*$"; "")) as $model
    | (if (.contextWindowSize // 0) > 0
        then ", \(((.tokenCount // 0) * 100 / .contextWindowSize) | floor)% ctx"
        else "" end) as $ctx
    | "\($name) (\($model)\($ctx))\(if ($body != "" and $body != $name) then "  \($body)" else "" end)"
  )
}' 2>/dev/null
